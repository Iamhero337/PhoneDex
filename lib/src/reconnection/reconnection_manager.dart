import 'dart:async';
import 'package:flutter/foundation.dart';
import '../state/android_core.dart';
import '../adb/adb_provider.dart';
import '../jar/jar_manager.dart';
import '../../core/device.dart';
import '../../utils/logger.dart';

/// Reconnection phases
enum ReconnectionPhase {
  idle,
  quickReconnect,
  fullRestart,
  failed,
}

/// Reconnection status
class ReconnectionStatus {
  final ReconnectionPhase phase;
  final bool jarReconnecting;
  final bool apkReconnecting;
  final String message;
  final int attempt;

  const ReconnectionStatus({
    required this.phase,
    required this.jarReconnecting,
    required this.apkReconnecting,
    required this.message,
    required this.attempt,
  });

  ReconnectionStatus copyWith({
    ReconnectionPhase? phase,
    bool? jarReconnecting,
    bool? apkReconnecting,
    String? message,
    int? attempt,
  }) {
    return ReconnectionStatus(
      phase: phase ?? this.phase,
      jarReconnecting: jarReconnecting ?? this.jarReconnecting,
      apkReconnecting: apkReconnecting ?? this.apkReconnecting,
      message: message ?? this.message,
      attempt: attempt ?? this.attempt,
    );
  }

  @override
  String toString() => 'ReconnectionStatus(phase: $phase, jar: $jarReconnecting, apk: $apkReconnecting, message: $message, attempt: $attempt)';
}

/// Manages automatic reconnection after disconnection
class ReconnectionManager {
  ReconnectionManager._internal();
  static final ReconnectionManager _instance = ReconnectionManager._internal();
  factory ReconnectionManager() => _instance;

  final _log = AppLogger('ReconnectionManager');
  final _core = AndroidCore();
  final _adb = AdbProvider();
  final _jarManager = JarManager();

  final _statusController = ValueNotifier<ReconnectionStatus>(
    const ReconnectionStatus(
      phase: ReconnectionPhase.idle,
      jarReconnecting: false,
      apkReconnecting: false,
      message: '',
      attempt: 0,
    ),
  );

  ValueNotifier<ReconnectionStatus> get status => _statusController;
  bool _isMonitoring = false;
  bool _busy = false;
  ConnectionTarget? _currentTarget;
  StreamSubscription? _jarSub;
  StreamSubscription? _apkSub;
  Timer? _reconnectTimer;

  /// Starts monitoring connection state
  void startMonitoring(ConnectionTarget target) {
    if (_isMonitoring) return;
    _log.info('Starting connection monitoring');
    _currentTarget = target;
    _isMonitoring = true;
    _busy = false;

    _jarSub = _core.jarConnected.addListener(_onConnectionChanged);
    _apkSub = _core.apkConnected.addListener(_onConnectionChanged);
  }

  /// Stops monitoring
  void stopMonitoring() {
    _log.info('Stopping connection monitoring');
    _isMonitoring = false;
    _jarSub?.cancel();
    _apkSub?.cancel();
    _reconnectTimer?.cancel();
    _jarSub = null;
    _apkSub = null;
  }

  void _onConnectionChanged() {
    if (_busy || !_isMonitoring) return;
    
    final jarConnected = _core.jarConnected.value;
    final apkConnected = _core.apkConnected.value;
    
    if (jarConnected && apkConnected) {
      // Both connected - if we were reconnecting, we're done
      if (_statusController.value.phase != ReconnectionPhase.idle) {
        _log.info('Both components reconnected successfully');
        _setStatus(const ReconnectionStatus(
          phase: ReconnectionPhase.idle,
          jarReconnecting: false,
          apkReconnecting: false,
          message: 'Connected',
          attempt: 0,
        ));
      }
      return;
    }

    // One or both disconnected - start recovery
    _startRecovery(
      jarReconnecting: !jarConnected,
      apkReconnecting: !apkConnected,
    );
  }

  void _startRecovery({required bool jarReconnecting, required bool apkReconnecting}) {
    if (_busy) return;
    _busy = true;
    
    _log.warning('Connection lost - JAR: $jarConnected, APK: $apkConnected. Starting recovery...');
    
    _setStatus(ReconnectionStatus(
      phase: ReconnectionPhase.quickReconnect,
      jarReconnecting: jarReconnecting,
      apkReconnecting: apkReconnecting,
      message: 'Attempting to reconnect to device...',
      attempt: 0,
    ));
    
    _core.setReconnecting(true, 'Attempting to reconnect to device...');
    
    _attemptQuickReconnect(jarReconnecting, apkReconnecting);
  }

  Future<void> _attemptQuickReconnect(bool jarReconnecting, bool apkReconnecting) async {
    try {
      if (_currentTarget == null) throw Exception('No target device');
      
      _log.info('Phase 1: Quick reconnect...');
      
      // Reconnect ADB
      final connectResult = await _reconnectAdb();
      if (!connectResult) throw Exception('ADB reconnect failed');
      
      // Re-setup reverse ports
      await _setupReversePorts();
      
      // Wait for reconnections
      await _waitForReconnections(jarReconnecting, apkReconnecting, const Duration(seconds: 15));
      
      final jarOk = _core.jarConnected.value || !jarReconnecting;
      final apkOk = _core.apkConnected.value || !apkReconnecting;
      
      if (jarOk && apkOk) {
        _log.info('Quick reconnect successful');
        _setStatus(const ReconnectionStatus(
          phase: ReconnectionPhase.idle,
          jarReconnecting: false,
          apkReconnecting: false,
          message: 'Reconnected successfully',
          attempt: 0,
        ));
        _core.setReconnecting(false);
        _busy = false;
        return;
      }
      
      // Quick reconnect failed - proceed to full restart
      _log.warning('Quick reconnect failed, starting full restart...');
      await _attemptFullRestart(jarReconnecting, apkReconnecting);
    } catch (e) {
      _log.error('Quick reconnect error: $e');
      await _attemptFullRestart(jarReconnecting, apkReconnecting);
    }
  }

  Future<bool> _reconnectAdb() async {
    if (_currentTarget == null) return false;
    
    try {
      final target = _currentTarget!;
      if (target is WifiTarget) {
        final result = await _adb.connectWifi(target.ip, target.port);
        return result.success && (result.output.contains('connected') || result.output.contains('already connected'));
      } else {
        // USB - just ensure ADB server is running
        await _adb.startServer();
        return true;
      }
    } catch (e) {
      _log.error('ADB reconnect failed: $e');
      return false;
    }
  }

  Future<void> _setupReversePorts() async {
    if (_currentTarget == null) return;
    const ports = [8080, 8081, 8082, 8083]; // JAR, APK, Media, Notification ports
    await _adb.setupReversePorts(_currentTarget!, ports);
  }

  Future<void> _waitForReconnections(bool waitJar, bool waitApk, Duration timeout) async {
    final completer = Completer<void>();
    var jarDone = !waitJar;
    var apkDone = !waitApk;
    
    late StreamSubscription jarSub;
    late StreamSubscription apkSub;
    
    jarSub = _core.jarConnected.addListener(() {
      if (!jarDone && _core.jarConnected.value) {
        jarDone = true;
        _checkDone();
      }
    });
    
    apkSub = _core.apkConnected.addListener(() {
      if (!apkDone && _core.apkConnected.value) {
        apkDone = true;
        _checkDone();
      }
    });
    
    void _checkDone() {
      if ((jarDone || !waitJar) && (apkDone || !waitApk)) {
        completer.complete();
      }
    }
    
    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      _log.warning('Reconnection wait timed out');
    } finally {
      jarSub.cancel();
      apkSub.cancel();
    }
  }

  Future<void> _attemptFullRestart(bool jarReconnecting, bool apkReconnecting) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      _setStatus(ReconnectionStatus(
        phase: ReconnectionPhase.fullRestart,
        jarReconnecting: jarReconnecting,
        apkReconnecting: apkReconnecting,
        message: 'Performing full restart (attempt $attempt of 2)...',
        attempt: attempt,
      ));
      
      _core.setReconnecting(true, 'Performing full restart (attempt $attempt of 2)...');
      
      try {
        // Stop existing JAR
        await _jarManager.stop();
        
        // Kill JAR on device
        if (_currentTarget != null) {
          await _adb.killJarProcess(_currentTarget!);
        }
        
        // Redeploy JAR
        final deployResult = await _jarManager.deployAndStart(_currentTarget!);
        if (!deployResult.success) {
          throw Exception(deployResult.userMessage ?? 'JAR deploy failed');
        }
        
        // Restart APK service
        if (_currentTarget != null && apkReconnecting) {
          const packageName = 'com.phonedex.hub';
          await _adb.startCompanionService(_currentTarget!, packageName);
        }
        
        // Wait for handshakes
        await _waitForReconnections(jarReconnecting, apkReconnecting, const Duration(seconds: 30));
        
        final jarOk = _core.jarConnected.value || !jarReconnecting;
        final apkOk = _core.apkConnected.value || !apkReconnecting;
        
        if (jarOk && apkOk) {
          _log.info('Full restart successful on attempt $attempt');
          _setStatus(const ReconnectionStatus(
            phase: ReconnectionPhase.idle,
            jarReconnecting: false,
            apkReconnecting: false,
            message: 'Reconnected successfully',
            attempt: 0,
          ));
          _core.setReconnecting(false);
          _busy = false;
          return;
        }
      } catch (e) {
        _log.error('Full restart attempt $attempt failed: $e');
        if (attempt == 2) {
          _onRecoveryFailed(e.toString());
          return;
        }
        // Wait before retry
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  void _onRecoveryFailed(String error) {
    _log.error('All recovery attempts failed: $error');
    _setStatus(ReconnectionStatus(
      phase: ReconnectionPhase.failed,
      jarReconnecting: false,
      apkReconnecting: false,
      message: 'Device disconnected. Check your USB cable or Wi-Fi connection.',
      attempt: 0,
    ));
    _core.setReconnecting(false, 'Device disconnected. Check your USB cable or Wi-Fi connection.');
    _busy = false;
  }

  void _setStatus(ReconnectionStatus status) {
    _statusController.value = status;
  }

  void dispose() {
    stopMonitoring();
    _statusController.dispose();
  }
}