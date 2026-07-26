import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Connection target for ADB operations
sealed class ConnectionTarget {
  const ConnectionTarget();
  
  const factory ConnectionTarget.usb() = UsbTarget;
  const factory ConnectionTarget.wifi(String ip, [int? port]) = WifiTarget;
  const factory ConnectionTarget.auto() = AutoTarget;

  static ConnectionTarget parseCliArgs(List<String> args) {
    if (args.isEmpty) return const AutoTarget();
    if (args.first == '--usb') return const UsbTarget();
    final arg = args.first;
    if (arg.contains(':')) {
      final parts = arg.split(':');
      return WifiTarget(parts[0], int.tryParse(parts[1]));
    }
    return WifiTarget(arg);
  }

  T when<T>({
    required T Function() usb,
    required T Function(String ip, int? port) wifi,
    required T Function() auto,
  }) {
    return switch (this) {
      UsbTarget() => usb(),
      WifiTarget(:final ip, :final port) => wifi(ip, port),
      AutoTarget() => auto(),
    };
  }
}

class UsbTarget extends ConnectionTarget {
  const UsbTarget();
  @override bool operator ==(Object other) => other is UsbTarget;
  @override int get hashCode => 0;
  @override String toString() => 'UsbTarget()';
}

class WifiTarget extends ConnectionTarget {
  final String ip;
  final int? port;
  const WifiTarget(this.ip, [this.port]);
  int get effectivePort => port ?? 5555;
  String get address => '$ip:$effectivePort';
  @override bool operator ==(Object other) =>
      identical(this, other) || other is WifiTarget && ip == other.ip && port == other.port;
  @override int get hashCode => Object.hash(ip, port);
  @override String toString() => 'WifiTarget($ip:${port ?? 5555})';
}

class AutoTarget extends ConnectionTarget {
  const AutoTarget();
  @override bool operator ==(Object other) => other is AutoTarget;
  @override int get hashCode => 1;
  @override String toString() => 'AutoTarget()';
}

/// Device information from ADB
class DeviceInfo {
  final String id;
  final DeviceType type;
  final String? model;
  final String? transportId;

  const DeviceInfo({
    required this.id,
    required this.type,
    this.model,
    this.transportId,
  });

  String get displayName => model ?? id;
  bool get isUsb => type == DeviceType.usb;
  bool get isWifi => type == DeviceType.wifi;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeviceInfo && id == other.id;
  @override int get hashCode => id.hashCode;
  @override String toString() => 'DeviceInfo($id, $type, $model)';
}

enum DeviceType { usb, wifi }

/// ADB command result
class AdbResult {
  final bool success;
  final String output;
  final int exitCode;
  const AdbResult({required this.success, required this.output, required this.exitCode});

  factory AdbResult.fromProcess(ProcessResult r) => AdbResult(
    success: r.exitCode == 0,
    output: '${r.stdout}${r.stderr}'.trim(),
    exitCode: r.exitCode,
  );

  @override String toString() => 'AdbResult(success=$success, exitCode=$exitCode)';
}

/// Exception for ADB operations
class AdbException implements Exception {
  final String message;
  final String? userMessage;
  final AdbResult? result;
  const AdbException(this.message, {this.userMessage, this.result});
  @override String toString() => 'AdbException: $message';
}