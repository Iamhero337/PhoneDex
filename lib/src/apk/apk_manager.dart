import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../adb/adb_provider.dart';
import '../core/device.dart';
import '../state/android_core.dart';
import '../utils/logger.dart';

/// APK connection events
class ApkEvent {
  final double progress;
  final String message;
  final bool isError;
  final bool isComplete;

  const ApkEvent({
    required this.progress,
    required this.message,
    this.isError = false,
    this.isComplete = false,
  });
}

/// Manages the companion APK lifecycle on the device
class ApkManager {
  ApkManager._internal();
  static final ApkManager _instance = ApkManager._internal();
  factory ApkManager() => _instance;

  final _log = AppLogger('ApkManager');
  final _adb = AdbProvider();
  final _androidCore = AndroidCore();
  
  WebSocketChannel? _apkChannel;
  final _eventController = StreamController<ApkEvent>.broadcast();
  final _handshakeCompleter = Completer<void>();
  Timer? _pingTimer;

  static const String _packageName = 'com.phonedex.hub';
  static const int _apkServerPort = 8081;

  Stream<ApkEvent> get events => _eventController.stream;
  Completer<void> get handshakeCompleter => _handshakeCompleter;
  bool get isConnected => _apkChannel != null && _handshakeCompleter.isCompleted;

  /// Resets the handshake completer for retry
  void resetHandshake() {
    if (_handshakeCompleter.isCompleted) {
      _handshakeCompleter = Completer<void>();
    }
  }

  /// Ensures APK is installed and starts the service
  Future<void> ensureInstalledAndStart(ConnectionTarget target) async {
    _log.info('Ensuring APK is installed and started...');
    
    try {
      // Check if APK is installed
      _emit(0.55, 'Verifying companion app on device...');
      final installed = await _adb.isPackageInstalled(target, _packageName);
      
      if (!installed) {
        _emit(0.65, 'Companion app not found — installing now...');
        final apkPath = await _adb.apkPath;
        final installResult = await _adb.installApk(target, apkPath);
        if (!installResult.success) {
          throw Exception('APK install failed: ${installResult.output}');
        }
      }

      // Start the companion service
      _emit(0.72, 'Launching Android companion services...');
      final startResult = await _adb.startCompanionService(target, _packageName);
      if (!startResult.success) {
        throw Exception('Failed to start companion service: ${startResult.output}');
      }

      _emit(0.80, 'Waiting for companion app to connect...');
    } catch (e) {
      _log.error('APK setup failed: $e');
      _emit(0, 'Companion app setup failed: $e', isError: true);
      rethrow;
    }
  }

  /// Handles incoming WebSocket connection from APK
  void handleConnection(WebSocketChannel channel) {
    _log.info('APK WebSocket connected');
    _apkChannel = channel;
    
    channel.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );

    // Start ping timer
    _startPingTimer();
  }

  void _onMessage(dynamic message) {
    try {
      if (message is String) {
        final data = _parseJson(message);
        if (data != null) {
          _handleApkMessage(data);
        }
      }
    } catch (e) {
      _log.warning('Failed to parse APK message: $e');
    }
  }

  void _handleApkMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'apk.hello':
        _log.info('APK handshake received');
        _androidCore.setApkConnected(true);
        if (!_handshakeCompleter.isCompleted) {
          _handshakeCompleter.complete();
        }
        _emit(1.0, 'Companion app connected ✓', isComplete: true);
        break;
        
      case 'battery_small':
      case 'battery_update':
      case 'volume_update':
      case 'apk.permissions':
      case 'device_state':
        // Include states block if present
        if (data['states'] != null) {
          _androidCore.updateDeviceStates(data['states'] as Map<String, dynamic>);
        }
        _androidCore.updateFromMessage(data);
        break;
        
      case 'media_session':
        _androidCore.updateMediaSession(data);
        break;
        
      case 'notification':
        _androidCore.updateNotification(data);
        break;
        
      case 'pong':
        // Ping response
        break;
        
      default:
        _log.debug('Unknown APK message type: $type');
    }
  }

  void _onError(error) {
    _log.warning('APK WebSocket error: $error');
    _androidCore.setApkConnected(false);
    _cleanup();
  }

  void _onDone() {
    _log.info('APK WebSocket disconnected');
    _androidCore.setApkConnected(false);
    _cleanup();
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _apkChannel = null;
    resetHandshake();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_apkChannel != null) {
        try {
          _apkChannel!.sink.add('{"type":"ping"}');
        } catch (_) {}
      }
    });
  }

  /// Sends a command to the APK
  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (_apkChannel != null) {
      try {
        _apkChannel!.sink.add(_jsonEncode(command));
      } catch (e) {
        _log.error('Failed to send command to APK: $e');
      }
    }
  }

  /// Starts extended services (media, notifications)
  Future<void> startExtendedServices() async {
    await sendCommand({'type': 'start_services'});
  }

  Map<String, dynamic>? _parseJson(String json) {
    try {
      // Simple JSON parsing - in production use dart:convert
      return _simpleJsonParse(json);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _simpleJsonParse(String json) {
    // This is a simplified parser - replace with json.decode in production
    return {'raw': json};
  }

  String _jsonEncode(Map<String, dynamic> data) {
    // Simplified - use json.encode in production
    return data.toString();
  }

  void _emit(double progress, String message, {bool isError = false, bool isComplete = false}) {
    if (!_eventController.isClosed) {
      _eventController.add(ApkEvent(
        progress: progress,
        message: message,
        isError: isError,
        isComplete: isComplete,
      ));
    }
  }

  void dispose() {
    _cleanup();
    _eventController.close();
  }
}