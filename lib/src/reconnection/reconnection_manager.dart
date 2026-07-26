import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/adb/adb_provider.dart';
import 'package:phonedex/src/jar/jar_manager.dart';
import 'package:phonedex/src/core/device.dart';
import 'package:phonedex/src/utils/logger.dart';

enum ReconnectionPhase { idle, quickReconnect, fullRestart, failed }

class ReconnectionStatus {
  final ReconnectionPhase phase;
  final bool jarReconnecting, apkReconnecting;
  final String message;
  final int attempt;
  const ReconnectionStatus({required this.phase, required this.jarReconnecting, required this.apkReconnecting, required this.message, required this.attempt});
}

class ReconnectionManager {
  final _log = AppLogger('Reconn');
  final _core = AndroidCore.instance;
  final _adb = AdbProvider();
  final _jarMgr = JarManager.instance;
  final _status = ValueNotifier<ReconnectionStatus>(
    const ReconnectionStatus(phase: ReconnectionPhase.idle, jarReconnecting: false, apkReconnecting: false, message: '', attempt: 0),
  );

  ValueNotifier<ReconnectionStatus> get status => _status;
  bool _monitoring = false, _busy = false;
  ConnectionTarget? _target;

  void startMonitoring(ConnectionTarget t) {
    if (_monitoring) return;
    _target = t;
    _monitoring = true;
    _core.jarConnected.addListener(_onChange);
    _core.apkConnected.addListener(_onChange);
  }

  void stopMonitoring() {
    _monitoring = false;
    _core.jarConnected.removeListener(_onChange);
    _core.apkConnected.removeListener(_onChange);
  }

  void _onChange() {
    if (_busy || !_monitoring) return;
    if (_core.jarConnected.value && _core.apkConnected.value) {
      _set(ReconnectionPhase.idle, false, false, 'Connected', 0);
      _core.setReconnecting(false);
      return;
    }
    _recover(!_core.jarConnected.value, !_core.apkConnected.value);
  }

  void _recover(bool jarDown, bool apkDown) {
    _busy = true;
    _set(ReconnectionPhase.quickReconnect, jarDown, apkDown, 'Reconnecting…', 0);
    _core.setReconnecting(true, 'Reconnecting…');
    _quickReconnect(jarDown, apkDown);
  }

  Future<void> _quickReconnect(bool jarDown, bool apkDown) async {
    try {
      if (_target is WifiTarget) {
        final t = _target as WifiTarget;
        await _adb.connectDevice(t.ip, t.port ?? 5555);
      }
      await _adb.setupReversePorts(_target!, const [8080, 8081, 8082, 8083]);
      await _waitHandshakes(jarDown, apkDown, const Duration(seconds: 15));
      if (!_core.jarConnected.value || !_core.apkConnected.value) {
        await _fullRestart(jarDown, apkDown);
      } else {
        _clear();
      }
    } catch (_) {
      await _fullRestart(jarDown, apkDown);
    }
  }

  Future<void> _fullRestart(bool jarDown, bool apkDown) async {
    for (int i = 1; i <= 2; i++) {
      _set(ReconnectionPhase.fullRestart, jarDown, apkDown, 'Full restart ($i/2)…', i);
      try {
        await _jarMgr.stop();
        if (_target != null) await _adb.killJarProcess(_target!);
        await _jarMgr.deployAndStart(_target!);
        if (_core.jarConnected.value && _core.apkConnected.value) { _clear(); return; }
      } catch (e) {
        if (i == 2) {
          _set(ReconnectionPhase.failed, false, false, 'Device disconnected. Check connection.', 0);
          _core.setReconnecting(false);
        }
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _waitHandshakes(bool j, bool a, Duration d) async {
    final c = Completer<void>();
    late VoidCallback check;
    check = () { if ((_core.jarConnected.value || !j) && (_core.apkConnected.value || !a) && !c.isCompleted) c.complete(); };
    _core.jarConnected.addListener(check);
    _core.apkConnected.addListener(check);
    try { await c.future.timeout(d); } on TimeoutException {} finally { _core.jarConnected.removeListener(check); _core.apkConnected.removeListener(check); }
  }

  void _clear() { _set(ReconnectionPhase.idle, false, false, 'Connected', 0); _core.setReconnecting(false); _busy = false; }

  void _set(ReconnectionPhase p, bool j, bool a, String m, int attempt) {
    _status.value = ReconnectionStatus(phase: p, jarReconnecting: j, apkReconnecting: a, message: m, attempt: attempt);
  }

  void dispose() { stopMonitoring(); _status.dispose(); }
}