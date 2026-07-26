# PhoneDex Architecture

Deep-dive into the three-layer system design, communication protocols, data flow, and failure handling.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            WINDOWS HOST (Flutter Desktop)                     │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  ┌───────────────────┐  │
│  │  AppManager │  │  AdbProvider │  │  JarServer  │  │    ApkServer      │  │
│  │  (Orchestrator)│ │ (ADB Bridge) │  │  (TCP:8080) │  │  (WebSocket:8081) │  │
│  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘  └────────┬──────────┘  │
│         │                │                 │                    │            │
│         │                │                 │                    │            │
│         ▼                ▼                 ▼                    ▼            │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    AndroidCore (Reactive State Store)                │   │
│  │  ValueNotifiers: jarConnected, apkConnected, allConnected,          │   │
│  │  batteryPercentage, volumeMusic, wifi, bluetooth, notifications...  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │ TCP:8080                 │ WebSocket:8081           │
          ▼                          ▼                          ▼
┌─────────────────────────┐  ┌─────────────────────────────────────────┐
│    LOGIC ENGINE         │  │          FEATURE HUB                    │
│    (Java JAR)           │  │          (Kotlin APK)                   │
│    ADB Shell Context    │  │          Android App Context            │
│    • AudioManager       │  │          • NotificationListenerService  │
│    • ActivityManager    │  │          • MediaSessionManager          │
│    • PowerManager       │  │          • BatteryManager               │
│    • DisplayManager     │  │          • Bluetooth/WiFi callbacks     │
└─────────────────────────┘  └─────────────────────────────────────────┘
```

**Key Principle**: Both Android components **connect back to Windows** — Windows runs the servers; Android clients dial in. This works over USB (`adb reverse`) or Wi-Fi (direct TCP).

---

## Layer 1 — Windows Host (Flutter)

### Responsibilities
| Domain | Implementation |
|--------|----------------|
| **ADB Lifecycle** | `AdbProvider.startServer()`, `connect()`, `reverse()` |
| **Server Infrastructure** | `JarServer` (TCP), `ApkServer` (WebSocket), `MediaServer` (WS:8082), `NotifyServer` (WS:8083) |
| **JAR Deployment** | `JarManager.deployAndStart()` — push, launch, monitor |
| **APK Management** | `ApkManager.ensureInstalledAndStart()` — install, launch service |
| **Rendering** | `scrcpy` embedded via Win32 `SetParent()` into Flutter windows |
| **UI** | Boot screen, Home screen, Taskbar, Reconnection overlay, Device picker |
| **Reconnection** | `ReconnectionManager` — monitors `ValueNotifier`s, executes recovery |
| **Device Selection** | `DevicePickerDialog` — auto-detect + manual IP connect |

### Server Ports
| Port | Protocol | Client | Purpose |
|------|----------|--------|---------|
| 8080 | TCP (raw) | Logic Engine (JAR) | Commands, status, `jar.hello` handshake |
| 8081 | WebSocket | Feature Hub (APK) | Telemetry, notifications, `apk.hello` handshake |
| 8082 | WebSocket | Feature Hub | Media session metadata + artwork |
| 8083 | WebSocket | Feature Hub | Notification stream |

All ports forwarded via `adb reverse tcp:PORT tcp:PORT` on connect.

---

## Layer 2 — Logic Engine (Java JAR)

### Why a JAR?
Android's permission model blocks shell processes from:
- Direct `AudioManager` stream access (volume control)
- `ActivityManager.startActivity()` with foreground flags
- `ActivityManager.forceStopPackage()`
- `PowerManager` wake/sleep without `WAKE_LOCK` permission
- Display state manipulation

The JAR runs via `adb shell app_process /data/local/tmp com.phonedex.engine.JarMain` — executing at **ADB shell user level** (shell UID), which has these privileges.

### Capabilities
| Feature | Android API |
|---------|-------------|
| Volume control (all streams) | `AudioManager.setStreamVolume()` |
| App launch | `ActivityManager.startActivity()` with `FLAG_ACTIVITY_NEW_TASK` |
| App kill | `ActivityManager.forceStopPackage()` |
| Screen wake/sleep | `PowerManager.wakeUp()` / `goToSleep()` |
| Display on/off | `DisplayManager` + reflection |
| Shell command execution | `Runtime.getRuntime().exec()` |

### Lifecycle
```
Windows locates phonedex.jar
        │
        ▼
adb push → /data/local/tmp/phonedex.jar
        │
        ▼
adb shell app_process /data/local/tmp com.phonedex.engine.JarMain
        │
        ▼
JAR opens TCP to Windows:8080
        │
        ▼
Sends: {"type":"jar.hello"}  ← handshake
        │
        ▼
Windows: JarManager.jarReady.complete() → jarConnected=true
```

### Message Protocol (TCP → Windows)
```json
// Handshake
{"type": "jar.hello"}

// Battery quick tick (~1s)
{"type": "battery_small", "percentage": 87, "charging": true, "plugged": 2, "battery_saver": false, "states": {...}}

// Full battery snapshot
{"type": "battery_update", "battery": {"percentage": 87, "voltage": 4.2, "temperature": 29.5, "current_ma": -1200, "health": "Good", "technology": "Li-ion", "plug_type": "USB", "battery_saver": false}}

// Volume streams
{"type": "volume_update", "streams": [{"stream_name":"music","current":8,"max":15,"available":true}, ...]}

// Permission status
{"type": "apk.permissions", "level": "warning", "message": "Notification access not granted", "timestamp": 1711700000000, "data": {"READ_CONTACTS": true, "POST_NOTIFICATIONS": false, ...}}

// Device states (always included in "states" block)
"states": {
  "wifi": true, "wifi_name": "HomeNetwork",
  "bluetooth": false, "bluetooth_name": "",
  "mobile_data": true, "airplane_mode": false,
  "mute": false, "rotation_lock": false,
  "location": true, "torch": false
}
```

---

## Layer 3 — Feature Hub (Kotlin APK)

### Why Separate APK?
The APK runs in **Android application context** — required for listener APIs that need app registration:
- `NotificationListenerService` — cannot be registered from shell
- `MediaSessionManager` — requires `MediaController` callbacks
- `BatteryManager` broadcasts — need `BroadcastReceiver` in manifest
- `BIND_ACCESSIBILITY_SERVICE` — system-level permission

### Components
| Component | Purpose |
|-----------|---------|
| `ServerStartService` (Foreground Service) | Entry point; starts WebSocket client, holds wake lock |
| `NotificationListener` | Streams notifications to Windows via WS:8081 |
| `MediaSessionController` | Pushes media metadata/artwork to WS:8082 |
| `TelemetryService` | Battery, volume, device states → WS:8081 (1s tick) |
| `PermissionMonitor` | Reports runtime permission grants/denials |

### Lifecycle
```
Windows checks: adb shell pm list packages com.phonedex.hub
        │
        ├─ Not installed → adb install -r PhoneDex.apk
        │
        ▼
adb shell am start-foreground-service -n com.phonedex.hub/.ServerStartService
        │
        ▼
APK opens WebSocket to Windows:8081
        │
        ▼
Sends: {"type":"apk.hello"}  ← handshake
        │
        ▼
Windows: ApkManager.apkReady.complete() → apkConnected=true
        │
        ▼
Windows sends: {"type":"start_services"} → starts NotificationListener + MediaSession
```

### Message Protocol (WebSocket → Windows)
```json
// Handshake
{"type": "apk.hello"}

// Battery tick (includes states block)
{"type": "battery_small", "percentage": 87, "charging": true, "plugged": 2, "battery_saver": false, "states": {...}}

// Full battery
{"type": "battery_update", "battery": {...}}

// Volume
{"type": "volume_update", "streams": [...]}

// Permissions
{"type": "apk.permissions", "level": "success", "message": "All permissions granted", "timestamp": 1711700000000, "data": {...}}

// Media session
{"type": "media_session", "active": true, "title": "Song", "artist": "Artist", "artwork": "base64...", "state": "playing", "position": 45000, "duration": 210000, "actions": ["play","pause","next","prev"]}

// Notification
{"type": "notification", "notification": {"key": "pkg|id|tag", "package": "com.app", "title": "Title", "text": "Body", "icon": "base64...", "timestamp": 1711700000000, "actions": [{"title":"Reply","actionIntent":...}]}}

// Ping/pong (10s interval)
{"type": "ping"}  →  {"type": "pong"}
```

---

## Handshake Protocol (Boot Sequence)

```
Windows App Launch
       │
       ▼
┌──────────────────────────────────────────┐
│  AppManager.initializeSystem()           │
│  (11 steps, emits AppEvent stream)       │
└──────────────────┬───────────────────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
  JAR Bar                    APP Bar
  (JarManager)               (AppManager)
       │                       │
       ▼                       ▼
 1. stopJar()            1. startAdbBlocking()
 2. killJar()            2. connectBlocking()
 3. locate JAR           3. reverse ports (8080-8083)
 4. push JAR             4. start servers
 5. launch JAR           5. deploy JAR (triggers JAR bar)
 6. monitor stdout       6. verify/install APK
 7. wait jar.hello       7. start APK service
                         8. wait jar.hello (15s timeout)
                         9. wait apk.hello (15s timeout)
                        10. start extended services
                        11. ALL_CONNECTED → UI unlock
```

**Progress Mapping:**

| APP Bar | Message |
|---------|---------|
| 0.02 | Starting ADB server… |
| 0.10 | Connecting to Android device… |
| 0.20 | Device connected — network bridge configured |
| 0.28 | Starting local communication servers… |
| 0.38 | Deploying service module to Android device… |
| 0.55 | Verifying companion app on device… |
| 0.65 | Companion app not found — installing now… |
| 0.72 | Launching Android companion services… |
| 0.84 | Waiting for background service to connect… |
| 0.93 | Waiting for companion app to connect… |
| 0.97 | Activating media and notification services… |
| 1.00 | **System ready** ✓ |

| JAR Bar | Message |
|---------|---------|
| 0.00 | Preparing service deployment… |
| 0.15 | Stopping previous service on device… |
| 0.30 | Locating service module… |
| 0.50 | Uploading service module to device… |
| 0.70 | Service module uploaded successfully |
| 0.82 | Launching service runtime on device… |
| 0.92 | Service is running — awaiting connection… |
| 1.00 | **Service connected — handshake confirmed** ✓ |

---

## Data Flow

```
┌──────────────┐     TCP:8080      ┌──────────────┐     ValueNotifier     ┌──────────────┐
│  Logic Engine │ ───────────────► │   JarServer  │ ────────────────────► │ AndroidCore  │
│   (Java JAR)  │  JSON messages  │  (TCP recv)  │  updateFromMessage()  │  (State)     │
└──────────────┘                   └──────────────┘                       └──────┬───────┘
                                                                                 │
┌──────────────┐     WS:8081       ┌──────────────┐                            │
│ Feature Hub  │ ───────────────► │  ApkServer   │ ────────────────────────────┘
│  (Kotlin APK)│  JSON messages  │  (WS recv)   │
└──────────────┘                   └──────────────┘
        │                                 │
        │ WS:8082                         │ WS:8083
        ▼                                 ▼
┌──────────────┐                   ┌──────────────┐
│ MediaServer  │                   │ NotifyServer │
│ (artwork,    │                   │ (notification│
│  metadata)   │                   │  stream)     │
└──────────────┘                   └──────────────┘
        │                                 │
        └─────────────────┬───────────────┘
                          ▼
                 ┌──────────────────┐
                 │   Flutter UI     │
                 │ (ValueListenable │
                 │  Builder widgets)│
                 └──────────────────┘
```

**scrcpy Path (separate):**
```
scrcpy process → Win32 SetParent(hwnd, flutterWindow) → H.264 video → Flutter texture
```

---

## Reconnection System

### State Machine
```
IDLE
  │ (jarConnected=false OR apkConnected=false)
  ▼
QUICK_RECONNECT
  │ adb connect + adb reverse
  │ wait 15s for handshakes
  │
  ├─ Both reconnected → IDLE
  └─ Failed → FULL_RESTART (attempt 1)
               │
               ├─ stopJar() + killJar()
               ├─ push JAR + launch
               ├─ start APK service
               ├─ wait handshakes (30s)
               │
               ├─ Success → IDLE
               └─ Failed → FULL_RESTART (attempt 2)
                          │
                          ├─ Success → IDLE
                          └─ Failed → FAILED
```

### Partial Disconnection Handling
| Scenario | jarReconnecting | apkReconnecting | Action |
|----------|-----------------|-----------------|--------|
| JAR drops only | true | false | Quick reconnect JAR only |
| APK drops only | false | true | Quick reconnect APK only |
| Both drop | true | true | Full recovery for both |

### Overlay UI
- **Phase indicator**: "QUICK RECONNECT" / "FULL RESTART" / "CONNECTION LOST"
- **Component pills**: 🟡 Reconnecting / 🟢 Connected / 🔴 Failed
- **Attempt counter**: "Attempt 1 of 2"
- **Blocks all desktop interaction** until recovery or failure

---

## Error Handling Philosophy

**Two-Tier Messaging:**
| Tier | Audience | Content |
|------|----------|---------|
| **Dev Log** | Developer (console/logcat) | Raw output, stack traces, exit codes, file paths |
| **User Message** | End-user (boot screen) | Plain English, actionable, no jargon |

**Mapping Examples:**
| Internal Error | User Message |
|----------------|--------------|
| `FileNotFoundException: phonedex.jar` | "Service module not found. Please reinstall the application." |
| `adb connect` fails | "Unable to connect to the device. Verify the IP address or check the USB cable." |
| `adb reverse` fails port 8080 | "Network bridge setup failed on port 8080. The device may have revoked ADB permissions." |
| JAR handshake timeout (15s) | "Background service timed out. The device may be busy or unreachable." |
| APK handshake timeout (15s) | "Companion app timed out. Ensure it is installed and running on the device." |

**Connection Error Detection** (shows "Open ADB Manager" button):
```dart
l.contains('connect') || l.contains('device') || l.contains('adb') ||
l.contains('network') || l.contains('refused') || l.contains('timeout') ||
l.contains('unreachable') || l.contains('bridge') || l.contains('handshake')
```

---

## Build & Deployment

### Windows Bundle Structure
```
PhoneDex-Windows/
├── PhoneDex.exe
├── assets/
│   ├── adb/adb.exe
│   ├── scrcpy/scrcpy.exe
│   ├── phonedex.jar
│   └── PhoneDex.apk
├── flutter_assets/
├── data/
└── icudtl.dat
```

### Linux Bundle Structure
```
PhoneDex-Linux/
├── PhoneDex
├── run_PhoneDex.sh          # Checks deps, sets LD_LIBRARY_PATH
├── assets/
│   ├── adb/adb
│   ├── scrcpy/scrcpy
│   ├── phonedex.jar
│   └── PhoneDex.apk
├── lib/                     # Flutter engine .so files
└── flutter_assets/
```

### Asset Resolution (AdbProvider)
```dart
// Search order for each asset:
1. <exe_dir>/../assets/<asset>        // Installed bundle
2. <exe_dir>/../../assets/<asset>     // Development (build/<platform>/)
3. <cwd>/assets/<asset>               // Manual testing
```

---

## Security Model

- **No root required** — uses standard ADB + Android APIs
- **Local-only servers** — bind to `127.0.0.1` (Windows) + `adb reverse` (device→host)
- **No cloud** — all communication stays on local network/USB
- **Companion APK permissions** — requested at runtime:
  - `BIND_NOTIFICATION_LISTENER_SERVICE`
  - `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC`
  - `POST_NOTIFICATIONS` (Android 13+)
  - `BLUETOOTH_CONNECT` (Android 12+)
  - `MEDIA_CONTENT_CONTROL` (Android 13+)

---

## Extending the System

### Add New Telemetry
1. Add field to `AndroidCore`
2. Add message type in APK (`TelemetryService`)
3. Handle in `AndroidCore.updateFromMessage()`
4. UI reads via `ValueListenableBuilder`

### Add New JAR Command
1. Add method to `JarMain` (Java)
2. Send JSON from Windows via `JarServer.broadcast()`
3. JAR parses, executes, replies with result

### Add New APK Feature
1. Add service/receiver in APK
2. Connect to existing WebSocket or new port
3. Define message `type` + schema
4. Handle in `AndroidCore` + expose to UI

---

## Performance Notes

| Metric | Target |
|--------|--------|
| Boot to UI (USB) | < 8s |
| Boot to UI (Wi-Fi) | < 12s |
| JAR push (Wi-Fi) | ~2-4s (depends on link) |
| scrcpy latency (LAN) | 30-60ms |
| Reconnect (quick) | < 3s |
| Memory (Windows) | ~150MB base + scrcpy per window |
| CPU (idle) | < 2% |

---

## References

- [scrcpy Architecture](https://github.com/Genymobile/scrcpy/blob/master/docs/architecture.md)
- [ADB Protocol](https://android.googlesource.com/platform/system/core/+/master/adb/protocol.txt)
- [Android NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService)
- [Android MediaSessionManager](https://developer.android.com/reference/android/media/session/MediaSessionManager)