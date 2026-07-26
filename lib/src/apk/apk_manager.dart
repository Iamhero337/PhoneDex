import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:phonedex/src/core/device.dart';
import 'package:phonedex/src/adb/adb_provider.dart';
import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/utils/logger.dart';

class ApkEvent {
  final double progress;
  final String message;
  final bool isError, isComplete;
  const ApkEvent({required this.progress, required this.message, this.isError = false, this.isComplete = false});
}

class ApkManager {
  final _log = AppLogger('ApkMgr');
  final _adb = AdbProvider();
  final _core = AndroidCore.instance;
  final _events = StreamController<ApkEvent>.broadcast();
  Completer<void> _handshake = Completer<void>();

  static const _pkg = 'com.phonedex.hub';

  Stream<ApkEvent> get events => _events.stream;
  Completer<void> get handshakeCompleter => _handshake;

  void resetHandshake() {
    if (_handshake.isCompleted) _handshake = Completer<void>();
  }

  void markHandshakeComplete() {
    if (!_handshake.isCompleted) _handshake.complete();
  }

  Future<void> ensureInstalledAndStart(ConnectionTarget target) async {
    try {
      _emit(0.55, 'Checking companion app on device…');
      final installed = await _adb.isPackageInstalled(target, _pkg);
      if (!installed) {
        _emit(0.65, 'Companion app missing — checking local installer…');
        final apkPath = await _adb.apkPath;
        if (apkPath != null) {
          _emit(0.70, 'Installing PhoneDex companion app…');
          final r = await _adb.installApk(target, apkPath);
          if (!r.success) {
            _log.warning('Apk install output: ${r.output}');
          }
        } else {
          _log.info('PhoneDex.apk not found in assets, skipping companion app install');
          _emit(0.80, 'Companion app skipped (Assets missing)');
          markHandshakeComplete();
          return;
        }
      }
      
      _emit(0.78, 'Starting companion service…');
      final r = await _adb.startCompanionService(target, _pkg);
      if (!r.success) {
        _log.warning('Service start output: ${r.output}');
      }
      _emit(0.85, 'Waiting for companion connection…');
    } catch (e) {
      _log.error('APK setup: $e');
      _emit(0.85, 'Companion app setup note: $e');
      markHandshakeComplete();
    }
  }

  void handleConnection(WebSocket ws) {
    _log.info('APK connected');
    ws.listen(
      (msg) {
        try {
          final json = jsonDecode(msg as String) as Map<String, dynamic>;
          if (json['type'] == 'apk.hello') {
            _log.info('APK handshake confirmed');
            _core.setApkConnected(true);
            markHandshakeComplete();
            _emit(1.0, 'Companion connected ✓', isComplete: true);
          } else {
            _core.updateFromMessage(json);
          }
        } catch (e) {
          _log.warning('APK parse error: $e');
        }
      },
      onError: (_) => _core.setApkConnected(false),
      onDone: () => _core.setApkConnected(false),
    );
  }

  Future<void> startExtendedServices() async {}
  
  void _emit(double p, String m, {bool isError = false, bool isComplete = false}) {
    if (!_events.isClosed) {
      _events.add(ApkEvent(progress: p, message: m, isError: isError, isComplete: isComplete));
    }
  }

  void dispose() { _events.close(); }
}