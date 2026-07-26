import 'dart:async';
import 'dart:io';
import 'package:phonedex/src/core/device.dart';
import 'package:phonedex/src/adb/adb_provider.dart';
import 'package:phonedex/src/utils/logger.dart';

class JarDeployResult {
  final bool success;
  final String? errorMessage, userMessage;
  final Process? process;
  const JarDeployResult({required this.success, this.errorMessage, this.userMessage, this.process});
  factory JarDeployResult.ok(Process p) => JarDeployResult(success: true, process: p);
  factory JarDeployResult.fail(String e, {String? userMsg}) => JarDeployResult(success: false, errorMessage: e, userMessage: userMsg);
}

class JarDeployEvent {
  final double progress;
  final String message;
  final bool isError, isComplete;
  const JarDeployEvent({required this.progress, required this.message, this.isError = false, this.isComplete = false});
}

class JarManager {
  JarManager._();
  static final JarManager _instance = JarManager._();
  static JarManager get instance => _instance;

  final _log = AppLogger('JarMgr');
  final _adb = AdbProvider();
  Process? _process;
  final _events = StreamController<JarDeployEvent>.broadcast();
  Completer<void> _handshake = Completer<void>();

  Stream<JarDeployEvent> get events => _events.stream;
  Completer<void> get handshakeCompleter => _handshake;

  void resetHandshake() {
    if (_handshake.isCompleted) _handshake = Completer<void>();
  }

  void markHandshakeComplete() {
    if (!_handshake.isCompleted) _handshake.complete();
  }

  Future<JarDeployResult> deployAndStart(ConnectionTarget target) async {
    try {
      _emit(0.05, 'Preparing…');
      await _stop();
      _emit(0.15, 'Stopping previous service…');
      await _adb.killJarProcess(target);
      _emit(0.30, 'Locating service module…');
      final jarPath = await _adb.jarPath;
      _emit(0.50, 'Uploading to device…');
      final push = await _adb.pushJar(target, jarPath);
      if (!push.success) throw Exception('Push failed: ${push.output}');
      _emit(0.70, 'Uploaded ✓');
      _emit(0.82, 'Launching service…');
      _process = await _adb.startJarRuntime(target);
      _emit(0.92, 'Awaiting connection…');
      await _handshake.future.timeout(const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('JAR handshake timeout'));
      _emit(1.0, 'Service connected ✓', isComplete: true);
      return JarDeployResult.ok(_process!);
    } catch (e) {
      _log.error('JAR deploy failed: $e');
      _emit(0, 'Service failed: $e', isError: true);
      return JarDeployResult.fail(e.toString(), userMsg: 'Service initialization failed.');
    }
  }

  Future<void> stop() async { await _stop(); resetHandshake(); }
  Future<void> _stop() async {
    if (_process != null) {
      try { _process!.kill(ProcessSignal.sigkill); } catch (_) {}
      _process = null;
    }
  }

  void _emit(double p, String m, {bool isError = false, bool isComplete = false}) {
    if (!_events.isClosed) _events.add(JarDeployEvent(progress: p, message: m, isError: isError, isComplete: isComplete));
  }

  void dispose() { _stop(); _events.close(); }
}