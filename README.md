# PhoneDex

Transform your Android device into a desktop experience. Run Android apps in resizable windows, mirror notifications, control media, manage your device — all wirelessly from Windows or Linux.

## Download

| Platform | Download |
|----------|----------|
| **Windows** | [PhoneDex-Windows.zip](https://github.com/iamhero337/PhoneDex/releases/latest/download/PhoneDex-Windows.zip) |
| **Linux** | [PhoneDex-Linux.tar.gz](https://github.com/iamhero337/PhoneDex/releases/latest/download/PhoneDex-Linux.tar.gz) |

## Quick Start

### Prerequisites
- Android 8.0+ with **Developer Options** enabled
- **USB Debugging** ON (Settings → Developer Options)
- For Wi-Fi: **Wireless Debugging** ON (Android 11+), same network as PC

### Connect

**Option 1: USB (easiest first time)**
```bash
# Windows
PhoneDex.exe

# Linux
./PhoneDex
```

**Option 2: Wi-Fi (after initial USB pairing)**
1. Connect via USB once to install companion app
2. On phone: Settings → Developer Options → Wireless Debugging → "Pair device with pairing code"
3. Run PhoneDex, click "Open ADB Manager", enter IP:port shown on phone

### Launch Options
```bash
PhoneDex.exe                    # Auto-detect (USB first, then Wi-Fi)
PhoneDex.exe --usb              # Force USB only
PhoneDex.exe 192.168.1.50       # Connect to IP (port 5555)
PhoneDex.exe 192.168.1.50:5555  # Explicit IP:port
```

## Features

| Feature | Description |
|---------|-------------|
| **Multi-Window Apps** | Each Android app runs in its own resizable, movable desktop window |
| **Live Notifications** | Android notifications appear instantly on your desktop |
| **Media Control** | Full artwork, metadata, playback controls for any media session |
| **Device Telemetry** | Real-time battery, volume, Wi-Fi, Bluetooth, mobile data, location, torch |
| **Low Latency** | Shell-level commands bypass UI overhead; scrcpy H.264 streaming |
| **Auto-Healing** | Multi-phase reconnection restores link seamlessly on disconnect |
| **Wireless-First** | Works over Wi-Fi on first connect — no USB required after setup |

## Architecture

Three-layer design with cryptographic-style handshake:

```
┌─────────────────────────────────────────────────────────────┐
│  WINDOWS (Flutter Desktop)                                  │
│  • UI, ADB lifecycle, server infrastructure, scrcpy embed  │
└─────────────────────┬───────────────────────────────────────┘
                      │ TCP:8080 (JAR)    WebSocket:8081 (APK)
                      ▼                     ▼
┌───────────────────────────────┐   ┌─────────────────────────────────┐
│  LOGIC ENGINE (Java JAR)      │   │  FEATURE HUB (Kotlin APK)       │
│  ADB shell context (elevated) │   │  Android app context (permissions)│
│  • Volume control             │   │  • NotificationListenerService  │
│  • App launch/kill            │   │  • MediaSessionManager          │
│  • Screen wake/sleep          │   │  • Battery/device telemetry     │
│  • Display interaction        │   │  • Permission management        │
└───────────────────────────────┘   └─────────────────────────────────┘
```

**Handshake Protocol:**
1. Windows starts ADB server, connects device, sets up `adb reverse` ports
2. Pushes `phonedex.jar` → launches via `app_process` → JAR connects TCP → sends `{"type":"jar.hello"}`
3. Installs/starts `PhoneDex.apk` → APK connects WebSocket → sends `{"type":"apk.hello"}`
4. Both handshakes confirmed → Desktop UI unlocks

See [ARCHITECTURE.md](ARCHITECTURE.md) for deep dive.

## Reconnection System

| Phase | Trigger | Action |
|-------|---------|--------|
| **Quick Reconnect** | First disconnect | `adb connect` + `adb reverse` → wait for handshakes (15s) |
| **Full Restart** (×2) | Quick fails | Kill JAR/APK → re-push JAR → re-launch services → wait handshakes |
| **Failed** | Both retries fail | Overlay shows error; user can re-pick device |

## Building from Source

### Prerequisites
- Flutter SDK 3.19+
- Android SDK (for companion APK/JAR)
- Windows: Visual Studio 2022 + Desktop C++ workload
- Linux: `clang`, `cmake`, `ninja`, `gtk-3.0`, `webkit2gtk-4.0`

### Build
```bash
git clone https://github.com/iamhero337/PhoneDex.git
cd PhoneDex
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

### Bundle Assets
Place in `build/<platform>/assets/`:
- `adb/adb.exe` (or `adb` on Linux)
- `scrcpy/scrcpy.exe` (or `scrcpy`)
- `phonedex.jar` (Logic Engine)
- `PhoneDex.apk` (Feature Hub)

## Project Structure

```
lib/
├── main.dart                      # App entry, window setup
├── src/
│   ├── core/
│   │   ├── app_manager.dart       # Boot orchestration (11 steps)
│   │   └── device.dart            # ConnectionTarget, DeviceInfo
│   ├── adb/
│   │   └── adb_provider.dart      # ADB binary resolution, commands
│   ├── jar/
│   │   ├── jar_manager.dart       # JAR deploy, progress, handshake
│   │   └── jar_server.dart        # TCP:8080 server
│   ├── apk/
│   │   ├── apk_manager.dart       # APK install, service start
│   │   └── apk_server.dart        # WebSocket:8081 server
│   ├── reconnection/
│   │   └── reconnection_manager.dart  # Auto-healing logic
│   ├── state/
│   │   └── android_core.dart      # Central reactive state (ValueNotifiers)
│   └── ui/
│       ├── boot_screen.dart       # Dual progress bars, error UI
│       ├── home_screen.dart       # Desktop, taskbar, overlay
│       ├── device_picker_dialog.dart  # ADB device selection
│       └── about_screen.dart      # Credits, links
```

## Credits

Built by **[@iamhero337](https://twitter.com/iamhero337)**

Third-party:
- [scrcpy](https://github.com/Genymobile/scrcpy) — screen/audio streaming
- [Flutter](https://flutter.dev) — UI framework
- [Riverpod](https://riverpod.dev) — state management
- [bitsdojo_window](https://pub.dev/packages/bitsdojo_window) — custom window chrome
- [window_manager](https://pub.dev/packages/window_manager) — window controls

## License

MIT License — see [LICENSE](LICENSE)