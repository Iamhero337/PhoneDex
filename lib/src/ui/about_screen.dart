import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/logger.dart';

/// About and credits screen
class AboutScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('About PhoneDex'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App info card
            _AppInfoCard(packageInfo: _packageInfo),
            const SizedBox(height: 24),

            // Description
            _SectionTitle('About'),
            const SizedBox(height: 12),
            _DescriptionCard(),
            const SizedBox(height: 24),

            // Features
            _SectionTitle('Features'),
            const SizedBox(height: 12),
            _FeaturesGrid(),
            const SizedBox(height: 24),

            // Architecture
            _SectionTitle('Architecture'),
            const SizedBox(height: 12),
            _ArchitectureCard(),
            const SizedBox(height: 24),

            // Credits
            _SectionTitle('Credits'),
            const SizedBox(height: 12),
            _CreditsCard(),
            const SizedBox(height: 24),

            // Links
            _SectionTitle('Links'),
            const SizedBox(height: 12),
            _LinksCard(),
            const SizedBox(height: 32),

            // Version info
            Center(
              child: Text(
                _packageInfo != null
                    ? 'Version ${_packageInfo!.version}+${_packageInfo!.buildNumber}'
                    : 'Version 1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  final PackageInfo? packageInfo;

  const _AppInfoCard({this.packageInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF006EFF),
            Color(0xFF7C3AED),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PhoneDex',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transform your Android into a desktop experience',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          if (packageInfo != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'v${packageInfo!.version} (${packageInfo!.buildNumber})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        'PhoneDex bridges your Android device and desktop computer, providing a seamless desktop experience powered by your phone. '
        'Run Android apps in resizable windows, mirror notifications, control media playback, and manage your device — all wirelessly with first-connect reliability.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.white.withOpacity(0.8),
          height: 1.6,
        ),
      ),
    );
  }
}

class _FeaturesGrid extends StatelessWidget {
  final _features = const [
    _Feature(
      icon: Icons.view_agenda_rounded,
      title: 'Multi-Window Apps',
      desc: 'Each Android app runs in its own resizable, movable desktop window',
      color: Colors.blue,
    ),
    _Feature(
      icon: Icons.notifications_rounded,
      title: 'Live Notifications',
      desc: 'Android notifications pushed instantly to your Windows desktop',
      color: Colors.orange,
    ),
    _Feature(
      icon: Icons.music_note_rounded,
      title: 'Media Control',
      desc: 'Full artwork, metadata, and playback controls for any media session',
      color: Colors.purple,
    ),
    _Feature(
      icon: Icons.battery_charging_full_rounded,
      title: 'Live Telemetry',
      desc: 'Real-time battery, volume, Wi-Fi, Bluetooth, and device states',
      color: Colors.green,
    ),
    _Feature(
      icon: Icons.flash_on_rounded,
      title: 'Low Latency',
      desc: 'Shell-level commands bypass UI overhead for responsive control',
      color: Colors.amber,
    ),
    _Feature(
      icon: Icons.healing_rounded,
      title: 'Auto-Healing',
      desc: 'Multi-stage reconnection restores connection seamlessly on disconnect',
      color: Colors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _features.length,
      itemBuilder: (context, index) {
        final f = _features[index];
        return _FeatureCard(feature: f);
      },
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _Feature({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: feature.color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            feature.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feature.desc,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchitectureCard extends StatelessWidget {
  final _layers = const [
    _Layer(
      name: 'Windows Side (Flutter)',
      components: ['Desktop UI', 'ADB Lifecycle', 'Server Infrastructure', 'scrcpy Embedding'],
      color: Colors.blue,
    ),
    _Layer(
      name: 'Logic Engine (Java JAR)',
      components: ['Volume Control', 'App Launch/Kill', 'Screen Wake/Sleep', 'Display Interaction'],
      color: Colors.purple,
    ),
    _Layer(
      name: 'Feature Hub (Kotlin APK)',
      components: ['Notification Listener', 'Media Session', 'Battery/Device Telemetry', 'Permissions'],
      color: Colors.orange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Three-Layer Architecture',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Both Android-side components connect back to the Windows host — the Windows app runs the servers; Android clients connect to them.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          ..._layers.map((layer) => _LayerCard(layer: layer)).toList(),
        ],
      ),
    );
  }
}

class _Layer {
  final String name;
  final List<String> components;
  final Color color;

  const _Layer({
    required this.name,
    required this.components,
    required this.color,
  });
}

class _LayerCard extends StatelessWidget {
  final _Layer layer;

  const _LayerCard({required this.layer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: layer.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: layer.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: layer.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                layer.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: layer.components.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: layer.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: layer.color.withOpacity(0.9),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Built with ❤️ by',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF006EFF).withOpacity(0.2),
                child: const Text(
                  'H',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF006EFF),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hero (@iamhero337)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Software Engineer & Open Source Contributor',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _SocialButton(
                icon: Icons.alternate_email_rounded,
                label: 'Twitter',
                onTap: () => launchUrl(Uri.parse('https://twitter.com/iamhero337')),
              ),
              const SizedBox(width: 8),
              _SocialButton(
                icon: Icons.code_rounded,
                label: 'GitHub',
                onTap: () => launchUrl(Uri.parse('https://github.com/iamhero337')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'Third-Party Libraries',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _libraries.map((lib) => _LibraryChip(
              name: lib.name,
              url: lib.url,
            )).toList(),
          ),
        ],
      ),
    );
  }

  static const _libraries = [
    _Lib('Flutter', 'https://flutter.dev'),
    _Lib('scrcpy', 'https://github.com/Genymobile/scrcpy'),
    _Lib('ADB', 'https://developer.android.com/studio/command-line/adb'),
    _Lib('Riverpod', 'https://riverpod.dev'),
    _Lib('WebSocket Channel', 'https://pub.dev/packages/web_socket_channel'),
    _Lib('Window Manager', 'https://pub.dev/packages/window_manager'),
    _Lib('Bitsdojo Window', 'https://pub.dev/packages/bitsdojo_window'),
    _Lib('Package Info Plus', 'https://pub.dev/packages/package_info_plus'),
    _Lib('URL Launcher', 'https://pub.dev/packages/url_launcher'),
  ];
}

class _Lib {
  final String name;
  final String url;

  const _Lib(this.name, this.url);
}

class _LibraryChip extends StatelessWidget {
  final String name;
  final String url;

  const _LibraryChip({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  final _links = const [
    _Link('GitHub Repository', 'https://github.com/iamhero337/PhoneDex', Icons.code_rounded),
    _Link('Report Issue', 'https://github.com/iamhero337/PhoneDex/issues', Icons.bug_report_rounded),
    _Link('Documentation', 'https://github.com/iamhero337/PhoneDex/wiki', Icons.menu_book_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _links.map((link) => _LinkTile(
        title: link.title,
        url: link.url,
        icon: link.icon,
      )).toList(),
    );
  }
}

class _Link {
  final String title;
  final String url;
  final IconData icon;

  const _Link(this.title, this.url, this.icon);
}

class _LinkTile extends StatelessWidget {
  final String title;
  final String url;
  final IconData icon;

  const _LinkTile({required this.title, required this.url, required this.icon});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F3E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF006EFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF006EFF), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}