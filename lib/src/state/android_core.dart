import 'dart:async';
import 'package:flutter/foundation.dart';

/// Centralized state store for all Android device telemetry
class AndroidCore {
  AndroidCore._internal();
  static final AndroidCore _instance = AndroidCore._internal();
  factory AndroidCore() => _instance;

  // Connection state (reactive)
  final ValueNotifier<bool> jarConnected = ValueNotifier(false);
  final ValueNotifier<bool> apkConnected = ValueNotifier(false);
  final ValueNotifier<bool> allConnected = ValueNotifier(false);
  final ValueNotifier<bool> isReconnecting = ValueNotifier(false);
  final ValueNotifier<String> reconnectionMessage = ValueNotifier('');

  // Battery state
  int batteryPercentage = 0;
  bool batteryCharging = false;
  int batteryPlugged = 0;
  bool batterySaver = false;
  double batteryTemperature = 0.0;
  double batteryVoltage = 0.0;
  int batteryCurrentMa = 0;
  String batteryHealth = 'Unknown';
  String batteryTechnology = 'Unknown';
  String batteryPlugType = 'None';

  // Volume state
  int volumeMusic = 0;
  int volumeMusicMax = 15;
  int volumeRing = 0;
  int volumeRingMax = 7;
  int volumeNotification = 0;
  int volumeNotificationMax = 7;
  int volumeAlarm = 0;
  int volumeAlarmMax = 7;
  bool volumeMusicAvailable = true;
  bool volumeRingAvailable = true;
  bool volumeNotificationAvailable = true;
  bool volumeAlarmAvailable = true;

  // Device states
  bool wifi = false;
  String wifiName = '';
  bool bluetooth = false;
  String bluetoothName = '';
  bool mobileData = false;
  bool airplane = false;
  bool mute = false;
  bool rotationLock = false;
  bool location = false;
  bool torch = false;

  // Permissions
  String permissionLevel = 'unknown';
  String permissionMessage = '';
  Map<String, bool> permissionsData = {};
  int permissionTimestamp = 0;

  // Media session
  Map<String, dynamic> mediaSession = {};
  bool mediaSessionActive = false;

  // Notifications
  List<Map<String, dynamic>> notifications = [];

  // Apps list
  List<Map<String, dynamic>> installedApps = [];

  // Device info
  String deviceModel = '';
  String deviceManufacturer = '';
  String androidVersion = '';
  String apiLevel = '';

  // Update connection state
  void setJarConnected(bool connected) {
    jarConnected.value = connected;
    _updateAllConnected();
  }

  void setApkConnected(bool connected) {
    apkConnected.value = connected;
    _updateAllConnected();
  }

  void _updateAllConnected() {
    allConnected.value = jarConnected.value && apkConnected.value;
  }

  void setReconnecting(bool reconnecting, [String message = '']) {
    isReconnecting.value = reconnecting;
    reconnectionMessage.value = message;
  }

  // Update from JAR/APK messages
  void updateFromMessage(Map<String, dynamic> data) {
    // Always update device states if present
    if (data['states'] != null) {
      updateDeviceStates(data['states'] as Map<String, dynamic>);
    }

    final type = data['type'] as String?;
    switch (type) {
      case 'battery_small':
        _updateBatterySmall(data);
        break;
      case 'battery_update':
        _updateBatteryFull(data);
        break;
      case 'volume_update':
        _updateVolume(data);
        break;
      case 'apk.permissions':
        _updatePermissions(data);
        break;
      case 'device_state':
        updateDeviceStates(data['states'] as Map<String, dynamic>);
        break;
      case 'media_session':
        updateMediaSession(data);
        break;
      case 'notification':
        updateNotification(data);
        break;
      case 'apps_list':
        updateAppsList(data);
        break;
      case 'device_info':
        updateDeviceInfo(data);
        break;
    }
  }

  void _updateBatterySmall(Map<String, dynamic> data) {
    batteryPercentage = (data['percentage'] as num?)?.toInt() ?? batteryPercentage;
    batteryCharging = (data['charging'] as bool?) ?? batteryCharging;
    batteryPlugged = (data['plugged'] as num?)?.toInt() ?? batteryPlugged;
    batterySaver = (data['battery_saver'] as bool?) ?? batterySaver;
  }

  void _updateBatteryFull(Map<String, dynamic> data) {
    final battery = data['battery'] as Map<String, dynamic>?;
    if (battery != null) {
      batteryPercentage = (battery['percentage'] as num?)?.toInt() ?? batteryPercentage;
      batteryCharging = (battery['charging'] as bool?) ?? batteryCharging;
      batteryPlugged = (battery['plugged'] as num?)?.toInt() ?? batteryPlugged;
      batteryVoltage = (battery['voltage'] as num?)?.toDouble() ?? batteryVoltage;
      batteryTemperature = (battery['temperature'] as num?)?.toDouble() ?? batteryTemperature;
      batteryCurrentMa = (battery['current_ma'] as num?)?.toInt() ?? batteryCurrentMa;
      batteryHealth = battery['health'] as String? ?? batteryHealth;
      batteryTechnology = battery['technology'] as String? ?? batteryTechnology;
      batteryPlugType = battery['plug_type'] as String? ?? batteryPlugType;
      batterySaver = (battery['battery_saver'] as bool?) ?? batterySaver;
    }
  }

  void _updateVolume(Map<String, dynamic> data) {
    final streams = data['streams'] as List<dynamic>?;
    if (streams != null) {
      for (final stream in streams) {
        final name = stream['stream_name'] as String?;
        final current = (stream['current'] as num?)?.toInt() ?? 0;
        final max = (stream['max'] as num?)?.toInt() ?? 1;
        final available = (stream['available'] as bool?) ?? true;

        switch (name) {
          case 'music':
            volumeMusic = current;
            volumeMusicMax = max;
            volumeMusicAvailable = available;
            break;
          case 'ring':
            volumeRing = current;
            volumeRingMax = max;
            volumeRingAvailable = available;
            break;
          case 'notification':
            volumeNotification = current;
            volumeNotificationMax = max;
            volumeNotificationAvailable = available;
            break;
          case 'alarm':
            volumeAlarm = current;
            volumeAlarmMax = max;
            volumeAlarmAvailable = available;
            break;
        }
      }
    }
  }

  void _updatePermissions(Map<String, dynamic> data) {
    permissionLevel = data['level'] as String? ?? permissionLevel;
    permissionMessage = data['message'] as String? ?? permissionMessage;
    permissionTimestamp = (data['timestamp'] as num?)?.toInt() ?? permissionTimestamp;
    
    final permData = data['data'] as Map<String, dynamic>?;
    if (permData != null) {
      permissionsData = permData.map((k, v) => MapEntry(k, v as bool));
    }
  }

  void updateDeviceStates(Map<String, dynamic> states) {
    wifi = states['wifi'] as bool? ?? wifi;
    wifiName = states['wifi_name'] as String? ?? wifiName;
    bluetooth = states['bluetooth'] as bool? ?? bluetooth;
    bluetoothName = states['bluetooth_name'] as String? ?? bluetoothName;
    mobileData = states['mobile_data'] as bool? ?? mobileData;
    airplane = states['airplane_mode'] as bool? ?? airplane;
    mute = states['mute'] as bool? ?? mute;
    rotationLock = states['rotation_lock'] as bool? ?? rotationLock;
    location = states['location'] as bool? ?? location;
    torch = states['torch'] as bool? ?? torch;
  }

  void updateMediaSession(Map<String, dynamic> data) {
    mediaSession = data;
    mediaSessionActive = data['active'] as bool? ?? false;
  }

  void updateNotification(Map<String, dynamic> data) {
    final notif = data['notification'] as Map<String, dynamic>?;
    if (notif != null) {
      // Remove existing with same key
      notifications.removeWhere((n) => n['key'] == notif['key']);
      notifications.insert(0, notif);
      if (notifications.length > 50) {
        notifications = notifications.take(50).toList();
      }
    }
  }

  void updateAppsList(Map<String, dynamic> data) {
    final apps = data['apps'] as List<dynamic>?;
    if (apps != null) {
      installedApps = apps.cast<Map<String, dynamic>>().toList();
    }
  }

  void updateDeviceInfo(Map<String, dynamic> data) {
    deviceModel = data['model'] as String? ?? deviceModel;
    deviceManufacturer = data['manufacturer'] as String? ?? deviceManufacturer;
    androidVersion = data['android_version'] as String? ?? androidVersion;
    apiLevel = data['api_level'] as String? ?? apiLevel;
  }

  // Computed getters
  double get batteryPercentageNormalized => batteryPercentage / 100.0;
  double get volumeMusicNormalized => volumeMusicMax > 0 ? volumeMusic / volumeMusicMax : 0.0;
  double get volumeRingNormalized => volumeRingMax > 0 ? volumeRing / volumeRingMax : 0.0;
  double get volumeNotificationNormalized => volumeNotificationMax > 0 ? volumeNotification / volumeNotificationMax : 0.0;
  double get volumeAlarmNormalized => volumeAlarmMax > 0 ? volumeAlarm / volumeAlarmMax : 0.0;

  bool get hasCriticalPermissions => permissionLevel == 'success';
  bool get hasWarnings => permissionLevel == 'warning';
  bool get hasErrors => permissionLevel == 'error';

  void clearNotifications() {
    notifications.clear();
  }

  void removeNotification(String key) {
    notifications.removeWhere((n) => n['key'] == key);
  }

  void dispose() {
    jarConnected.dispose();
    apkConnected.dispose();
    allConnected.dispose();
    isReconnecting.dispose();
    reconnectionMessage.dispose();
  }
}