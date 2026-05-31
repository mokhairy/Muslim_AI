import 'package:flutter/material.dart';

import '../services/app_preferences_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenTab,
  });

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MuslimAI',
                style: textTheme.displaySmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Flutter rebuild for a production-grade Islamic mobile app with stronger audio, RTL, and offline foundations.',
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _Pill(label: 'Prayer times'),
                  _Pill(label: 'Quran audio'),
                  _Pill(label: 'Adhkar snapshots'),
                  _Pill(label: 'Arabic-first UI'),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HomeActionButton(
                    label: 'Open Prayer',
                    icon: Icons.access_time,
                    onTap: () => onOpenTab(1),
                  ),
                  _HomeActionButton(
                    label: 'Open Quran',
                    icon: Icons.menu_book,
                    onTap: () => onOpenTab(2),
                  ),
                  _HomeActionButton(
                    label: 'Open Library',
                    icon: Icons.library_books,
                    onTap: () => onOpenTab(3),
                  ),
                  _HomeActionButton(
                    label: 'Open More',
                    icon: Icons.tune,
                    onTap: () => onOpenTab(4),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FutureBuilder(
          future: AppPreferencesService.instance.loadQuranSession(
            defaultSurahNumber: 1,
            defaultTranslationId: '85',
            defaultReaderId: '7',
            defaultMode: 'read_listen',
          ),
          builder: (context, snapshot) {
            final session = snapshot.data;
            if (session == null) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                _FeatureCard(
                  title: 'Continue Quran',
                  body:
                      'Resume from Surah ${session.surahNumber}, Ayah ${session.activeAyahIndex + 1}. ${session.bookmarkedVerses.length} verses are bookmarked.',
                  icon: Icons.bookmark_added_outlined,
                  actionLabel: 'Resume',
                  onTap: () => onOpenTab(2),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        ),
        Text('Build direction', style: textTheme.headlineSmall),
        const SizedBox(height: 12),
        _FeatureCard(
          title: 'Quran',
          body:
              'Read, listen, and synchronized verse progression now use public Quran.com content, persistent playback, and saved reading state.',
          icon: Icons.graphic_eq,
          actionLabel: 'Go to Quran',
          onTap: () => onOpenTab(2),
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          title: 'Prayer',
          body:
              'Prayer times and qibla use AlAdhan with saved coordinates and a device-location shortcut for local accuracy.',
          icon: Icons.explore_outlined,
          actionLabel: 'Go to Prayer',
          onTap: () => onOpenTab(1),
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          title: 'Library',
          body:
              'Adhkar and Hisn Muslim stay snapshot-backed, while verified recorded morning and evening adhkar are now playable in-app.',
          icon: Icons.library_books_outlined,
          actionLabel: 'Go to Library',
          onTap: () => onOpenTab(3),
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          title: 'Settings and tools',
          body:
              'Open the More tab for reciter settings, preferences, and the technical status surfaces used in this build.',
          icon: Icons.tune,
          actionLabel: 'Go to More',
          onTap: () => onOpenTab(4),
        ),
      ],
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.body,
    required this.icon,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 24, child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(body, style: textTheme.bodyMedium),
                    if (actionLabel != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        actionLabel!,
                        style: textTheme.labelLarge,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
