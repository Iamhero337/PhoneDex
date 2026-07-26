import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class BootScreen extends StatefulWidget {
  final String? errorMessage;
  final bool canPickDevice;
  final VoidCallback onPickDevice;
  const BootScreen({super.key, this.errorMessage, this.canPickDevice = false, required this.onPickDevice});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(const Color(0xFF0A0E27), const Color(0xFF1A1F4A), _ctrl.value)!,
                    Color.lerp(const Color(0xFF0D1136), const Color(0xFF151A3E), _ctrl.value)!,
                    const Color(0xFF050815),
                  ],
                ),
              ),
            ),
          ),
          // Custom Window Title Bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: MoveWindow(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F3E).withValues(alpha: 0.9),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PhoneDex',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const Spacer(),
                    WindowTitleBarBox(
                      child: Row(
                        children: [
                          MinimizeWindowButton(colors: WindowButtonColors(iconNormal: Colors.white.withValues(alpha: 0.5), mouseOver: Colors.white.withValues(alpha: 0.1))),
                          CloseWindowButton(colors: WindowButtonColors(iconNormal: Colors.white.withValues(alpha: 0.5), mouseOver: Colors.red.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF006EFF).withValues(alpha: 0.4), blurRadius: 36),
                        ],
                      ),
                      child: const Icon(Icons.phone_android_rounded, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'PhoneDex',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Transform your Android into a desktop experience',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (widget.errorMessage != null) ...[
                      _ErrorBox(
                        message: widget.errorMessage!,
                        canPick: widget.canPickDevice,
                        onPick: widget.onPickDevice,
                      ),
                    ] else ...[
                      Text('Initializing background services…', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(height: 16),
                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                    const SizedBox(height: 32),
                    Text('PhoneDex v1.2.0', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final bool canPick;
  final VoidCallback onPick;
  const _ErrorBox({required this.message, required this.canPick, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.red[200], fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          if (canPick) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.wifi_find_rounded, size: 18),
                label: const Text('Open ADB Manager — Select Device'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006EFF).withValues(alpha: 0.25),
                  foregroundColor: const Color(0xFF60A5FA),
                  side: BorderSide(color: const Color(0xFF006EFF).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
