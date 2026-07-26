import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

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
  const AppEvent({required this.progress, required this.message, this.isError = false, this.isComplete = false, this.canPickDevice = false});
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

    try {
      _emit(0.02, 'Starting ADB server…');
      await _adb.startServer();

      if (target case WifiTarget(:final ip, :final port)) {
        _emit(0.10, 'Connecting to Wi-Fi device…');
        final r = await _adb.connectDevice(ip, port ?? 5555);
        if (!r.success && !r.output.contains('already connected')) {
          throw AdbException('WiFi connect failed', userMessage: 'Unable to connect. Verify IP.');
        }
      }

      _emit(0.20, 'Device connected — configuring bridge…');
      await _adb.setupReversePorts(target, const [8080, 8081, 8082, 8083]);

      _emit(0.28, 'Local servers ready');
      await Future.delayed(const Duration(milliseconds: 100));

      _emit(0.38, 'Deploying service module…');
      final jarResult = await _jarMgr.deployAndStart(target);
      if (!jarResult.success) {
        throw Exception(jarResult.userMessage ?? 'JAR deployment failed');
      }

      _emit(0.55, 'Checking companion app…');
      await _apkMgr.ensureInstalledAndStart(target);

      _emit(0.84, 'Waiting for service handshake…');
      await _jarMgr.handshakeCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('JAR timeout'),
      );

      _emit(0.93, 'Waiting for companion handshake…');
      await _apkMgr.handshakeCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('APK timeout'),
      );

      _emit(0.97, 'Activating services…');
      await _apkMgr.startExtendedServices();

      _reconn.startMonitoring(target);
      _emit(1.0, 'System ready ✓', isComplete: true);
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
    if (!_events.isClosed) _events.add(AppEvent(progress: p, message: m, isError: isError, isComplete: isComplete, canPickDevice: canPickDevice));
  }

  void dispose() { _events.close(); _jarMgr.dispose(); _reconn.stopMonitoring(); }
}