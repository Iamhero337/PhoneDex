import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:phonedex/src/core/device.dart';
import 'package:phonedex/src/adb/adb_provider.dart';

/// Centralized reactive state store for all Android device telemetry & actions
class AndroidCore {
  AndroidCore._();
  static final AndroidCore _instance = AndroidCore._();
  static AndroidCore get instance => _instance;

  final jarConnected = ValueNotifier<bool>(false);
  final apkConnected = ValueNotifier<bool>(false);
  final allConnected = ValueNotifier<bool>(false);
  final isReconnecting = ValueNotifier<bool>(false);
  final reconnectionMessage = ValueNotifier<String>('');

  ConnectionTarget? activeTarget;

  int batteryPercentage = 85;
  bool batteryCharging = false;
  bool batterySaver = false;
  double batteryTemperature = 32.5;
  double batteryVoltage = 4.1;
  String batteryHealth = 'Good';

  int volumeMusic = 10, volumeMusicMax = 15;
  int volumeRing = 5, volumeRingMax = 7;

  bool wifi = true, bluetooth = true, mobileData = false;
  bool airplane = false, mute = false, rotationLock = false;
  bool location = true, torch = false;
  String wifiName = 'Wi-Fi Network', bluetoothName = 'Bluetooth Active';

  String permissionLevel = 'normal';
  String permissionMessage = 'All core features available';

  Map<String, dynamic> mediaSession = {
    'title': 'No media playing',
    'artist': 'PhoneDex Media Hub',
    'album': 'Android Audio',
    'is_playing': false,
  };

  List<Map<String, dynamic>> notifications = [
    {
      'key': 'demo_1',
      'package': 'com.android.vending',
      'title': 'Google Play Store',
      'text': 'Apps updated successfully',
      'time': 'Just now',
    },
    {
      'key': 'demo_2',
      'package': 'com.google.android.gm',
      'title': 'Gmail',
      'text': 'Welcome to PhoneDex Desktop Edition',
      'time': '5m ago',
    },
  ];

  List<Map<String, dynamic>> installedApps = [
    {'name': 'Settings', 'package': 'com.android.settings', 'icon': 'settings'},
    {'name': 'Chrome', 'package': 'com.android.chrome', 'icon': 'web'},
    {'name': 'YouTube', 'package': 'com.google.android.youtube', 'icon': 'play'},
    {'name': 'Play Store', 'package': 'com.android.vending', 'icon': 'shop'},
    {'name': 'Camera', 'package': 'com.android.camera', 'icon': 'camera'},
    {'name': 'Files', 'package': 'com.android.documentsui', 'icon': 'folder'},
    {'name': 'Gallery / Photos', 'package': 'com.google.android.apps.photos', 'icon': 'image'},
    {'name': 'Clock', 'package': 'com.android.deskclock', 'icon': 'alarm'},
    {'name': 'Calculator', 'package': 'com.android.calculator2', 'icon': 'calculate'},
    {'name': 'Music', 'package': 'com.google.android.music', 'icon': 'music'},
  ];

  void setJarConnected(bool v) { jarConnected.value = v; _updateAll(); }
  void setApkConnected(bool v) { apkConnected.value = v; _updateAll(); }
  void _updateAll() => allConnected.value = jarConnected.value || apkConnected.value;

  void setReconnecting(bool v, [String msg = '']) {
    isReconnecting.value = v;
    if (msg.isNotEmpty) reconnectionMessage.value = msg;
  }

  void updateFromMessage(Map<String, dynamic> data) {
    if (data['states'] is Map) updateDeviceStates(data['states'] as Map<String, dynamic>);
    switch (data['type'] as String?) {
      case 'battery_small':
        batteryPercentage = (data['percentage'] as num?)?.toInt() ?? batteryPercentage;
        batteryCharging = (data['charging'] as bool?) ?? batteryCharging;
        batterySaver = (data['battery_saver'] as bool?) ?? batterySaver;
      case 'battery_update':
        final b = data['battery'] as Map<String, dynamic>?;
        if (b != null) {
          batteryPercentage = (b['percentage'] as num?)?.toInt() ?? batteryPercentage;
          batteryCharging = (b['charging'] as bool?) ?? batteryCharging;
          batteryVoltage = (b['voltage'] as num?)?.toDouble() ?? batteryVoltage;
          batteryTemperature = (b['temperature'] as num?)?.toDouble() ?? batteryTemperature;
          batteryHealth = b['health'] as String? ?? batteryHealth;
          batterySaver = (b['battery_saver'] as bool?) ?? batterySaver;
        }
      case 'volume_update':
        final streams = data['streams'] as List?;
        if (streams != null) {
          for (final s in streams) {
            final name = s['stream_name'] as String?, cur = (s['current'] as num?)?.toInt() ?? 0, mx = (s['max'] as num?)?.toInt() ?? 1;
            if (name == 'music') { volumeMusic = cur; volumeMusicMax = mx; }
            if (name == 'ring') { volumeRing = cur; volumeRingMax = mx; }
          }
        }
      case 'apk.permissions':
        permissionLevel = data['level'] as String? ?? permissionLevel;
        permissionMessage = data['message'] as String? ?? permissionMessage;
      case 'media_session':
        mediaSession = data;
      case 'notification':
        updateNotification(data);
    }
  }

  void updateDeviceStates(Map<String, dynamic> s) {
    wifi = s['wifi'] as bool? ?? wifi;
    wifiName = s['wifi_name'] as String? ?? wifiName;
    bluetooth = s['bluetooth'] as bool? ?? bluetooth;
    bluetoothName = s['bluetooth_name'] as String? ?? bluetoothName;
    mobileData = s['mobile_data'] as bool? ?? mobileData;
    airplane = s['airplane_mode'] as bool? ?? airplane;
    mute = s['mute'] as bool? ?? mute;
    rotationLock = s['rotation_lock'] as bool? ?? rotationLock;
    location = s['location'] as bool? ?? location;
    torch = s['torch'] as bool? ?? torch;
  }

  void updateNotification(Map<String, dynamic> data) {
    final n = data['notification'] as Map<String, dynamic>?;
    if (n != null) {
      notifications.removeWhere((x) => x['key'] == n['key']);
      notifications.insert(0, n);
      if (notifications.length > 50) notifications = notifications.take(50).toList();
    }
  }

  void dismissNotification(String key) {
    notifications.removeWhere((x) => x['key'] == key);
  }

  void clearAllNotifications() {
    notifications.clear();
  }

  Future<void> launchApp(String packageName) async {
    if (activeTarget != null) {
      await AdbProvider().launchApp(activeTarget!, packageName);
    }
  }

  Future<void> sendHomeKey() async {
    if (activeTarget != null) {
      await AdbProvider().sendKeyEvent(activeTarget!, 3); // KEYCODE_HOME
    }
  }

  Future<void> sendBackKey() async {
    if (activeTarget != null) {
      await AdbProvider().sendKeyEvent(activeTarget!, 4); // KEYCODE_BACK
    }
  }

  Future<void> sendPowerKey() async {
    if (activeTarget != null) {
      await AdbProvider().sendKeyEvent(activeTarget!, 26); // KEYCODE_POWER
    }
  }

  void dispose() {
    jarConnected.dispose();
    apkConnected.dispose();
    allConnected.dispose();
    isReconnecting.dispose();
    reconnectionMessage.dispose();
  }
}