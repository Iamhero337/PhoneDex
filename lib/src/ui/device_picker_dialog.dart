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
    _scan();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _pairIpCtrl.dispose();
    _pairPortCtrl.dispose();
    _pairCodeCtrl.dispose();
    _showGuide.dispose();
    _expandedSection.dispose();
    super.dispose();
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
        _connectResultMsg = 'ADB scan failed: $e';
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
        setState(() => _ipError = r.output.length > 80 ? r.output.substring(0, 80) : r.output);
      }
    } catch (e) {
      setState(() => _ipError = 'Connection failed');
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
        setState(() { _pairResultMsg = 'Paired successfully ✓'; _pairError = null; });
        await _adb.connectDevice(ip, 5555);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.pop(context);
          widget.onDeviceSelected(WifiTarget(ip, 5555));
        }
      } else {
        setState(() => _pairError = r.output.length > 100 ? r.output.substring(0, 100) : r.output);
      }
    } catch (e) {
      setState(() => _pairError = 'Pairing failed — check IP/port/code');
      _log.error('Pair: $e');
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  Future<void> _select(DeviceInfo d) async {
    if (!d.isAuthorized) {
      setState(() => _connectResultMsg = 'Device "${d.id}" is not authorized.\nAccept the USB debugging prompt on your device and tap Refresh.');
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
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildHeader(),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              _buildDeviceSection(),
              const SizedBox(height: 8),
              _buildManualConnect(),
              const SizedBox(height: 8),
              _buildPairingSection(),
              const SizedBox(height: 8),
              _buildGuideToggle(),
              const SizedBox(height: 12),
            ]),
          )),
          _buildFooter(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        if (_scanning)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else
          InkWell(
            onTap: _scan,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.refresh_rounded, size: 20, color: Colors.white.withOpacity(0.6)),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      if (_scanning)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('Scanning for devices…', style: TextStyle(color: Colors.white70))),
        )
      else if (_devices.isEmpty)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(Icons.usb_off_rounded, size: 36, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No devices found', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 6),
            Text('Connect via USB or use the pairing section below', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ]),
        )
      else
        ..._devices.map((d) => _DeviceRow(
          device: d,
          onTap: () => _select(d),
        )),
      if (_connectResultMsg.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(_connectResultMsg, style: TextStyle(color: Colors.blue[200], fontSize: 12)),
        ),
      ],
    ]);
  }

  Widget _buildManualConnect() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.wifi_find_rounded, size: 18, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text('Manual Connect (Wi-Fi ADB)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 3, child: TextField(
            controller: _ipCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '192.168.1.100', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            onSubmitted: (_) => _connectIp(),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: TextField(
            controller: _portCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '5555', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              isDense: true,
            ),
            onSubmitted: (_) => _connectIp(),
          )),
          const SizedBox(width: 8),
          _connectingIp
              ? const SizedBox(width: 44, height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : ElevatedButton(
                  onPressed: _connectIp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ]),
        if (_ipError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_ipError!, style: TextStyle(color: Colors.red[200], fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  Widget _buildPairingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
            child: Text('Android 11+', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[300])),
          ),
          const SizedBox(width: 8),
          Text('Wireless Debugging Pair', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 2, child: TextField(
            controller: _pairIpCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'IP from device', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 1, child: TextField(
            controller: _pairPortCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Port', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              isDense: true,
            ),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: TextField(
            controller: _pairCodeCtrl, style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Pairing code', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _pairing
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                : ElevatedButton.icon(
                    onPressed: _pairAndConnect,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Pair & Connect', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      foregroundColor: Colors.green[300],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.green.withOpacity(0.4)),
                    ),
                  ),
          ),
        ]),
        if (_pairError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_pairError!, style: TextStyle(color: Colors.red[200], fontSize: 12)),
          ),
        ],
        if (_pairResultMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_pairResultMsg, style: TextStyle(color: Colors.green[200], fontSize: 12)),
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
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(children: [
              Icon(Icons.help_outline_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text('Setup Guide', style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(show ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white.withOpacity(0.5)),
            ]),
          ),
        ),
        if (show) ...[
          const SizedBox(height: 8),
          _buildGuideContent(),
        ],
      ]),
    );
  }

  Widget _buildGuideContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How to connect your Android device', style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ..._guideSteps.entries.map((e) => _GuideStep(
          index: e.key,
          title: e.value.title,
          content: e.value.content,
          isExpanded: _expandedSection.value == e.key,
          onToggle: () => _expandedSection.value = _expandedSection.value == e.key ? null : e.key,
        )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.amber[300]),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Tip: Wireless Debugging (Android 11+) is the easiest method. '
              'Use the "Pair & Connect" section above with the code shown on your device.',
              style: TextStyle(color: Colors.amber[200], fontSize: 12),
            )),
          ]),
        ),
      ]),
    );
  }

  static const _guideSteps = {
    1: _GuideData(
      title: 'Step 1: Enable Developer Options',
      content: '1. Open Settings\n'
          '2. Scroll down to "About Phone" → "Software Information"\n'
          '3. Tap "Build Number" 7 times rapidly\n'
          '4. Enter your PIN/pattern if prompted\n'
          '5. You will see "You are now a developer!"',
    ),
    2: _GuideData(
      title: 'Step 2: Enable USB Debugging',
      content: '1. Go back to Settings → "Developer Options"\n'
          '2. Toggle ON "USB Debugging"\n'
          '3. Tap "OK" to confirm\n'
          '4. If connecting via USB, plug in your phone now\n'
          '5. Accept the "Allow USB Debugging?" prompt on your phone\n'
          '   (Check "Always allow from this computer")',
    ),
    3: _GuideData(
      title: 'Step 3 (Option A): Wireless Debugging (Android 11+)',
      content: '1. In Developer Options, toggle ON "Wireless Debugging"\n'
          '2. Tap "Wireless Debugging" to enter the submenu\n'
          '3. Tap "Pair device with pairing code"\n'
          '4. Note the IP address, port, and 6-digit code shown\n'
          '5. Enter these in the "Pair & Connect" section above\n'
          '6. The phone should show "Connected to PhoneDex"',
    ),
    4: _GuideData(
      title: 'Step 3 (Option B): Manual Wi-Fi ADB',
      content: '1. Connect your phone via USB first\n'
          '2. On your PC, run: adb tcpip 5555\n'
          '3. Disconnect the USB cable\n'
          '4. Get your phone\'s IP address:\n'
          '   • Settings → About Phone → Status → IP Address\n'
          '   • Or Wi-Fi settings → tap connected network\n'
          '5. Enter the IP and port (5555) in "Manual Connect" above\n'
          '6. Or select the device from the list and it will auto-switch',
    ),
    5: _GuideData(
      title: 'Step 3 (Option C): Connect via USB',
      content: '1. Plug in your phone via USB cable\n'
          '2. Accept "Allow USB Debugging?" on your phone\n'
          '3. The device will appear in the list above\n'
          '4. Tap it to connect\n'
          '5. If your phone has Wi-Fi, the app will try to switch to wireless',
    ),
  };

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton.icon(
          onPressed: _scanning ? null : _scan,
          icon: Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () { Navigator.pop(context); widget.onCancel(); },
          child: const Text('Cancel'),
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
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF006EFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text('$index', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue[300]))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
              Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: Colors.white.withOpacity(0.4)),
            ]),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(content, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.5)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hover && authorized ? Colors.white.withOpacity(0.05) : Colors.transparent,
            border: Border.all(
              color: !authorized ? Colors.orange.withOpacity(0.4)
                  : _hover ? Colors.blue.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (authorized ? (isUsb ? Colors.blue : Colors.green) : Colors.orange).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isUsb ? Icons.usb_rounded : Icons.wifi_rounded,
                color: (authorized ? (isUsb ? Colors.blue : Colors.green) : Colors.orange)[300],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(d.displayName, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white))),
                if (d.isWifi) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Wi-Fi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[300])),
                  ),
                ],
                if (!authorized) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(d.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange[300])),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                !authorized ? 'Tap Refresh after authorizing on device'
                    : d.isWifi ? d.id : 'USB — tap to connect',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ])),
            if (authorized)
              AnimatedOpacity(
                opacity: _hover ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.4), size: 22),
              ),
          ]),
        ),
      ),
    );
  }
}
