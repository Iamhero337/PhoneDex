import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/adb/adb_provider.dart';
import 'package:phonedex/src/reconnection/reconnection_manager.dart';
import 'package:phonedex/src/ui/about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _reconn = ReconnectionManager();
  
  bool _showStartMenu = false;
  bool _showNotifications = false;
  bool _showMediaController = false;
  bool _showQuickSettings = false;

  void _closeAllOverlays() {
    setState(() {
      _showStartMenu = false;
      _showNotifications = false;
      _showMediaController = false;
      _showQuickSettings = false;
    });
  }

  void _toggleStartMenu() {
    setState(() {
      final target = !_showStartMenu;
      _closeAllOverlays();
      _showStartMenu = target;
    });
  }

  void _toggleNotifications() {
    setState(() {
      final target = !_showNotifications;
      _closeAllOverlays();
      _showNotifications = target;
    });
  }

  void _toggleMediaController() {
    setState(() {
      final target = !_showMediaController;
      _closeAllOverlays();
      _showMediaController = target;
    });
  }

  void _toggleQuickSettings() {
    setState(() {
      final target = !_showQuickSettings;
      _closeAllOverlays();
      _showQuickSettings = target;
    });
  }

  Future<void> _launchScreenMirror() async {
    final core = AndroidCore.instance;
    if (core.activeTarget != null) {
      await AdbProvider().launchScrcpy(core.activeTarget!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting scrcpy stream…')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _closeAllOverlays,
        child: Stack(
          children: [
            // Background wallpaper
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F142A), Color(0xFF080B1A)],
                ),
              ),
            ),
            
            // Decorative background glowing nodes
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF006EFF).withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF006EFF).withValues(alpha: 0.12),
                      blurRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      blurRadius: 100,
                    ),
                  ],
                ),
              ),
            ),

            // Top Status Bar (Clean internal bar)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF13172E).withValues(alpha: 0.8),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('PhoneDex', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Desktop Edition', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
                    ),
                    const Spacer(),
                    _ConnectionStatus(),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white70),
                      tooltip: 'About PhoneDex',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Desktop Workspace Center Canvas
            Positioned.fill(
              top: 38,
              bottom: 50,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF006EFF).withValues(alpha: 0.35), blurRadius: 40),
                        ],
                      ),
                      child: const Icon(Icons.phone_android_rounded, size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your Phone, Elevated to Desktop',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Launch Android apps, mirror displays, control volume & media from the taskbar',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _launchScreenMirror,
                          icon: const Icon(Icons.cast_rounded, size: 18),
                          label: const Text('Mirror Display (scrcpy)', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006EFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        OutlinedButton.icon(
                          onPressed: _toggleStartMenu,
                          icon: const Icon(Icons.apps_rounded, size: 18),
                          label: const Text('App Launcher'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Start Menu Drawer Overlay
            if (_showStartMenu)
              Positioned(
                left: 16,
                bottom: 58,
                child: _StartMenuOverlay(onClose: () => setState(() => _showStartMenu = false)),
              ),

            // Notification Drawer Overlay
            if (_showNotifications)
              Positioned(
                left: 140,
                bottom: 58,
                child: _NotificationOverlay(onClose: () => setState(() => _showNotifications = false)),
              ),

            // Media Controller Overlay
            if (_showMediaController)
              Positioned(
                left: 260,
                bottom: 58,
                child: _MediaOverlay(onClose: () => setState(() => _showMediaController = false)),
              ),

            // Quick Settings / Controls Overlay
            if (_showQuickSettings)
              Positioned(
                right: 16,
                bottom: 58,
                child: _QuickSettingsOverlay(onClose: () => setState(() => _showQuickSettings = false)),
              ),

            // Reconnection system overlay
            ValueListenableBuilder<ReconnectionStatus>(
              valueListenable: _reconn.status,
              builder: (_, s, __) => s.phase != ReconnectionPhase.idle
                  ? _ReconnectionOverlay(s)
                  : const SizedBox.shrink(),
            ),

            // Desktop Taskbar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _TaskBar(
                onToggleStart: _toggleStartMenu,
                onToggleNotifications: _toggleNotifications,
                onToggleMedia: _toggleMediaController,
                onToggleSettings: _toggleQuickSettings,
                onMirror: _launchScreenMirror,
                isStartOpen: _showStartMenu,
                isNotifOpen: _showNotifications,
                isMediaOpen: _showMediaController,
                isSettingsOpen: _showQuickSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AndroidCore.instance.allConnected,
      builder: (_, connected, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (connected ? Colors.green : Colors.orange).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (connected ? Colors.green : Colors.orange).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: connected ? Colors.green : Colors.orange, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              connected ? 'Connected' : 'Connecting…',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (connected ? Colors.green : Colors.orange)[300]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskBar extends StatefulWidget {
  final VoidCallback onToggleStart;
  final VoidCallback onToggleNotifications;
  final VoidCallback onToggleMedia;
  final VoidCallback onToggleSettings;
  final VoidCallback onMirror;
  final bool isStartOpen, isNotifOpen, isMediaOpen, isSettingsOpen;

  const _TaskBar({
    required this.onToggleStart,
    required this.onToggleNotifications,
    required this.onToggleMedia,
    required this.onToggleSettings,
    required this.onMirror,
    required this.isStartOpen,
    required this.isNotifOpen,
    required this.isMediaOpen,
    required this.isSettingsOpen,
  });

  @override
  State<_TaskBar> createState() => _TaskBarState();
}

class _TaskBarState extends State<_TaskBar> {
  Timer? _clockTimer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        final n = DateTime.now();
        _time = '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = AndroidCore.instance;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF13172E).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          _StartButton(onTap: widget.onToggleStart, active: widget.isStartOpen),
          const SizedBox(width: 4),
          _TaskbarItem(label: 'Apps', icon: Icons.phone_android_rounded, color: Colors.blue, onTap: widget.onToggleStart, active: widget.isStartOpen),
          _TaskbarItem(label: 'Notifications', icon: Icons.notifications_rounded, color: Colors.orange, onTap: widget.onToggleNotifications, active: widget.isNotifOpen),
          _TaskbarItem(label: 'Media', icon: Icons.music_note_rounded, color: Colors.purple, onTap: widget.onToggleMedia, active: widget.isMediaOpen),
          _TaskbarItem(label: 'Screen Mirror', icon: Icons.cast_rounded, color: Colors.green, onTap: widget.onMirror, active: false),
          const Spacer(),
          
          // System tray
          InkWell(
            onTap: widget.onToggleSettings,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrayItem(
                    icon: core.batteryCharging ? Icons.battery_charging_full_rounded : Icons.battery_5_bar_rounded,
                    text: '${core.batteryPercentage}%',
                    color: core.batteryCharging ? Colors.green : Colors.white70,
                  ),
                  const SizedBox(width: 14),
                  _TrayItem(
                    icon: core.wifi ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    text: core.wifi ? 'Wi-Fi' : 'Off',
                    color: core.wifi ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 14),
                  _TrayItem(
                    icon: Icons.volume_up_rounded,
                    text: '${core.volumeMusic}',
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 14),
                  Text(_time, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool active;
  const _StartButton({required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF006EFF).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? const Color(0xFF006EFF) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF006EFF), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.apps_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text('Start', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskbarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool active;
  const _TaskbarItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: active ? 1.0 : 0.8), fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrayItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _TrayItem({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
        ],
      );
}

class _StartMenuOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const _StartMenuOverlay({required this.onClose});

  @override
  State<_StartMenuOverlay> createState() => _StartMenuOverlayState();
}

class _StartMenuOverlayState extends State<_StartMenuOverlay> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = AndroidCore.instance;
    final apps = core.installedApps.where((a) {
      final name = a['name'].toString().toLowerCase();
      final pkg = a['package'].toString().toLowerCase();
      return name.contains(_filter) || pkg.contains(_filter);
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        height: 480,
        decoration: BoxDecoration(
          color: const Color(0xFF13172E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24),
          ],
        ),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search apps or type package name…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
                onSubmitted: (v) {
                  if (v.isNotEmpty) {
                    core.launchApp(v);
                    widget.onClose();
                  }
                },
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            // App Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: apps.length,
                itemBuilder: (_, i) {
                  final app = apps[i];
                  return InkWell(
                    onTap: () {
                      core.launchApp(app['package']);
                      widget.onClose();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Launching ${app['name']} on device…')),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006EFF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.android_rounded, size: 24, color: Color(0xFF60A5FA)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            app['name'],
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _NotificationOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final core = AndroidCore.instance;
    final notifs = core.notifications;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        height: 440,
        decoration: BoxDecoration(
          color: const Color(0xFF13172E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text('Notifications', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  if (notifs.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        core.clearAllNotifications();
                        onClose();
                      },
                      child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.orange)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: notifs.isEmpty
                  ? Center(
                      child: Text('No active notifications', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: notifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = notifs[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(n['title'] ?? 'Android System', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12)),
                                  const Spacer(),
                                  Text(n['time'] ?? '', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(n['text'] ?? '', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _MediaOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final core = AndroidCore.instance;
    final media = core.mediaSession;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13172E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note_rounded, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text('Media Player', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFEC4899)]),
              ),
              child: const Center(child: Icon(Icons.album_rounded, size: 50, color: Colors.white70)),
            ),
            const SizedBox(height: 14),
            Text(media['title'] ?? 'No Media', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text(media['artist'] ?? 'Idle', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white), onPressed: () {}),
                IconButton(icon: const Icon(Icons.play_circle_fill_rounded, size: 40, color: Color(0xFF006EFF)), onPressed: () {}),
                IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white), onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSettingsOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _QuickSettingsOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final core = AndroidCore.instance;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13172E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Controls & Telemetry', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 14),
            Row(
              children: [
                _ControlChip(label: 'Wi-Fi', icon: Icons.wifi_rounded, active: core.wifi),
                const SizedBox(width: 8),
                _ControlChip(label: 'Bluetooth', icon: Icons.bluetooth_rounded, active: core.bluetooth),
                const SizedBox(width: 8),
                _ControlChip(label: 'Flashlight', icon: Icons.flashlight_on_rounded, active: core.torch),
              ],
            ),
            const SizedBox(height: 16),
            Text('Android Key Navigation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => core.sendBackKey(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => core.sendHomeKey(),
                    icon: const Icon(Icons.home_rounded, size: 16),
                    label: const Text('Home'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => core.sendPowerKey(),
                    icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                    label: const Text('Power'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  const _ControlChip({required this.label, required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF006EFF).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? const Color(0xFF006EFF) : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? const Color(0xFF60A5FA) : Colors.white54, size: 20),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.white60, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ReconnectionOverlay extends StatelessWidget {
  final ReconnectionStatus status;
  const _ReconnectionOverlay(this.status);

  @override
  Widget build(BuildContext context) {
    final phaseColor = switch (status.phase) {
      ReconnectionPhase.quickReconnect => Colors.blue,
      ReconnectionPhase.fullRestart => Colors.orange,
      ReconnectionPhase.failed => Colors.red,
      ReconnectionPhase.idle => Colors.green,
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF13172E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: phaseColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(status.phase.name.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: phaseColor)),
              ),
              const SizedBox(height: 20),
              Text(status.message, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Pill('Service Engine', status.jarReconnecting ? Colors.blue : (status.phase == ReconnectionPhase.idle ? Colors.green : Colors.red)),
                  const SizedBox(width: 12),
                  _Pill('Companion Hub', status.apkReconnecting ? Colors.blue : (status.phase == ReconnectionPhase.idle ? Colors.green : Colors.red)),
                ],
              ),
              if (status.phase == ReconnectionPhase.fullRestart) ...[
                const SizedBox(height: 16),
                Text('Attempt ${status.attempt} of 2', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              ],
              if (status.phase != ReconnectionPhase.failed && status.phase != ReconnectionPhase.idle) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(strokeWidth: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}