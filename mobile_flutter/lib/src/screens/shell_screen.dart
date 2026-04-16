import 'package:flutter/material.dart';

import '../services/quran_audio_controller.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'more_screen.dart';
import 'prayer_screen.dart';
import 'quran_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final _audioController = QuranAudioController.instance;
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    PrayerScreen(),
    QuranScreen(),
    LibraryScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _audioController,
      builder: (context, _) => Scaffold(
        body: SafeArea(child: _screens[_index]),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_audioController.hasPlaylist) _MiniPlayer(
              controller: _audioController,
              onOpenQuran: () => setState(() => _index = 2),
            ),
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.access_time_outlined),
                  selectedIcon: Icon(Icons.access_time),
                  label: 'Prayer',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Quran',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: 'More',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.controller,
    required this.onOpenQuran,
  });

  final QuranAudioController controller;
  final VoidCallback onOpenQuran;

  @override
  Widget build(BuildContext context) {
    final ayah = controller.currentAyah;
    final surah = controller.surah;
    final textTheme = Theme.of(context).textTheme;

    if (ayah == null || surah == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onOpenQuran,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${surah.englishName} • Ayah ${ayah.numberInSurah}',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.readerLabel,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.activeIndex > 0
                    ? controller.seekPrevious
                    : null,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                onPressed: controller.togglePlayback,
                icon: Icon(
                  controller.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
              ),
              IconButton(
                onPressed:
                    controller.activeIndex + 1 < controller.ayahs.length
                    ? controller.seekNext
                    : null,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
