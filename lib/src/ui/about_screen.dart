import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
            _AppInfoCard(),
            const SizedBox(height: 24),
            const _Section('About'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F3E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                'PhoneDex bridges your Android device and desktop, providing a seamless desktop experience powered by your phone. '
                'Run Android apps in resizable windows, mirror notifications, control media playback, and manage your device wirelessly.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.6,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            const _Section('Features'),
            _FeaturesGrid(),
            const SizedBox(height: 24),
            const _Section('Architecture'),
            _ArchitectureCard(),
            const SizedBox(height: 24),
            const _Section('Credits'),
            _CreditsCard(),
            const SizedBox(height: 24),
            const _Section('Links'),
            _LinksCard(),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Version 1.2.0',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF006EFF), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.phone_android_rounded, size: 48, color: Colors.white),
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
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
      );
}

class _FeaturesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _features.length,
        itemBuilder: (_, i) => _FeatureCard(f: _features[i]),
      );

  static const _features = [
    _F(Icons.view_agenda_rounded, 'Multi-Window', 'Resizable desktop windows for apps', Colors.blue),
    _F(Icons.notifications_rounded, 'Notifications', 'Push notifications to desktop', Colors.orange),
    _F(Icons.music_note_rounded, 'Media Control', 'Full playback controls', Colors.purple),
    _F(Icons.battery_charging_full_rounded, 'Live Telemetry', 'Battery, volume, device states', Colors.green),
  ];
}

class _F {
  final IconData icon;
  final String title, desc;
  final Color color;
  const _F(this.icon, this.title, this.desc, this.color);
}

class _FeatureCard extends StatelessWidget {
  final _F f;
  const _FeatureCard({required this.f});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: f.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(f.icon, color: f.color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(f.title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            const SizedBox(height: 8),
            Text(f.desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          ],
        ),
      );
}

class _ArchitectureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Three-Layer Design', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
            SizedBox(height: 12),
            _LayerCard('Windows / Linux (Flutter)', ['UI', 'ADB Lifecycle', 'Servers', 'scrcpy'], Colors.blue),
            SizedBox(height: 8),
            _LayerCard('Logic Engine (JAR)', ['Volume', 'App Launch', 'Screen Control'], Colors.purple),
            SizedBox(height: 8),
            _LayerCard('Feature Hub (APK)', ['Notifications', 'Media', 'Telemetry'], Colors.orange),
          ],
        ),
      );
}

class _LayerCard extends StatelessWidget {
  final String name;
  final List<String> items;
  final Color color;
  const _LayerCard(this.name, this.items, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(c, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.9))),
                      ))
                  .toList(),
            ),
          ],
        ),
      );
}

class _CreditsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Built with ❤️ by', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF006EFF).withValues(alpha: 0.2),
                  child: const Text('H', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF006EFF))),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hero (@iamhero337)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                    Text('Software Engineer & Open Source', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Third-Party Libraries', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LibChip('Flutter'),
                _LibChip('scrcpy'),
                _LibChip('ADB'),
                _LibChip('Riverpod'),
                _LibChip('bitsdojo_window'),
                _LibChip('window_manager'),
              ],
            ),
          ],
        ),
      );
}

class _LibChip extends StatelessWidget {
  final String name;
  const _LibChip(this.name);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(name, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
      );
}

class _LinksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Column(
        children: [
          _LinkTile('GitHub Repository', Icons.code_rounded),
          SizedBox(height: 8),
          _LinkTile('Report Issue', Icons.bug_report_rounded),
          SizedBox(height: 8),
          _LinkTile('Documentation', Icons.menu_book_rounded),
        ],
      );
}

class _LinkTile extends StatelessWidget {
  final String title;
  final IconData icon;
  const _LinkTile(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF006EFF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF006EFF), size: 20),
            ),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(color: Colors.white)),
            const Spacer(),
            Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white.withValues(alpha: 0.4)),
          ],
        ),
      );
}