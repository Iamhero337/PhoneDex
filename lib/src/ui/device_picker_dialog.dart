import 'package:flutter/material.dart';
import 'package:phonedex/src/core/device.dart';
import 'package:phonedex/src/adb/adb_provider.dart';
import 'package:phonedex/src/utils/logger.dart';

class DevicePickerDialog extends StatefulWidget {
  final void Function(ConnectionTarget) onDeviceSelected;
  final VoidCallback onCancel;
  const DevicePickerDialog({super.key, required this.onDeviceSelected, required this.onCancel});

  @override
  State<DevicePickerDialog> createState() => _DevicePickerDialogState();
}

class _DevicePickerDialogState extends State<DevicePickerDialog> {
  final _log = AppLogger('Picker');
  final _adb = AdbProvider();

  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '5555');
  final _pairIpCtrl = TextEditingController();
  final _pairPortCtrl = TextEditingController(text: '37000');
  final _pairConnectPortCtrl = TextEditingController(text: '5555');
  final _pairCodeCtrl = TextEditingController();

  List<DeviceInfo> _devices = [];
  bool _scanning = false;
  String? _ipError;
  bool _connectingIp = false;
  String _connectResultMsg = '';

  bool _pairing = false;
  String? _pairError;
  String _pairResultMsg = '';

  final _showGuide = ValueNotifier<bool>(false);
  final _expandedSection = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _ipCtrl.addListener(_onIpChanged);
    _scan();
  }

  @override
  void dispose() {
    _ipCtrl.removeListener(_onIpChanged);
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pairIpCtrl.dispose();
    _pairPortCtrl.dispose();
    _pairConnectPortCtrl.dispose();
    _pairCodeCtrl.dispose();
    _showGuide.dispose();
    _expandedSection.dispose();
    super.dispose();
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

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _connectResultMsg = '';
      _ipError = null;
      _pairError = null;
      _pairResultMsg = '';
    });
    try {
      await _adb.startServer();
      final d = await _adb.getDevices();
      if (mounted) {
        setState(() {
          _devices = d;
          _scanning = false;
        });
      }
    } catch (e) {
      _log.error('Scan failed: $e');
      if (mounted) {
        setState(() {
          _scanning = false;
          _connectResultMsg = e.toString().contains('ADB not found')
              ? 'ADB not found on this system.\nInstall platform-tools and ensure adb is in PATH.'
              : 'Scan failed: $e';
        });
      }
    }
  }

  Future<void> _connectIp() async {
    final ip = _ipCtrl.text.trim();
    final portStr = _portCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _ipError = 'Enter an IP address');
      return;
    }
    final port = int.tryParse(portStr) ?? 5555;
    setState(() {
      _connectingIp = true;
      _ipError = null;
      _connectResultMsg = '';
    });
    try {
      await _adb.startServer();
      final r = await _adb.connectDevice(ip, port);
      if (r.success || r.output.contains('already connected')) {
        setState(() {
          _connectResultMsg = 'Connected to $ip:$port ✓';
          _ipError = null;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.pop(context);
          widget.onDeviceSelected(WifiTarget(ip, port));
        }
      } else {
        setState(() => _ipError = r.output.length > 100 ? r.output.substring(0, 100) : r.output);
      }
    } catch (e) {
      setState(() => _ipError = 'Connection failed — check IP and port');
      _log.error('Connect IP: $e');
    } finally {
      if (mounted) setState(() => _connectingIp = false);
    }
  }

  Future<void> _pairAndConnect() async {
    final ip = _pairIpCtrl.text.trim();
    final pairPortStr = _pairPortCtrl.text.trim();
    final connectPortStr = _pairConnectPortCtrl.text.trim();
    final code = _pairCodeCtrl.text.trim();

    if (ip.isEmpty) {
      setState(() => _pairError = 'Enter the IP shown on device');
      return;
    }
    final pairPort = int.tryParse(pairPortStr);
    if (pairPort == null) {
      setState(() => _pairError = 'Enter the pairing port');
      return;
    }
    if (code.isEmpty || code.length < 6) {
      setState(() => _pairError = 'Enter the 6-digit pairing code');
      return;
    }
    final connectPort = int.tryParse(connectPortStr) ?? 5555;

    setState(() {
      _pairing = true;
      _pairError = null;
      _pairResultMsg = '';
    });

    try {
      await _adb.startServer();
      final r = await _adb.pairDevice(ip, pairPort, code);
      if (r.success || r.output.contains('Successfully paired')) {
        setState(() {
          _pairResultMsg = 'Paired successfully ✓ Connecting to $ip:$connectPort…';
          _pairError = null;
        });
        
        // Attempt connect on target connectPort as well as pairPort
        final connRes = await _adb.connectDevice(ip, connectPort);
        if (!connRes.success) {
          await _adb.connectDevice(ip, pairPort);
        }
        
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.pop(context);
          widget.onDeviceSelected(WifiTarget(ip, connectPort));
        }
      } else {
        setState(() => _pairError = r.output.length > 120 ? r.output.substring(0, 120) : r.output);
      }
    } catch (e) {
      setState(() => _pairError = 'Pairing failed — check pairing code & port');
      _log.error('Pair error: $e');
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  Future<void> _select(DeviceInfo d) async {
    if (!d.isAuthorized) {
      setState(() => _connectResultMsg = 'Device "${d.id}" is unauthorized.\nAccept the USB debugging popup on your phone screen.');
      return;
    }
    await _adb.startServer();
    if (d.isUsb) {
      final ip = await _adb.getDeviceIp(d.id);
      if (ip != null && ip.isNotEmpty) {
        final switched = await _adb.switchToWireless(d.id);
        if (switched != null && mounted) {
          Navigator.pop(context);
          widget.onDeviceSelected(WifiTarget(switched, 5555));
          return;
        }
      }
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onDeviceSelected(
        d.isWifi
            ? WifiTarget(d.id.split(':').first, int.tryParse(d.id.split(':').last))
            : UsbTarget(d.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: const Color(0xFF13172E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceSection(),
                    const SizedBox(height: 12),
                    _buildManualConnect(),
                    const SizedBox(height: 12),
                    _buildPairingSection(),
                    const SizedBox(height: 12),
                    _buildGuideToggle(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: const Color(0xFF006EFF).withValues(alpha: 0.3), blurRadius: 10),
              ],
            ),
            child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PhoneDex ADB Manager',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a connected device or pair wirelessly',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Connected Devices',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
            ),
            const Spacer(),
            SizedBox(
              height: 32,
              child: _scanning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Scan Devices', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[300],
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_scanning)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Scanning for ADB devices…', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          )
        else if (_devices.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Icon(Icons.usb_off_rounded, size: 36, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 10),
                Text('No active devices detected', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Plug in USB cable with USB Debugging ON, or use Wireless Debugging below',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._devices.map((d) => _DeviceRow(device: d, onTap: () => _select(d))),
        if (_connectResultMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_connectResultMsg.contains('✓') ? Colors.green : Colors.blue).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (_connectResultMsg.contains('✓') ? Colors.green : Colors.blue).withValues(alpha: 0.3)),
            ),
            child: Text(
              _connectResultMsg,
              style: TextStyle(
                color: (_connectResultMsg.contains('✓') ? Colors.green : Colors.blue)[200],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualConnect() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_find_rounded, size: 18, color: Colors.blue[300]),
              const SizedBox(width: 8),
              Text(
                'Direct Wi-Fi Connection',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('IP : Port', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue[300])),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '192.168.1.100',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _connectIp(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 85,
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
                  onSubmitted: (_) => _connectIp(),
                ),
              ),
              const SizedBox(width: 8),
              _connectingIp
                  ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : ElevatedButton(
                      onPressed: _connectIp,
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
          if (_ipError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(_ipError!, style: TextStyle(color: Colors.red[200], fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPairingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Android 11+', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green[300])),
              ),
              const SizedBox(width: 8),
              Text(
                'Wireless Debugging Pairing',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pairIpCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Device IP address',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 75,
                child: TextField(
                  controller: _pairPortCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Pair Port',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pairCodeCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '6-digit pairing code',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _pairing
                  ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : ElevatedButton.icon(
                      onPressed: _pairAndConnect,
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Pair & Connect', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.25),
                        foregroundColor: Colors.green[300],
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                    ),
            ],
          ),
          if (_pairError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_pairError!, style: TextStyle(color: Colors.red[200], fontSize: 11)),
            ),
          ],
          if (_pairResultMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_pairResultMsg, style: TextStyle(color: Colors.green[200], fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideToggle() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showGuide,
      builder: (_, show, __) => Column(
        children: [
          InkWell(
            onTap: () => _showGuide.value = !_showGuide.value,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Text('Step-by-step Setup Guide', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500, fontSize: 13)),
                  const Spacer(),
                  Icon(show ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
                ],
              ),
            ),
          ),
          if (show) ...[
            const SizedBox(height: 8),
            _buildGuideContent(),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideContent() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to setup your Android device:',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ..._guideSteps.entries.map((e) => _GuideStep(
                index: e.key,
                title: e.value.title,
                content: e.value.content,
                isExpanded: _expandedSection.value == e.key,
                onToggle: () => _expandedSection.value = _expandedSection.value == e.key ? null : e.key,
              )),
        ],
      ),
    );
  }

  static const _guideSteps = {
    1: _GuideData(
      title: 'Step 1: Enable Developer Options',
      content: '1. Settings → About Phone → Software Information\n'
          '2. Tap "Build Number" 7 times rapidly\n'
          '3. Enter PIN if prompted until "Developer mode enabled" appears',
    ),
    2: _GuideData(
      title: 'Step 2: Enable USB Debugging',
      content: '1. Settings → Developer Options → USB Debugging → Turn ON\n'
          '2. Plug in phone via USB cable\n'
          '3. Accept "Allow USB Debugging?" prompt on phone screen',
    ),
    3: _GuideData(
      title: 'Step 3: Wireless Debugging (Android 11+)',
      content: '1. Enable "Wireless Debugging" in Developer Options\n'
          '2. Tap "Pair device with pairing code"\n'
          '3. Enter IP, Pair Port, and 6-digit code in the Pair & Connect section',
    ),
  };

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh List'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[300],
              side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}

class _GuideData {
  final String title;
  final String content;
  const _GuideData({required this.title, required this.content});
}

class _GuideStep extends StatelessWidget {
  final int index;
  final String title;
  final String content;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _GuideStep({
    required this.index,
    required this.title,
    required this.content,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF006EFF).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text('$index', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue[300])),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: Colors.white.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(content, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatefulWidget {
  final DeviceInfo device;
  final VoidCallback onTap;
  const _DeviceRow({required this.device, required this.onTap});
  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _hover = false;
  bool _connecting = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final isUsb = d.isUsb;
    final authorized = d.isAuthorized;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: authorized && !_connecting
            ? () async {
                setState(() => _connecting = true);
                try {
                  widget.onTap();
                } finally {
                  if (mounted) setState(() => _connecting = false);
                }
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hover && authorized ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
            border: Border.all(
              color: !authorized
                  ? Colors.orange.withValues(alpha: 0.4)
                  : _hover
                      ? Colors.blue.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.06),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (authorized ? (isUsb ? Colors.blue : Colors.green) : Colors.orange).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUsb ? Icons.usb_rounded : Icons.wifi_rounded,
                  color: (authorized ? (isUsb ? Colors.blue : Colors.green) : Colors.orange)[300],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                          ),
                        ),
                        if (d.isWifi) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Wi-Fi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[300])),
                          ),
                        ],
                        if (!authorized) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(d.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange[300])),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !authorized
                          ? 'Authorize on your phone, then tap Refresh List'
                          : d.isWifi
                              ? d.id
                              : 'USB Device (${d.id}) — tap to connect',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (_connecting)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else if (authorized)
                AnimatedOpacity(
                  opacity: _hover ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.blue[300], size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
