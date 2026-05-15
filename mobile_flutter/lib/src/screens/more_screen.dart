import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('More', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'This Flutter rebuild is the new mobile direction. Expo remains in the repo only as reference while the native client catches up feature by feature.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        const _NoteCard(
          title: 'Current mobile state',
          bullets: [
            'Prayer now supports saved coordinates and device geolocation.',
            'Quran now keeps a saved last-read position, verse bookmarks, and persistent playback controls.',
            'Verified recorded adhkar audio is wired for the morning and evening categories.',
            'The shell now exposes a persistent Quran mini-player above the tab bar.',
            'API responses now cache locally so Quran and library content can reopen offline after a successful fetch.',
            'Quran, adhkar, and Hisn Muslim audio can now be downloaded onto the device for offline playback.',
          ],
        ),
        const SizedBox(height: 12),
        const _NoteCard(
          title: 'Remaining gaps',
          bullets: [
            'Adhkar category audio is still partial; unsupported categories remain text-first until a verified recording is added.',
            'Category-level adhkar recordings do not expose entry timestamps, so read + listen remains visual accompaniment rather than exact line sync.',
            'Offline mode still depends on a successful first fetch for remote Quran and Hisn Muslim content before those cached responses exist on the device.',
          ],
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final bullet in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(bullet, style: textTheme.bodyMedium)),
                ],
              ),
              if (bullet != bullets.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
