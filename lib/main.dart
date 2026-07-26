import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'src/core/app_manager.dart';
import 'src/core/device.dart';
import 'src/state/android_core.dart';
import 'src/jar/jar_server.dart';
import 'src/jar/jar_manager.dart';
import 'src/apk/apk_server.dart'
    hide ApkServer;
import 'src/reconnection/reconnection_manager.dart';
import 'src/ui/boot_screen.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/about_screen.dart';
import 'src/ui/device_picker_dialog.dart';
import 'src/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize logging
  Logger.init();

  runApp(ProviderScope(child: PhoneDexApp()));
}

class PhoneDexApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<PhoneDexApp> createState() => _PhoneDexAppState();
}

class _PhoneDexAppState extends ConsumerState<PhoneDexApp> {
  final _log = AppLogger('PhoneDexApp');
  final _appManager = AppManager();
  final _core = AndroidCore();
  final _jarServer = JarServer();
  final _apkServer = ApkServer();
  final _reconnectionManager = ReconnectionManager();
  final _jarManager = JarManager();

  AppState _appState = AppState.booting;
  ConnectionTarget? _selectedTarget;
  String? _errorMessage;
  bool _canPickDevice = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Start local servers
      await _jarServer.start();
      await _apkServer.start();
      _log.info('Local servers started');

      // Parse command line arguments for connection target
      // For now, use auto-detection
      final target = const AutoTarget();
      
      // Subscribe to app events
      _appManager.events.listen(_onAppEvent);
      
      // Start initialization
      await _appManager.initializeSystem(target);
    } catch (e) {
      _log.error('Initialization failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _canPickDevice = _isConnectionError(e.toString());
        });
      }
    }
  }

  void _onAppEvent(AppEvent event) {
    if (mounted) {
      setState(() {
        if (event.isError) {
          _errorMessage = event.message;
          _canPickDevice = event.canPickDevice;
          _appState = AppState.error;
        } else if (event.isComplete) {
          _appState = AppState.ready;
          _errorMessage = null;
        }
        // Update progress on boot screen via provider
      });
    }
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

  Future<void> _onDeviceSelected(ConnectionTarget target) async {
    setState(() {
      _selectedTarget = target;
      _errorMessage = null;
      _canPickDevice = false;
      _appState = AppState.booting;
    });

    // Reset and retry
    _appManager.dispose();
    _core.setJarConnected(false);
    _core.setApkConnected(false);
    _jarManager.resetHandshake();
    _reconnectionManager.stopMonitoring();

    try {
      await _appManager.initializeSystem(target);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _canPickDevice = _isConnectionError(e.toString());
          _appState = AppState.error;
        });
      }
    }
  }

  void _onOpenDevicePicker() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DevicePickerDialog(
        onDeviceSelected: _onDeviceSelected,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  void dispose() {
    _appManager.dispose();
    _jarServer.stop();
    _apkServer.stop();
    _reconnectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhoneDex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Color(0xFF006EFF),
        brightness: Brightness.dark,
        fontFamily: 'Inter',
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    switch (_appState) {
      case AppState.booting:
        return BootScreen(
          errorMessage: _errorMessage,
          canPickDevice: _canPickDevice,
          onPickDevice: _onOpenDevicePicker,
        );
      case AppState.ready:
        return HomeScreen();
      case AppState.error:
        return BootScreen(
          errorMessage: _errorMessage,
          canPickDevice: _canPickDevice,
          onPickDevice: _onOpenDevicePicker,
        );
    }
  }
}

enum AppState { booting, ready, error }