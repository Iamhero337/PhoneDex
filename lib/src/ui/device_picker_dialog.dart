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
  final _ipCtrl = TextEditingController();
  final _adb = AdbProvider();
  List<DeviceInfo> _devices = [];
  bool _scanning = false;
  String? _ipError;
  bool _connectingIp = false;

  @override
  void initState() { super.initState(); _scan(); }
  @override void dispose() { _ipCtrl.dispose(); super.dispose(); }

  Future<void> _scan() async {
    setState(() { _scanning = true; _devices = []; });
    try { final d = await _adb.getDevices(); if (mounted) setState(() { _devices = d; _scanning = false; }); }
    catch (_) { if (mounted) setState(() => _scanning = false); }
  }

  Future<void> _connectIp() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) { setState(() => _ipError = 'Enter a valid IP'); return; }
    setState(() { _connectingIp = true; _ipError = null; });
    try {
      final r = await _adb.connectWifi(ip);
      if (r.success || r.output.contains('already connected')) {
        Navigator.pop(context);
        widget.onDeviceSelected(WifiTarget(ip));
      } else {
        setState(() => _ipError = 'Unable to connect to $ip');
      }
    } catch (_) {
      setState(() => _ipError = 'Connection failed — check Wi-Fi ADB is enabled');
    } finally { if (mounted) setState(() => _connectingIp = false); }
  }

  void _select(DeviceInfo d) {
    Navigator.pop(context);
    widget.onDeviceSelected(d.isWifi ? WifiTarget(d.id.split(':').first, int.tryParse(d.id.split(':').last)) : const UsbTarget());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480, constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(color: const Color(0xFF1A1F3E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF006EFF).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_android_rounded, color: Color(0xFF006EFF), size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PhoneDex — ADB Manager', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Tap a device to connect', style: TextStyle(color: Colors.white.withOpacity(0.6))),
              ])),
            ]),
          ),
          // Device list
          Flexible(child: _scanning
            ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(height: 16), Text('Scanning…', style: TextStyle(color: Colors.white70))]))
            : _devices.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.usb_off_rounded, size: 48, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No ADB devices found', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  const SizedBox(height: 8),
                  Text('Enable USB Debugging or\nWireless Debugging on your device', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8), shrinkWrap: true,
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(0.05), indent: 16, endIndent: 16),
                  itemBuilder: (_, i) => _DeviceRow(device: _devices[i], onTap: () => _select(_devices[i])),
                ),
          ),
          // IP connect
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Connect via IP', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: _ipCtrl, style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '192.168.1.100', hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    errorText: _ipError, filled: true, fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _connectIp(),
                )),
                const SizedBox(width: 12),
                _connectingIp
                  ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : ElevatedButton(onPressed: _connectIp, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006EFF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Connect')),
              ]),
            ]),
          ),
          // Footer
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: _scan, child: const Text('Refresh')),
              const SizedBox(width: 12),
              TextButton(onPressed: () { Navigator.pop(context); widget.onCancel(); }, child: const Text('Cancel')),
            ]),
          ),
        ]),
      ),
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
    final isUsb = widget.device.isUsb;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: _hover ? Colors.white.withOpacity(0.05) : Colors.transparent,
            border: Border.all(color: _hover ? Colors.blue.withOpacity(0.5) : Colors.transparent, width: 1.5), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isUsb ? Colors.blue : Colors.green).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(isUsb ? Icons.usb_rounded : Icons.wifi_rounded, color: (isUsb ? Colors.blue : Colors.green)[300], size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(widget.device.displayName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
                if (widget.device.isWifi) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('Wi-Fi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[300])))],
              ]),
              Text(isUsb ? 'USB Device — tap to connect' : 'Wi-Fi ADB — tap to connect', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ])),
            AnimatedOpacity(opacity: _hover ? 1.0 : 0.0, duration: const Duration(milliseconds: 150),
              child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.5), size: 24)),
          ]),
        ),
      ),
    );
  }
}