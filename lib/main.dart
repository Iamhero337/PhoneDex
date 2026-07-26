import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/app_manager.dart';
import 'src/core/device.dart';
import 'src/state/android_core.dart';
import 'src/jar/jar_server.dart';
import 'src/jar/jar_manager.dart';
import 'src/apk/apk_server.dart';
import 'src/ui/boot_screen.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/device_picker_dialog.dart';
import 'src/utils/logger.dart';
import 'src/adb/adb_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PhoneDexApp()));
}

class PhoneDexApp extends ConsumerStatefulWidget {
  const PhoneDexApp({super.key});
  @override
  ConsumerState<PhoneDexApp> createState() => _PhoneDexAppState();
}

class _PhoneDexAppState extends ConsumerState<PhoneDexApp> {
  final _log = AppLogger('App');
  final _appManager = AppManager();
  final _core = AndroidCore.instance;
  final _jarServer = JarServer();
  final _apkServer = ApkServer();
  final _jarMgr = JarManager.instance;

  AppState _appState = AppState.booting;
  String? _errorMessage;
  bool _canPickDevice = false;

  @override
  void initState() {
    super.initState();
    _startup();
  }

  Future<void> _startup() async {
    try {
      await Future.wait([_jarServer.start(), _apkServer.start()]);
      _log.info('Local TCP/WS servers started');
      _appManager.events.listen(_onEvent);
      
      final devices = await AdbProvider().getDevices();
      if (devices.length == 1 && mounted) {
        final d = devices.first;
        final target = d.isWifi
            ? WifiTarget(d.id.split(':').first, int.tryParse(d.id.split(':').last))
            : UsbTarget(d.id);
        _retry(target);
      } else if (mounted) {
        setState(() => _canPickDevice = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openPicker();
        });
      }
    } catch (e) {
      _log.error('Server start failed: $e');
      if (mounted) _setError(e.toString());
    }
  }

  void _onEvent(AppEvent e) {
    if (!mounted) return;
    setState(() {
      if (e.isError) {
        _errorMessage = e.message;
        _canPickDevice = e.canPickDevice;
        _appState = AppState.error;
      } else if (e.isComplete) {
        _appState = AppState.ready;
        _errorMessage = null;
        _canPickDevice = false;
      }
    });
  }

  void _setError(String msg) {
    setState(() {
      _errorMessage = msg;
      _canPickDevice = _isConnErr(msg);
      _appState = AppState.error;
    });
  }

  static bool _isConnErr(String m) =>
      ['connect','device','adb','network','refused','timeout','unreachable','bridge','handshake']
          .any((k) => m.toLowerCase().contains(k));

  void _openPicker() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dCtx) => DevicePickerDialog(
        onDeviceSelected: (target) {
          Navigator.of(dCtx).pop();
          _retry(target);
        },
        onCancel: () => Navigator.of(dCtx).pop(),
      ),
    );
  }

  Future<void> _retry(ConnectionTarget target) async {
    _core.activeTarget = target;
    setState(() {
      _errorMessage = null;
      _canPickDevice = false;
      _appState = AppState.booting;
    });
    _appManager.dispose();
    _core.setJarConnected(false);
    _core.setApkConnected(false);
    _jarMgr.resetHandshake();
    try {
      await _appManager.initializeSystem(target);
    } catch (e) {
      if (mounted) _setError(e.toString());
    }
  }

  @override
  void dispose() {
    _appManager.dispose();
    _jarServer.stop();
    _apkServer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PhoneDex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF006EFF),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
      ),
      home: switch (_appState) {
        AppState.ready => const HomeScreen(),
        _ => BootScreen(
            errorMessage: _errorMessage,
            canPickDevice: _canPickDevice,
            onPickDevice: _openPicker,
            onDirectConnect: _retry,
          ),
      },
    );
  }
}

enum AppState { booting, ready, error }
