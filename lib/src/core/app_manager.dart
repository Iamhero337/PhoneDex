import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/android_core.dart';
import '../reconnection/reconnection_manager.dart';
import '../adb/adb_provider.dart';
import '../core/device.dart';
import '../jar/jar_manager.dart';
import '../apk/apk_manager.dart';
import '../utils/logger.dart';

/// App initialization events
class AppEvent {
  final String message;
  final double progress;
  final bool isError;
  final bool isComplete;
  final bool canPickDevice;

  const AppEvent({
    required this.message,
    required this.progress,
    this.isError = false,
    this.isComplete = false,
    this.canPickDevice = false,
  });
}

/// Master orchestrator for system initialization
class AppManager {
  final _log = AppLogger('AppManager');
  final _adb = AdbProvider();
  final _core = AndroidCore();
  final _jarManager = JarManager();
  final _apkManager = ApkManager();
  final _reconnectionManager = ReconnectionManager();

  final _eventController = StreamController<AppEvent>.broadcast();
  bool _busy = false;

  Stream<AppEvent> get events => _eventController.stream;

  /// Full initialization sequence
  Future<void> initializeSystem(ConnectionTarget target) async {
    if (_busy) return;
    _busy = true;

    try {
      _log.info('Starting system initialization for ${target.runtimeType}');

      // Step 1: Start ADB server
      _emit(0.02, 'Starting ADB server...');
      await _adb.startServer();

      // Step 2: Connect to device
      _emit(0.10, 'Connecting to Android device...');
      await _connectDevice(target);

      // Step 3: Setup reverse ports
      _emit(0.20, 'Device connected — network bridge configured');
      await _setupReversePorts(target);

      // Step 4: Start local servers (already started in main)
      _emit(0.28, 'Starting local communication servers...');
      await Future.delayed(Duration(milliseconds: 200));

      // Step 5: Deploy JAR (starts JAR progress bar)
      _emit(0.38, 'Deploying service module to Android device...');
      final jarResult = await _jarManager.deployAndStart(target);
      if (!jarResult.success) {
        throw Exception(jarResult.userMessage ?? jarResult.errorMessage ?? 'JAR deployment failed');
      }

      // Step 6: Verify/install APK
      _emit(0.55, 'Verifying companion app on device...');
      await _apkManager.ensureInstalledAndStart(target);

      // Step 7: Wait for JAR handshake (handled by JAR manager)
      _emit(0.84, 'Waiting for background service to connect...');
      await _jarManager.handshakeCompleter.future.timeout(
        Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('JAR handshake timeout'),
      );

      // Step 8: Wait for APK handshake
      _emit(0.93, 'Waiting for companion app to connect...');
      await _apkManager.handshakeCompleter.future.timeout(
        Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('APK handshake timeout'),
      );

      // Step 9: Start extended services
      _emit(0.97, 'Activating media and notification services...');
      await _apkManager.startExtendedServices();

      // Step 10: Complete
      _emit(1.0, 'System ready ✓', isComplete: true);

      // Start reconnection monitoring
      _reconnectionManager.startMonitoring(target);
      
    } catch (e) {
      _log.error('Initialization failed: $e');
      _emit(0, e.toString(), isError: true, canPickDevice: _isConnectionError(e.toString()));
    } finally {
      _busy = false;
    }
  }

  Future<void> _connectDevice(ConnectionTarget target) async {
    switch (target) {
      case UsbTarget():
        // USB device - just ensure ADB is running
        break;
      case WifiTarget(ip: final ip, port: final port):
        final result = await _adb.connectWifi(ip, port ?? 5555);
        if (!result.success) {
          throw Exception('Unable to connect to device. Verify the IP address or check the USB cable.');
        }
        break;
      case AutoTarget():
        // Auto-detect handled by device selection
        break;
    }
  }

  Future<void> _setupReversePorts(ConnectionTarget target) async {
    const ports = [8080, 8081, 8082, 8083]; // JAR, APK, Media, Notification
    await _adb.setupReversePorts(target, ports);
  }

  bool _isConnectionError(String message) {
    final l = message.toLowerCase();
    return l.contains('connect') ||
           l.contains('device') ||
           l.contains('adb') ||
           l.contains('network') ||
           l.contains('refused') ||
           l.contains('timeout') ||
           l.contains('unreachable') ||
           l.contains('bridge') ||
           l.contains('handshake');
  }

  void _emit(double progress, String message, {bool isError = false, bool isComplete = false, bool canPickDevice = false}) {
    if (!_eventController.isClosed) {
      _eventController.add(AppEvent(
        progress: progress,
        message: message,
        isError: isError,
        isComplete: isComplete,
        canPickDevice: canPickDevice,
      ));
    }
  }

  void dispose() {
    _eventController.close();
    _jarManager.dispose();
    _apkManager.dispose();
  }
}