import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
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
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([_jarServer.start(), _apkServer.start()]);
      _log.info('Servers started');
      _appManager.events.listen(_onEvent);
      await _appManager.initializeSystem(const AutoTarget());
    } catch (e) {
      _log.error('Init: $e');
      if (mounted) _setError(e.toString());
    }
  }

  void _onEvent(AppEvent e) {
    if (!mounted) return;
    setState(() {
      if (e.isError) { _errorMessage = e.message; _canPickDevice = e.canPickDevice; _appState = AppState.error; }
      else if (e.isComplete) { _appState = AppState.ready; _errorMessage = null; }
    });
  }

  void _setError(String msg) {
    setState(() { _errorMessage = msg; _canPickDevice = _isConnErr(msg); _appState = AppState.error; });
  }

  static bool _isConnErr(String m) => ['connect','device','adb','network','refused','timeout','unreachable','bridge','handshake'].any((k) => m.toLowerCase().contains(k));

  void _openPicker() {
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => DevicePickerDialog(onDeviceSelected: _retry, onCancel: () => Navigator.pop(context)));
  }

  Future<void> _retry(ConnectionTarget target) async {
    setState(() { _errorMessage = null; _canPickDevice = false; _appState = AppState.booting; });
    _appManager.dispose(); _core.setJarConnected(false); _core.setApkConnected(false); _jarMgr.resetHandshake();
    try { await _appManager.initializeSystem(target); }
    catch (e) { if (mounted) _setError(e.toString()); }
  }

  @override
  void dispose() { _appManager.dispose(); _jarServer.stop(); _apkServer.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhoneDex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF006EFF), brightness: Brightness.dark),
      home: switch (_appState) {
        AppState.ready => const HomeScreen(),
        _ => BootScreen(errorMessage: _errorMessage, canPickDevice: _canPickDevice, onPickDevice: _openPicker),
      },
    );
  }
}

enum AppState { booting, ready, error }