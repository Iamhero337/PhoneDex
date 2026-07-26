import 'dart:async';
import 'package:phonedex/src/core/device.dart';
import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/adb/adb_provider.dart';
import 'package:phonedex/src/jar/jar_manager.dart';
import 'package:phonedex/src/apk/apk_manager.dart';
import 'package:phonedex/src/reconnection/reconnection_manager.dart';
import 'package:phonedex/src/utils/logger.dart';

class AppEvent {
  final double progress;
  final String message;
  final bool isError, isComplete, canPickDevice;
  const AppEvent({
    required this.progress,
    required this.message,
    this.isError = false,
    this.isComplete = false,
    this.canPickDevice = false,
  });
}

class AppManager {
  final _log = AppLogger('AppMgr');
  final _adb = AdbProvider();
  final _core = AndroidCore.instance;
  final _jarMgr = JarManager.instance;
  final _apkMgr = ApkManager();
  final _reconn = ReconnectionManager();
  final _events = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get events => _events.stream;
  bool _busy = false;

  Future<void> initializeSystem(ConnectionTarget target) async {
    if (_busy) return;
    _busy = true;
    _core.activeTarget = target;

    try {
      _emit(0.05, 'Starting ADB server…');
      await _adb.startServer();

      if (target case WifiTarget(:final ip, :final port)) {
        _emit(0.15, 'Connecting to Wi-Fi device ($ip:${port ?? 5555})…');
        final r = await _adb.connectDevice(ip, port ?? 5555);
        if (!r.success && !r.output.contains('already connected')) {
          throw AdbException('WiFi connect failed: ${r.output}',
              userMessage: 'Unable to connect to $ip. Ensure Wireless Debugging is ON and PC & phone are on the same Wi-Fi network.');
        }
      }

      _emit(0.25, 'Device connected — setting up network bridge…');
      try {
        await _adb.setupReversePorts(target, const [8080, 8081, 8082, 8083]);
      } catch (e) {
        _log.warning('Port reverse warning: $e');
      }

      _emit(0.40, 'Deploying service engine…');
      await _jarMgr.deployAndStart(target);

      _emit(0.60, 'Deploying companion hub…');
      await _apkMgr.ensureInstalledAndStart(target);

      _emit(0.85, 'Finalizing connection…');
      try {
        await Future.wait([
          _jarMgr.handshakeCompleter.future.timeout(const Duration(seconds: 4)),
          _apkMgr.handshakeCompleter.future.timeout(const Duration(seconds: 4)),
        ]);
      } catch (_) {
        _log.info('Proceeding with system activation');
      }

      _emit(0.95, 'Activating desktop environment…');
      await _apkMgr.startExtendedServices();

      _reconn.startMonitoring(target);
      _emit(1.0, 'PhoneDex Ready ✓', isComplete: true);
    } catch (e) {
      _log.error('Init failed: $e');
      _emit(0, e.toString(), isError: true, canPickDevice: _isConnectionError(e.toString()));
    } finally {
      _busy = false;
    }
  }

  static bool _isConnectionError(String m) {
    final l = m.toLowerCase();
    return ['connect','device','adb','network','refused','timeout','unreachable','bridge','handshake']
        .any((k) => l.contains(k));
  }

  void _emit(double p, String m, {bool isError = false, bool isComplete = false, bool canPickDevice = false}) {
    if (!_events.isClosed) {
      _events.add(AppEvent(progress: p, message: m, isError: isError, isComplete: isComplete, canPickDevice: canPickDevice));
    }
  }

  void dispose() {
    _events.close();
    _jarMgr.dispose();
    _reconn.stopMonitoring();
  }
}