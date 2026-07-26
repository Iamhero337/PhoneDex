import 'package:flutter/material.dart';
import 'package:phonedex/src/core/device.dart';
import 'package:phonedex/src/adb/adb_provider.dart';

class BootScreen extends StatefulWidget {
  final String? errorMessage;
  final bool canPickDevice;
  final VoidCallback onPickDevice;
  final Function(ConnectionTarget)? onDirectConnect;

  const BootScreen({
    super.key,
    this.errorMessage,
    this.canPickDevice = false,
    required this.onPickDevice,
    this.onDirectConnect,
  });

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5555');
  final _adb = AdbProvider();
  
  bool _connecting = false;
  String? _quickError;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _ipCtrl.addListener(_onIpChanged);
  }

  void _onIpChanged() {
    final text = _ipCtrl.text.trim();
    final colonIdx = text.lastIndexOf(':');
    if (colonIdx > 0 && colonIdx < text.length - 1) {
      final possiblePort = text.substring(colonIdx + 1);
      if (possiblePort.isNotEmpty && int.tryParse(possiblePort) != null) {
        _ipCtrl.text = text.substring(0, colonIdx);
        _ipCtrl.selection = TextSelection.collapsed(offset: _ipCtrl.text.length);
        _portCtrl.text = possiblePort;
      }
    }
  }

  Future<void> _connectDirect() async {
    final ip = _ipCtrl.text.trim();
    final portStr = _portCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _quickError = 'Please enter an IP address');
      return;
    }
    final port = int.tryParse(portStr) ?? 5555;
    setState(() {
      _connecting = true;
      _quickError = null;
    });
    try {
      await _adb.startServer();
      final r = await _adb.connectDevice(ip, port);
      if (r.success || r.output.contains('already connected')) {
        if (mounted && widget.onDirectConnect != null) {
          widget.onDirectConnect!(WifiTarget(ip, port));
        }
      } else {
        setState(() => _quickError = r.output.length > 80 ? r.output.substring(0, 80) : r.output);
      }
    } catch (e) {
      setState(() => _quickError = 'Connection failed — check IP & Wi-Fi');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    _ipCtrl.removeListener(_onIpChanged);
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon & Header
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF006EFF).withValues(alpha: 0.4), blurRadius: 36),
                        ],
                      ),
                      child: const Icon(Icons.phone_android_rounded, size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'PhoneDex',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Transform your Android into a desktop experience',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Quick Connection Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13172E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wifi_find_rounded, size: 20, color: Colors.blue[300]),
                              const SizedBox(width: 8),
                              Text(
                                'Connect Device',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Direct IP Connect Bar
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ipCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Device IP (e.g. 192.168.1.100)',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _connectDirect(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 75,
                                child: TextField(
                                  controller: _portCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: '5555',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _connectDirect(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _connecting
                                  ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                                  : ElevatedButton(
                                      onPressed: _connectDirect,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF006EFF),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                            ],
                          ),
                          if (_quickError != null) ...[
                            const SizedBox(height: 8),
                            Text(_quickError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ],

                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Colors.white10),
                          const SizedBox(height: 16),

                          // Open ADB Manager / Select Device Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: widget.onPickDevice,
                              icon: const Icon(Icons.devices_rounded, size: 18),
                              label: const Text('Open ADB Device Manager & Wireless Pairing', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (widget.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBox(
                        message: widget.errorMessage!,
                        canPick: widget.canPickDevice,
                        onPick: widget.onPickDevice,
                      ),
                    ],

                    const SizedBox(height: 28),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.red[200], fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
