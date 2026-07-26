import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// Boot screen with progress bars
class BootScreen extends ConsumerStatefulWidget {
  final String? errorMessage;
  final bool canPickDevice;
  final VoidCallback onPickDevice;

  const BootScreen({
    super.key,
    this.errorMessage,
    this.canPickDevice = false,
    required this.onPickDevice,
  });

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gradientShift;

  double _jarProgress = 0.0;
  String _jarLabel = 'Waiting…';
  bool _jarError = false;
  bool _jarComplete = false;

  double _appProgress = 0.0;
  String _appLabel = 'Starting…';
  bool _appError = false;
  bool _appComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    
    _gradientShift = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          _AnimatedBackground(animation: _gradientShift),
          
          // Window drag area
          Positioned.fill(
            child: MoveWindow(
              child: Container(),
            ),
          ),

          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    _Logo(),
                    const SizedBox(height: 40),

                    // Title
                    Text(
                      'PhoneDex',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecting your Android…',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // JAR Progress Bar
                    _ProgressCard(
                      label: 'Logic Engine',
                      progress: _jarProgress,
                      statusText: _jarLabel,
                      isError: _jarError,
                      isComplete: _jarComplete,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),

                    // APP Progress Bar
                    _ProgressCard(
                      label: 'System',
                      progress: _appProgress,
                      statusText: _appLabel,
                      isError: _appError,
                      isComplete: _appComplete,
                      color: Colors.purple,
                    ),

                    // Error display
                    if (widget.errorMessage != null) ...[
                      const SizedBox(height: 24),
                      _ErrorBox(
                        message: widget.errorMessage!,
                        canPickDevice: widget.canPickDevice,
                        onPickDevice: widget.onPickDevice,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Version badge
                    Text(
                      'PhoneDex v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Window controls
          Positioned(
            top: 0,
            right: 0,
            child: WindowTitleBarBox(
              child: Row(
                children: [
                  MinimizeWindowButton(colors: _buttonColors),
                  MaximizeWindowButton(colors: _buttonColors),
                  CloseWindowButton(colors: _buttonColors),
                ],
              ),
            ),
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

/// Animated gradient background
class _AnimatedBackground extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0A0E27), const Color(0xFF1A1F4A), animation.value)!,
                Color.lerp(const Color(0xFF0D1136), const Color(0xFF151A3E), animation.value)!,
                const Color(0xFF050815),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _MeshPainter(animation.value),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double progress;

  _MeshPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: Alignment(0.3 + 0.4 * progress, -0.5 + 0.3 * progress),
        radius: 1.2,
        colors: [
          const Color(0xFF006EFF).withOpacity(0.08),
          const Color(0xFF7C3AED).withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Logo widget
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF006EFF), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006EFF).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.phone_android_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Progress card with animated bar
class _ProgressCard extends StatelessWidget {
  final String label;
  final double progress;
  final String statusText;
  final bool isError;
  final bool isComplete;
  final Color color;

  const _ProgressCard({
    required this.label,
    required this.progress,
    required this.statusText,
    this.isError = false,
    this.isComplete = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = isError ? Colors.red : color;
    final displayProgress = isComplete ? 1.0 : progress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(
          color: displayColor.withOpacity(isError || isComplete ? 0.5 : 0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: displayColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: displayColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${(displayProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontVariant: [FontVariant.tabularNums],
                  color: displayColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              // Background track
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Progress bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [
                      displayColor,
                      displayColor.withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: displayColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: displayProgress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [
                          displayColor,
                          displayColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isComplete)
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Colors.green[300],
                )
              else if (isError)
                Icon(
                  Icons.error_rounded,
                  size: 16,
                  color: Colors.red[300],
                )
              else
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(displayColor),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isError ? Colors.red[300] : Colors.white.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Error box with optional device picker button
class _ErrorBox extends StatelessWidget {
  final String message;
  final bool canPickDevice;
  final VoidCallback onPickDevice;

  const _ErrorBox({
    required this.message,
    required this.canPickDevice,
    required this.onPickDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[200],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (canPickDevice) ...[
          const SizedBox(height: 12),
          _GlowButton(
            icon: Icons.bluetooth_searching_rounded,
            label: 'Open ADB Manager — Select Device',
            onPressed: onPickDevice,
            glowColor: Colors.blue,
          ),
        ],
      ],
    );
  }
}

/// Glowing button
class _GlowButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color glowColor;

  const _GlowButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.glowColor,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) {
          return InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.glowColor.withOpacity(
                    _hovered ? 0.6 : 0.3 * _glowAnimation.value,
                  ),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withOpacity(
                      _hovered ? 0.3 : 0.15 * _glowAnimation.value,
                    ),
                    blurRadius: _hovered ? 20 : 10,
                    spreadRadius: _hovered ? 2 : 0,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    widget.glowColor.withOpacity(0.1),
                    widget.glowColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: widget.glowColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.glowColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}