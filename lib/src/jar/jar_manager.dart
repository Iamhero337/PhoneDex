import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../adb/adb_provider.dart';
import '../utils/logger.dart';
import '../../core/device.dart';

/// Result of a JAR deployment operation
class JarDeployResult {
  final bool success;
  final String? errorMessage;
  final String? userMessage;
  final Process? process;

  const JarDeployResult({
    required this.success,
    this.errorMessage,
    this.userMessage,
    this.process,
  });

  factory JarDeployResult.success(Process process) => JarDeployResult(
    success: true,
    process: process,
  );

  factory JarDeployResult.failure(String error, {String? userMessage}) => JarDeployResult(
    success: false,
    errorMessage: error,
    userMessage: userMessage,
  );
}

/// JAR deployment progress event
class JarDeployEvent {
  final double progress;
  final String message;
  final bool isError;
  final bool isComplete;

  const JarDeployEvent({
    required this.progress,
    required this.message,
    this.isError = false,
    this.isComplete = false,
  });

  @override
  String toString() => 'JarDeployEvent(progress: $progress, message: $message, isError: $isError)';
}

/// Manages the Logic Engine (JAR) lifecycle on the device
class JarManager {
  JarManager._internal();
  static final JarManager _instance = JarManager._internal();
  factory JarManager() => _instance;

  final _log = AppLogger('JarManager');
  final _adb = AdbProvider();
  
  Process? _jarProcess;
  final _eventController = StreamController<JarDeployEvent>.broadcast();
  final _handshakeCompleter = Completer<void>();

  Stream<JarDeployEvent> get events => _eventController.stream;
  Completer<void> get handshakeCompleter => _handshakeCompleter;
  bool get isRunning => _jarProcess != null;
  bool get isHandshakeComplete => _handshakeCompleter.isCompleted;

  /// Resets the handshake completer for retry
  void resetHandshake() {
    if (_handshakeCompleter.isCompleted) {
      _handshakeCompleter = Completer<void>();
    }
  }

  /// Deploys and starts the JAR on the device
  Future<JarDeployResult> deployAndStart(ConnectionTarget target) async {
    _log.info('Starting JAR deployment...');
    
    try {
      // Step 1: Stop any existing JAR process locally
      await _stopLocalProcess();
      _emit(0.05, 'Preparing service deployment...');

      // Step 2: Kill existing JAR process on device
      await _adb.killJarProcess(target);
      _emit(0.15, 'Stopping previous service on device...');

      // Step 3: Locate JAR file
      final jarPath = await _adb.jarPath;
      _emit(0.30, 'Locating service module...');

      // Step 4: Push JAR to device
      _emit(0.45, 'Uploading service module to device...');
      final pushResult = await _adb.pushJar(target, jarPath);
      if (!pushResult.success) {
        throw Exception('Failed to push JAR: ${pushResult.output}');
      }
      _emit(0.60, 'Service module uploaded successfully');

      // Step 5: Verify JAR on device
      _emit(0.70, 'Verifying service module...');
      final verifyResult = await _adb.runOnDevice(target, [
        'shell', 'ls', '-la', '/data/local/tmp/phonedex.jar'
      ]);
      if (!verifyResult.success) {
        throw Exception('JAR verification failed');
      }

      // Step 6: Start JAR runtime
      _emit(0.82, 'Launching service runtime on device...');
      _jarProcess = await _adb.startJarRuntime(target);
      _emit(0.90, 'Service is running — awaiting connection...');

      // Step 7: Wait for handshake (with timeout)
      try {
        await _handshakeCompleter.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('JAR handshake timeout'),
        );
        _emit(1.0, 'Service connected — handshake confirmed ✓', isComplete: true);
        return JarDeployResult.success(_jarProcess!);
      } on TimeoutException {
        await _stopLocalProcess();
        throw Exception('Background service timed out. The device may be busy or unreachable.');
      }
    } catch (e) {
      _log.error('JAR deployment failed: $e');
      _emit(0, 'Service initialization failed: $e', isError: true);
      return JarDeployResult.failure(
        e.toString(),
        userMessage: 'Service initialization failed. Ensure the device is connected.',
      );
    }
  }

  /// Marks the handshake as complete (called when jar.hello received)
  void markHandshakeComplete() {
    if (!_handshakeCompleter.isCompleted) {
      _handshakeCompleter.complete();
    }
  }

  /// Stops the JAR process
  Future<void> stop() async {
    _log.info('Stopping JAR...');
    await _stopLocalProcess();
    _resetState();
  }

  Future<void> _stopLocalProcess() async {
    if (_jarProcess != null) {
      try {
        _jarProcess!.kill(ProcessSignal.sigterm);
        await _jarProcess!.exitCode.timeout(const Duration(seconds: 5));
      } catch (_) {
        try {
          _jarProcess!.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
      _jarProcess = null;
    }
  }

  void _resetState() {
    if (!_handshakeCompleter.isCompleted) {
      _handshakeCompleter = Completer<void>();
    }
  }

  void _emit(double progress, String message, {bool isError = false, bool isComplete = false}) {
    if (!_eventController.isClosed) {
      _eventController.add(JarDeployEvent(
        progress: progress,
        message: message,
        isError: isError,
        isComplete: isComplete,
      ));
    }
  }

  void dispose() {
    _stopLocalProcess();
    _eventController.close();
  }
}