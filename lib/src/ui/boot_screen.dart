import 'package:flutter/material.dart';
import 'package:phonedex/src/core/app_manager.dart';

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
  double _jarProgress = 0, _appProgress = 0;
  String _jarLabel = 'Waiting…', _appLabel = 'Starting…';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0A0E27), const Color(0xFF1A1F4A), _ctrl.value)!,
                Color.lerp(const Color(0xFF0D1136), const Color(0xFF151A3E), _ctrl.value)!,
                const Color(0xFF050815),
              ],
            )),
          ),
        ),
        Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(padding: const EdgeInsets.all(32), child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF006EFF).withOpacity(0.3), blurRadius: 30)],
                ),
                child: const Icon(Icons.phone_android_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text('PhoneDex', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Connecting your Android…', style: TextStyle(color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 40),
              _ProgressCard(label: 'Logic Engine', progress: _jarProgress, text: _jarLabel, color: Colors.blue),
              const SizedBox(height: 16),
              _ProgressCard(label: 'System', progress: _appProgress, text: _appLabel, color: Colors.purple),
              if (widget.errorMessage != null) ...[
                const SizedBox(height: 24),
                _ErrorBox(message: widget.errorMessage!, canPick: widget.canPickDevice, onPick: widget.onPickDevice),
              ],
              const SizedBox(height: 32),
              Text('PhoneDex v1.0.0', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
            ],
          )),
        )),
      ]),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String label, text;
  final double progress;
  final Color color;
  const _ProgressCard({required this.label, required this.progress, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), border: Border.all(color: color.withOpacity(0.2)), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
          const Spacer(),
          Text('${(p * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: Container(height: 6, color: Colors.white.withOpacity(0.08), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: p,
          child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]))))),
        const SizedBox(height: 10),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.7))),
      ]),
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
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), border: Border.all(color: Colors.red.withOpacity(0.4)), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: Colors.red[200]))),
        ]),
        if (canPick) ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: onPick, icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
            label: const Text('Open ADB Manager — Select Device'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.15), foregroundColor: Colors.blue[300],
              side: BorderSide(color: Colors.blue.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ],
      ]),
    );
  }
}