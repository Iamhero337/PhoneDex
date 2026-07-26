import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adb/adb_provider.dart';
import '../core/device.dart';
import '../utils/logger.dart';

/// Dialog for selecting ADB device
class DevicePickerDialog extends ConsumerStatefulWidget {
  final Function(ConnectionTarget) onDeviceSelected;
  final VoidCallback onCancel;

  const DevicePickerDialog({
    super.key,
    required this.onDeviceSelected,
    required this.onCancel,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(ConnectionTarget) onDeviceSelected,
    required VoidCallback onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DevicePickerDialog(
        onDeviceSelected: onDeviceSelected,
        onCancel: onCancel,
      ),
    );
  }

  @override
  ConsumerState<DevicePickerDialog> createState() => _DevicePickerDialogState();
}

class _DevicePickerDialogState extends ConsumerState<DevicePickerDialog> {
  final _log = AppLogger('DevicePickerDialog');
  final _ipController = TextEditingController();
  final _adb = AdbProvider();

  List<DeviceInfo> _devices = [];
  bool _isScanning = false;
  String? _ipError;
  bool _isConnectingIp = false;

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      final devices = await _adb.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      _log.error('Failed to scan devices: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectIp() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() => _ipError = 'Enter a valid IP address');
      return;
    }

    setState(() {
      _isConnectingIp = true;
      _ipError = null;
    });

    try {
      final result = await _adb.connectWifi(ip);
      if (result.success || result.output.contains('already connected')) {
        if (mounted) {
          Navigator.pop(context);
          widget.onDeviceSelected(ConnectionTarget.wifi(ip));
        }
      } else {
        setState(() => _ipError = 'Unable to connect to $ip — verify the IP and try again.');
      }
    } catch (e) {
      setState(() => _ipError = 'Connection failed — ensure ADB over Wi-Fi is enabled on the device.');
    } finally {
      if (mounted) {
        setState(() => _isConnectingIp = false);
      }
    }
  }

  void _selectDevice(DeviceInfo device) {
    Navigator.pop(context);
    if (device.isUsb) {
      widget.onDeviceSelected(const UsbTarget());
    } else {
      widget.onDeviceSelected(WifiTarget(device.id.split(':').first, 
          device.id.split(':').length > 1 ? int.tryParse(device.id.split(':').last) : 5555));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3E),
          borderRadius: BorderRadius.circular(20),
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
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006EFF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phone_android_rounded,
                          color: Color(0xFF006EFF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PhoneDex — ADB Manager',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Tap a device to connect instantly',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Device list
            Flexible(
              child: _isScanning
                  ? _buildScanningState()
                  : _devices.isEmpty
                      ? _buildEmptyState()
                      : _buildDeviceList(),
            ),

            // IP Connection
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect via IP Address',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: '192.168.1.100',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                            errorText: _ipError,
                            errorStyle: TextStyle(color: Colors.red[300]),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF006EFF), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) => _connectIp(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _isConnectingIp
                          ? const SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _connectIp,
                              icon: const Icon(Icons.wifi_rounded, size: 18),
                              label: const Text('Connect'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006EFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _scanDevices,
                    child: const Text('Refresh Devices'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCancel();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 16),
            Text('Scanning for ADB devices…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.usb_off_rounded, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No ADB devices found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable USB Debugging or Wireless Debugging\non your Android device',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      itemCount: _devices.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.white.withOpacity(0.05),
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _DeviceRow(
          device: device,
          onTap: () => _selectDevice(device),
        );
      },
    );
  }
}

class _DeviceRow extends StatefulWidget {
  final DeviceInfo device;
  final VoidCallback onTap;

  const _DeviceRow({
    required this.device,
    required this.onTap,
  });

  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? Colors.white.withOpacity(0.05) : Colors.transparent,
            border: Border.all(
              color: _hovered ? Colors.blue.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.device.isUsb 
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.device.isUsb ? Icons.usb_rounded : Icons.wifi_rounded,
                  color: widget.device.isUsb ? Colors.blue[300] : Colors.green[300],
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.device.displayName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.device.isWifi) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Wi-Fi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[300],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.device.isUsb 
                          ? 'USB Device — tap to connect'
                          : 'Wi-Fi ADB — tap to connect',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}