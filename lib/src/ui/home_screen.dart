import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import '../state/android_core.dart';
import '../reconnection/reconnection_manager.dart';

/// Main home screen - desktop experience
class HomeScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _core = AndroidCore();
  final _reconnectionManager = ReconnectionManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          _DesktopBackground(),

          // Window drag area (top area)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 32,
            child: MoveWindow(
              child: Row(
                children: [
                  // App title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF006EFF), Color(0xFF7C3AED)],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PhoneDex',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Connection status
                  _ConnectionStatus(),
                  const SizedBox(width: 16),
                  // Window controls
                  WindowTitleBarBox(
                    child: Row(
                      children: [
                        MinimizeWindowButton(colors: _buttonColors),
                        MaximizeWindowButton(colors: _buttonColors),
                        CloseWindowButton(colors: _buttonColors),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Taskbar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _TaskBar(),
          ),

          // Reconnection overlay
          ValueListenableBuilder<ReconnectionStatus>(
            valueListenable: _reconnectionManager.status,
            builder: (context, status, _) {
              if (status.phase != ReconnectionPhase.idle) {
                return _ReconnectionOverlay(status: status);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  final _buttonColors = WindowButtonColors(
    iconNormal: Colors.white.withOpacity(0.5),
    mouseOver: Colors.white.withOpacity(0.1),
    mouseDown: Colors.white.withOpacity(0.2),
    iconMouseOver: Colors.white,
    iconMouseDown: Colors.white,
  );
}

/// Desktop background
class _DesktopBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF12162E),
            const Color(0xFF0A0E27),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _DesktopMeshPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _DesktopMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: Alignment(0.2, -0.3),
        radius: 1.5,
        colors: [
          const Color(0xFF006EFF).withOpacity(0.05),
          const Color(0xFF7C3AED).withOpacity(0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Connection status indicator in title bar
class _ConnectionStatus extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = AndroidCore();
    
    return ValueListenableBuilder<bool>(
      valueListenable: core.allConnected,
      builder: (context, connected, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: connected ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: connected ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: connected ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? 'Connected' : 'Connecting…',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: connected ? Colors.green[300] : Colors.orange[300],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Taskbar at bottom
class _TaskBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = AndroidCore();

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3E).withOpacity(0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          // Start button
          _StartButton(),
          const SizedBox(width: 8),
          
          // Running apps (placeholder)
          Expanded(
            child: _RunningApps(),
          ),
          
          // System tray area
          _SystemTray(),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF006EFF), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.apps_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              'PhoneDex',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningApps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _AppButton(
            icon: Icons.phone_android_rounded,
            label: 'Apps',
            color: Colors.blue,
          ),
          _AppButton(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            color: Colors.orange,
          ),
          _AppButton(
            icon: Icons.music_note_rounded,
            label: 'Media',
            color: Colors.purple,
          ),
          _AppButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}

class _AppButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AppButton({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SystemTray extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = AndroidCore();

    return ValueListenableBuilder<bool>(
      valueListenable: core.allConnected,
      builder: (context, connected, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Battery
              _TrayItem(
                icon: Icons.battery_5_bar_rounded,
                label: '${core.batteryPercentage}%',
                color: core.batteryCharging ? Colors.green : Colors.white70,
              ),
              const SizedBox(width: 16),
              
              // WiFi
              _TrayItem(
                icon: core.wifi ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                label: core.wifiName.isNotEmpty ? core.wifiName : (core.wifi ? 'Wi-Fi' : 'Offline'),
                color: core.wifi ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 16),
              
              // Bluetooth
              _TrayItem(
                icon: Icons.bluetooth_rounded,
                label: core.bluetooth ? 'On' : 'Off',
                color: core.bluetooth ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 16),
              
              // Volume
              _TrayItem(
                icon: Icons.volume_up_rounded,
                label: '${core.volumeMusic}%',
                color: Colors.white70,
              ),
              
              const SizedBox(width: 8),
              // Time
              _Clock(),
            ],
          ),
        );
      },
    );
  }
}

class _TrayItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TrayItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.8),
            fontVariant: [FontVariant.tabularNums],
          ),
        ),
      ],
    );
  }
}

class _Clock extends StatefulWidget {
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late Timer _timer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _time = TimeOfDay.now().format(context);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _time,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontVariant: [FontVariant.tabularNums],
      ),
    );
  }
}

/// Reconnection overlay
class _ReconnectionOverlay extends StatelessWidget {
  final ReconnectionStatus status;

  const _ReconnectionOverlay({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(48),
          margin: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F3E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phase indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _phaseColor(status.phase).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _phaseLabel(status.phase),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _phaseColor(status.phase),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Main message
              Text(
                status.message,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Component status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ComponentPill(
                    label: 'Logic Engine',
                    status: status.jarReconnecting 
                        ? ComponentStatus.reconnecting
                        : (status.phase == ReconnectionPhase.idle ? ComponentStatus.connected : ComponentStatus.disconnected),
                  ),
                  const SizedBox(width: 12),
                  _ComponentPill(
                    label: 'Feature Hub',
                    status: status.apkReconnecting 
                        ? ComponentStatus.reconnecting
                        : (status.phase == ReconnectionPhase.idle ? ComponentStatus.connected : ComponentStatus.disconnected),
                  ),
                ],
              ),
              
              // Attempt counter
              if (status.phase == ReconnectionPhase.fullRestart) ...[
                const SizedBox(height: 16),
                Text(
                  'Attempt ${status.attempt} of 2',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
              
              // Progress indicator
              if (status.phase != ReconnectionPhase.failed && status.phase != ReconnectionPhase.idle) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(strokeWidth: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _phaseColor(ReconnectionPhase phase) {
    switch (phase) {
      case ReconnectionPhase.quickReconnect:
        return Colors.blue;
      case ReconnectionPhase.fullRestart:
        return Colors.orange;
      case ReconnectionPhase.failed:
        return Colors.red;
      case ReconnectionPhase.idle:
        return Colors.green;
    }
  }

  String _phaseLabel(ReconnectionPhase phase) {
    switch (phase) {
      case ReconnectionPhase.quickReconnect:
        return 'QUICK RECONNECT';
      case ReconnectionPhase.fullRestart:
        return 'FULL RESTART';
      case ReconnectionPhase.failed:
        return 'CONNECTION LOST';
      case ReconnectionPhase.idle:
        return 'CONNECTED';
    }
  }
}

enum ComponentStatus { connected, reconnecting, disconnected }

class _ComponentPill extends StatelessWidget {
  final String label;
  final ComponentStatus status;

  const _ComponentPill({
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    
    switch (status) {
      case ComponentStatus.connected:
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case ComponentStatus.reconnecting:
        color = Colors.blue;
        icon = Icons.sync_rounded;
        break;
      case ComponentStatus.disconnected:
        color = Colors.red;
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}