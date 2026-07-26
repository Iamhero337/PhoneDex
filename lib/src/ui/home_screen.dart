import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/reconnection/reconnection_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _core = AndroidCore.instance;
  final _reconn = ReconnectionManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Background
        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF12162E), Color(0xFF0A0E27)]))),
        // Title bar
        Positioned(top: 0, left: 0, right: 0, child: MoveWindow(child: Container(
          height: 40,
          decoration: BoxDecoration(color: const Color(0xFF1A1F3E).withOpacity(0.9), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08)))),
          child: Row(children: [
            const SizedBox(width: 16),
            Container(width: 14, height: 14, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)])),),
            const SizedBox(width: 8),
            Text('PhoneDex', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            _ConnectionStatus(),
            const SizedBox(width: 16),
            WindowTitleBarBox(child: Row(children: [
              MinimizeWindowButton(colors: WindowButtonColors(iconNormal: Colors.white.withOpacity(0.5), mouseOver: Colors.white.withOpacity(0.1))),
              MaximizeWindowButton(colors: WindowButtonColors(iconNormal: Colors.white.withOpacity(0.5), mouseOver: Colors.white.withOpacity(0.1))),
              CloseWindowButton(colors: WindowButtonColors(iconNormal: Colors.white.withOpacity(0.5), mouseOver: Colors.red.withOpacity(0.5))),
            ])),
          ]),
        ))),
        // Taskbar
        Positioned(bottom: 0, left: 0, right: 0, child: _TaskBar()),
        // Reconnection overlay
        ValueListenableBuilder<ReconnectionStatus>(
          valueListenable: _reconn.status,
          builder: (_, s, __) => s.phase != ReconnectionPhase.idle ? _ReconnectionOverlay(s) : const SizedBox.shrink(),
        ),
        // Center content placeholder
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.phone_android_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text('Your Phone, Your Desktop', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 12),
          Text('Launch apps from the taskbar below', style: TextStyle(color: Colors.white.withOpacity(0.3))),
        ])),
      ]),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AndroidCore.instance.allConnected,
      builder: (_, connected, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: (connected ? Colors.green : Colors.orange).withOpacity(0.15), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (connected ? Colors.green : Colors.orange).withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: connected ? Colors.green : Colors.orange, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(connected ? 'Connected' : 'Connecting…', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (connected ? Colors.green : Colors.orange)[300])),
        ]),
      ),
    );
  }
}

class _TaskBar extends StatefulWidget {
  @override
  State<_TaskBar> createState() => _TaskBarState();
}

class _TaskBarState extends State<_TaskBar> {
  Timer? _clockTimer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        final n = DateTime.now();
        _time = '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() { _clockTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final core = AndroidCore.instance;
    return Container(
      height: 48,
      decoration: BoxDecoration(color: const Color(0xFF1A1F3E).withOpacity(0.95), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
      child: Row(children: [
        _StartButton(),
        const Expanded(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            _AppBtn(label: 'Apps', icon: Icons.phone_android_rounded, color: Colors.blue),
            _AppBtn(label: 'Notifications', icon: Icons.notifications_rounded, color: Colors.orange),
            _AppBtn(label: 'Media', icon: Icons.music_note_rounded, color: Colors.purple),
            _AppBtn(label: 'Settings', icon: Icons.settings_rounded, color: Colors.grey),
          ]),
        )),
        // System tray
        ValueListenableBuilder<bool>(
          valueListenable: core.allConnected,
          builder: (_, c, __) => Container(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisSize: MainAxisSize.min, children: [
            _TrayItem(icon: core.batteryCharging ? Icons.battery_charging_full_rounded : Icons.battery_5_bar_rounded, text: '${core.batteryPercentage}%', color: core.batteryCharging ? Colors.green : Colors.white70),
            const SizedBox(width: 16),
            _TrayItem(icon: core.wifi ? Icons.wifi_rounded : Icons.wifi_off_rounded, text: core.wifi ? 'Wi-Fi' : 'Off', color: core.wifi ? Colors.blue : Colors.grey),
            const SizedBox(width: 16),
            _TrayItem(icon: Icons.volume_up_rounded, text: '${core.volumeMusic}', color: Colors.white70),
            const SizedBox(width: 16),
            Text(_time, style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
          ])),
        ),
      ]),
    );
  }
}

class _StartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.apps_rounded, size: 16, color: Colors.white)),
        const SizedBox(width: 8),
        const Text('PhoneDex', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

class _AppBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _AppBtn({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 12))]));
  }
}

class _TrayItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _TrayItem({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: color), const SizedBox(width: 6),
    Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
  ]);
}

class _ReconnectionOverlay extends StatelessWidget {
  final ReconnectionStatus status;
  const _ReconnectionOverlay(this.status);
  @override
  Widget build(BuildContext context) {
    final phaseColor = switch (status.phase) {
      ReconnectionPhase.quickReconnect => Colors.blue,
      ReconnectionPhase.fullRestart => Colors.orange,
      ReconnectionPhase.failed => Colors.red,
      ReconnectionPhase.idle => Colors.green,
    };
    return Container(color: Colors.black.withOpacity(0.85), child: Center(child: Container(
      margin: const EdgeInsets.all(32), padding: const EdgeInsets.all(48), constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(color: const Color(0xFF1A1F3E), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: phaseColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: Text(status.phase.name.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: phaseColor))),
        const SizedBox(height: 20),
        Text(status.message, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Pill('Engine', status.jarReconnecting ? Colors.blue : (status.phase == ReconnectionPhase.idle ? Colors.green : Colors.red)),
          const SizedBox(width: 12),
          _Pill('Hub', status.apkReconnecting ? Colors.blue : (status.phase == ReconnectionPhase.idle ? Colors.green : Colors.red)),
        ]),
        if (status.phase == ReconnectionPhase.fullRestart) ...[
          const SizedBox(height: 16),
          Text('Attempt ${status.attempt} of 2', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ],
        if (status.phase != ReconnectionPhase.failed && status.phase != ReconnectionPhase.idle) ...[
          const SizedBox(height: 24), const CircularProgressIndicator(strokeWidth: 3),
        ],
      ]),
    )));
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)));
}