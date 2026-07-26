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
  final _pairCodeCtrl = TextEditingController();

  List<DeviceInfo> _devices = [];
  bool _scanning = false;
  String? _ipError;
  bool _connectingIp = false;
  String _connectResultMsg = '';

  bool _pairing = false;
  String? _pairError;
  String _pairResultMsg = '';

  final _showGuide = ValueNotifier(false);
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
      if (mounted) setState(() {
        _devices = d;
        _scanning = false;
      });
    } catch (e) {
      _log.error('Scan failed: $e');
      if (mounted) setState(() {
        _scanning = false;
        _connectResultMsg = e.toString().contains('ADB not found')
            ? 'ADB not found on this system.\nInstall platform-tools and ensure adb is in PATH.'
            : 'Scan failed: $e';
      });
    }
  }

  Future<void> _connectIp() async {
    final ip = _ipCtrl.text.trim();
    final portStr = _portCtrl.text.trim();
    if (ip.isEmpty) { setState(() => _ipError = 'Enter an IP address'); return; }
    final port = int.tryParse(portStr) ?? 5555;
    setState(() { _connectingIp = true; _ipError = null; _connectResultMsg = ''; });
    try {
      await _adb.startServer();
      final r = await _adb.connectDevice(ip, port);
      if (r.success || r.output.contains('already connected')) {
        setState(() { _connectResultMsg = 'Connected to $ip:$port ✓'; _ipError = null; });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) { Navigator.pop(context); widget.onDeviceSelected(WifiTarget(ip, port)); }
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
    final portStr = _pairPortCtrl.text.trim();
    final code = _pairCodeCtrl.text.trim();
    if (ip.isEmpty) { setState(() => _pairError = 'Enter the IP shown on device'); return; }
    final port = int.tryParse(portStr);
    if (port == null) { setState(() => _pairError = 'Enter the port shown on device'); return; }
    if (code.isEmpty || code.length < 6) { setState(() => _pairError = 'Enter the 6-digit pairing code'); return; }
    setState(() { _pairing = true; _pairError = null; _pairResultMsg = ''; });
    try {
      await _adb.startServer();
      final r = await _adb.pairDevice(ip, port, code);
      if (r.success) {
        setState(() { _pairResultMsg = 'Paired ✓ Connecting…'; _pairError = null; });
        await _adb.connectDevice(ip, 5555);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) { Navigator.pop(context); widget.onDeviceSelected(WifiTarget(ip, 5555)); }
      } else {
        setState(() => _pairError = r.output.length > 100 ? r.output.substring(0, 100) : r.output);
      }
    } catch (e) {
      setState(() => _pairError = 'Pairing failed — check the code and try again');
      _log.error('Pair: $e');
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  Future<void> _select(DeviceInfo d) async {
    if (!d.isAuthorized) {
      setState(() => _connectResultMsg = 'Device "${d.id}" is not authorized.\nAccept the USB debugging prompt on your phone, then tap Refresh.');
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
    Navigator.pop(context);
    widget.onDeviceSelected(d.isWifi
        ? WifiTarget(d.id.split(':').first, int.tryParse(d.id.split(':').last))
        : const UsbTarget());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildHeader(),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildDeviceSection(),
              const SizedBox(height: 10),
              _buildManualConnect(),
              const SizedBox(height: 10),
              _buildPairingSection(),
              const SizedBox(height: 10),
              _buildGuideToggle(),
              const SizedBox(height: 8),
            ]),
          )),
          _buildFooter(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF006EFF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.phone_android_rounded, color: Color(0xFF006EFF), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PhoneDex — ADB Manager', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Select a device or connect wirelessly', style: TextStyle(color: Colors.white.withOpacity(0.6))),
        ])),
      ]),
    );
  }

  Widget _buildDeviceSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Connected Devices', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white70)),
        const Spacer(),
        SizedBox(
          height: 32,
          child: _scanning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[300],
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
        ),
      ]),
      const SizedBox(height: 6),
      if (_scanning)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('Scanning for devices…', style: TextStyle(color: Colors.white70))),
        )
      else if (_devices.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(Icons.usb_off_rounded, size: 32, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text('No devices found', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 4),
            Text('Connect via USB or use Wireless Debugging',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Scan Again'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue[300]),
            ),
          ]),
        )
      else
        ..._devices.map((d) => _DeviceRow(device: d, onTap: () => _select(d))),
      if (_connectResultMsg.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (_connectResultMsg.contains('✓') ? Colors.green : Colors.blue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_connectResultMsg, style: TextStyle(
            color: (_connectResultMsg.contains('✓') ? Colors.green : Colors.blue)[200],
            fontSize: 12,
          )),
        ),
      ],
    ]);
  }

  Widget _buildManualConnect() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.wifi_find_rounded, size: 16, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text('Manual Connect', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white70)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text('IP:Port', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400])),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ipCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '192.168.0.196', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                isDense: true,
              ),
              onSubmitted: (_) => _connectIp(),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _portCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '5555', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                isDense: true,
              ),
              onSubmitted: (_) => _connectIp(),
            ),
          ),
          const SizedBox(width: 6),
          _connectingIp
              ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : ElevatedButton(
                  onPressed: _connectIp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ]),
        if (_ipError != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_ipError!, style: TextStyle(color: Colors.red[200], fontSize: 11)),
          ),
        ],
      ]),
    );
  }

  Widget _buildPairingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text('Android 11+', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[300])),
          ),
          const SizedBox(width: 6),
          Text('Wireless Debugging Pair', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _pairIpCtrl, style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'IP address', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _pairPortCtrl, style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Port', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                isDense: true,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _pairCodeCtrl, style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '6-digit pairing code', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _pairing
              ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : ElevatedButton(
                  onPressed: _pairAndConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    foregroundColor: Colors.green[300],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: Colors.green.withOpacity(0.4)),
                  ),
                  child: const Text('Pair & Connect', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ]),
        if (_pairError != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_pairError!, style: TextStyle(color: Colors.red[200], fontSize: 11)),
          ),
        ],
        if (_pairResultMsg.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_pairResultMsg, style: TextStyle(color: Colors.green[200], fontSize: 11)),
          ),
        ],
      ]),
    );
  }

  Widget _buildGuideToggle() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showGuide,
      builder: (_, show, __) => Column(children: [
        InkWell(
          onTap: () => _showGuide.value = !_showGuide.value,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(children: [
              Icon(Icons.help_outline_rounded, size: 16, color: Colors.white.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text('Setup Guide', style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500, fontSize: 13)),
              const Spacer(),
              Icon(show ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white.withOpacity(0.5), size: 20),
            ]),
          ),
        ),
        if (show) ...[
          const SizedBox(height: 6),
          _buildGuideContent(),
        ],
      ]),
    );
  }

  Widget _buildGuideContent() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How to connect your Android device',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 10),
        ..._guideSteps.entries.map((e) => _GuideStep(
          index: e.key,
          title: e.value.title,
          content: e.value.content,
          isExpanded: _expandedSection.value == e.key,
          onToggle: () => _expandedSection.value = _expandedSection.value == e.key ? null : e.key,
        )),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber[300]),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Wireless Debugging (Android 11+) is the easiest method.\n'
              'Use Pair & Connect with the code shown on your device.',
              style: TextStyle(color: Colors.amber[200], fontSize: 11),
            )),
          ]),
        ),
      ]),
    );
  }

  static const _guideSteps = {
    1: _GuideData(
      title: 'Step 1: Enable Developer Options',
      content: '1. Open Settings → About Phone → Software Information\n'
          '2. Tap "Build Number" 7 times rapidly\n'
          '3. Enter your PIN if prompted\n'
          '4. You\'ll see "You are now a developer!"',
    ),
    2: _GuideData(
      title: 'Step 2: Enable USB Debugging',
      content: '1. Settings → Developer Options → USB Debugging → ON\n'
          '2. Tap OK to confirm\n'
          '3. If using USB, plug in your phone\n'
          '4. Accept "Allow USB Debugging?" on your phone\n'
          '   (Check "Always allow from this computer")',
    ),
    3: _GuideData(
      title: 'Step 3 (Option A): Wireless Debugging (Android 11+)',
      content: '1. Developer Options → toggle ON "Wireless Debugging"\n'
          '2. Tap "Wireless Debugging" → "Pair device with pairing code"\n'
          '3. Note the IP, port, and 6-digit code shown on screen\n'
          '4. Enter them in the "Pair & Connect" section above\n'
          '5. Phone will show "Connected to PhoneDex"',
    ),
    4: _GuideData(
      title: 'Step 3 (Option B): Manual Wi-Fi ADB',
      content: '1. Connect phone via USB first\n'
          '2. On PC: adb tcpip 5555 (or tap USB device to auto-switch)\n'
          '3. Disconnect USB cable\n'
          '4. Get phone IP: Settings → About Phone → Status → IP\n'
          '5. Enter IP:5555 in "Manual Connect" above',
    ),
    5: _GuideData(
      title: 'Step 3 (Option C): Use USB Cable',
      content: '1. Plug phone in via USB\n'
          '2. Accept "Allow USB Debugging?" on phone\n'
          '3. Device appears in list above — tap to connect\n'
          '4. App will try to switch to wireless automatically',
    ),
  };

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        SizedBox(
          height: 36,
          child: _scanning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : OutlinedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh Devices', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[300],
                    side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
        ),
        TextButton(
          onPressed: () { Navigator.pop(context); widget.onCancel(); },
          child: const Text('Cancel', style: TextStyle(fontSize: 13)),
        ),
      ]),
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
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF006EFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text('$index', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue[300]))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
              Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: Colors.white.withOpacity(0.4)),
            ]),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(content, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, height: 1.4)),
          ),
      ]),
    );
  }
}

class _DeviceRow extends StatefulWidget {
  final DeviceInfo device;
  final VoidCallback onTap;
  const _DeviceRow({required this.device, required this.onTap});
  @override State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final isUsb = d.isUsb;
    final authorized = d.isAuthorized;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: authorized ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover && authorized ? Colors.white.withOpacity(0.05) : Colors.transparent,
            border: Border.all(
              color: !authorized ? Colors.orange.withOpacity(0.4)
                  : _hover ? Colors.blue.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (authorized ? (isUsb ? Colors.blue : Colors.green) : Colors.orange).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isUsb ? Icons.usb_rounded : Icons.wifi_rounded,
                color: (authorized ? (isUsb ? Colors.blue : Colors.green) : Colors.orange)[300],
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(d.displayName, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13))),
                if (d.isWifi) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                    child: Text('Wi-Fi', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.green[300])),
                  ),
                ],
                if (!authorized) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                    child: Text(d.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orange[300])),
                  ),
                ],
              ]),
              Text(
                !authorized ? 'Authorize on your phone then tap Refresh'
                    : d.isWifi ? d.id : 'USB — tap to connect',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
              ),
            ])),
            if (authorized)
              AnimatedOpacity(
                opacity: _hover ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.4), size: 20),
              ),
          ]),
        ),
      ),
    );
  }
}
