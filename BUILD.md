# PhoneDex Build & Release Process

> **Important**: Build locally → Tag version → Push artifacts to GitHub. **No GitHub Actions builds.**

## Prerequisites

### Windows
- Windows 10/11
- Visual Studio 2022 with "Desktop development with C++" workload
- Flutter SDK 3.19+ (stable)
- Git

### Linux
- Ubuntu 22.04+ / Fedora 38+ / Arch
- `clang`, `cmake`, `ninja-build`
- `libgtk-3-dev`, `libwebkit2gtk-4.0-dev` (Ubuntu/Debian)
- `gtk3-devel`, `webkit2gtk4.1-devel` (Fedora)
- Flutter SDK 3.19+ (stable)
- Git

---

## Local Build Commands

### Windows
```bash
# 1. Get dependencies
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# 2. Build release
flutter build windows --release

# 3. Bundle assets (required for app to work)
# Create build/windows/x64/runner/Release/assets/
# Copy to it:
#   - adb/adb.exe
#   - scrcpy/scrcpy.exe
#   - phonedex.jar
#   - PhoneDex.apk

# 4. Create distribution zip
cd build/windows/x64/runner/Release
zip -r PhoneDex-Windows-vX.Y.Z.zip . -x "*.pdb"
```

### Linux
```bash
# 1. Enable Linux desktop (once)
flutter create --platforms=linux .

# 2. Get dependencies
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Build release
flutter build linux --release

# 4. Bundle assets
# Create build/linux/x64/release/bundle/assets/
# Copy to it:
#   - adb/adb
#   - scrcpy/scrcpy
#   - phonedex.jar
#   - PhoneDex.apk

# 5. Create distribution tarball
cd build/linux/x64/release/bundle
tar -czf PhoneDex-Linux-vX.Y.Z.tar.gz .
```

---

## Asset Requirements

| Asset | Source | Destination |
|-------|--------|-------------|
| `adb.exe` / `adb` | Android SDK platform-tools | `assets/adb/` |
| `scrcpy.exe` / `scrcpy` | https://github.com/Genymobile/scrcpy/releases | `assets/scrcpy/` |
| `phonedex.jar` | Build from `android/jar/` module | `assets/` |
| `PhoneDex.apk` | Build from `android/apk/` module | `assets/` |

> **Note**: The JAR and APK are separate Android modules. Build them with Android Studio/Gradle first.

---

## Release Process (Local → GitHub)

### 1. Update Version
```bash
# In pubspec.yaml:
version: X.Y.Z+N  # e.g., 1.0.1+2
```

### 2. Build Both Platforms
```bash
# On Windows machine:
./build_windows.sh  # Creates PhoneDex-Windows-vX.Y.Z.zip

# On Linux machine:
./build_linux.sh    # Creates PhoneDex-Linux-vX.Y.Z.tar.gz
```

### 3. Create Git Tag & Push
```bash
git add pubspec.yaml
git commit -m "chore: bump version to vX.Y.Z"
git tag vX.Y.Z
git push origin main --tags
```

### 4. Create GitHub Release with Artifacts
```bash
# Using gh CLI (recommended):
gh release create vX.Y.Z \
  --title "PhoneDex vX.Y.Z" \
  --notes-file RELEASE_NOTES.md \
  PhoneDex-Windows-vX.Y.Z.zip \
  PhoneDex-Linux-vX.Y.Z.tar.gz

# Or manually at: https://github.com/Iamhero337/PhoneDex/releases/new
```

### 5. Update Release Notes
Create `RELEASE_NOTES.md`:
```markdown
## PhoneDex vX.Y.Z

### New Features
- Feature description

### Improvements
- Improvement description

### Bug Fixes
- Fix description

### Downloads
- [Windows](https://github.com/Iamhero337/PhoneDex/releases/download/vX.Y.Z/PhoneDex-Windows-vX.Y.Z.zip)
- [Linux](https://github.com/Iamhero337/PhoneDex/releases/download/vX.Y.Z/PhoneDex-Linux-vX.Y.Z.tar.gz)
```

---

## Version Scheme

```
MAJOR.MINOR.PATCH+BUILD
│    │    │    │
│    │    │    └─ Increment on every build/release
│    │    └────── Bug fixes, small improvements
│    └──────────── New features, backwards compatible
└───────────────── Breaking changes
```

---

## Quick Reference

| Action | Command |
|--------|---------|
| Bump patch | `sed -i 's/version: .*/version: 1.0.1+2/' pubspec.yaml` |
| Build Windows | `flutter build windows --release` |
| Build Linux | `flutter build linux --release` |
| Tag & push | `git tag v1.0.1 && git push origin main --tags` |
| Create release | `gh release create v1.0.1 --title "PhoneDex v1.0.1" --notes-file RELEASE_NOTES.md *.zip *.tar.gz` |

---

## CI/CD Policy

**No GitHub Actions builds.** All binaries are built locally on trusted machines to ensure:
- Supply chain integrity
- Reproducible builds
- No secrets in CI
- Full control over signing/notarization

The repository only contains source code and documentation. Release artifacts are attached manually after local verification.