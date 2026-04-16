import 'package:flutter/material.dart';

import '../models/quran_models.dart';
import '../services/app_preferences_service.dart';
import '../services/quran_audio_controller.dart';
import '../services/quran_service.dart';

enum QuranMode { read, listen, readListen }

String _quranModeValue(QuranMode mode) {
  switch (mode) {
    case QuranMode.read:
      return 'read';
    case QuranMode.listen:
      return 'listen';
    case QuranMode.readListen:
      return 'read_listen';
  }
}

QuranMode _quranModeFromValue(String value) {
  switch (value) {
    case 'read':
      return QuranMode.read;
    case 'listen':
      return QuranMode.listen;
    default:
      return QuranMode.readListen;
  }
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _service = QuranService();
  final _preferences = AppPreferencesService.instance;
  final _audioController = QuranAudioController.instance;

  List<SurahSummary> _surahs = const [];
  SurahDetail? _detail;
  Set<String> _bookmarks = <String>{};
  QuranMode _mode = QuranMode.readListen;
  String _translation = QuranService.translationOptions.first.value;
  String _reader = QuranService.readerOptions.first.value;
  int _surahNumber = 1;
  int _initialAyahIndex = 0;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _audioController.addListener(_onAudioStateChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _audioController.removeListener(_onAudioStateChanged);
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final session = await _preferences.loadQuranSession(
        defaultSurahNumber: _surahNumber,
        defaultTranslationId: _translation,
        defaultReaderId: _reader,
        defaultMode: _quranModeValue(_mode),
      );

      final surahs = await _service.fetchSurahList();
      final detail = await _service.fetchSurahDetail(
        surahNumber: session.surahNumber,
        translationId: session.translationId,
        readerId: session.readerId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _surahs = surahs;
        _detail = detail;
        _surahNumber = session.surahNumber;
        _translation = session.translationId;
        _reader = session.readerId;
        _mode = _quranModeFromValue(session.mode);
        _bookmarks = session.bookmarkedVerses;
        _initialAyahIndex = session.activeAyahIndex;
        _loading = false;
      });

      if (detail.surah != null) {
        await _audioController.setPlaylist(
          surah: detail.surah!,
          ayahs: detail.ayahs,
          translationId: _translation,
          readerId: _reader,
          readerLabel: _readerLabelFor(_reader),
          mode: _quranModeValue(_mode),
          initialIndex: _initialAyahIndex,
          autoplay: false,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _reloadSurah({
    int? initialIndex,
    bool autoplay = false,
  }) async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final detail = await _service.fetchSurahDetail(
        surahNumber: _surahNumber,
        translationId: _translation,
        readerId: _reader,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _loading = false;
      });

      if (detail.surah != null) {
        await _audioController.setPlaylist(
          surah: detail.surah!,
          ayahs: detail.ayahs,
          translationId: _translation,
          readerId: _reader,
          readerLabel: _readerLabelFor(_reader),
          mode: _quranModeValue(_mode),
          initialIndex: initialIndex ?? 0,
          autoplay: autoplay && _mode != QuranMode.read,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _setMode(QuranMode mode) async {
    setState(() => _mode = mode);
    await _audioController.updateMode(_quranModeValue(mode));

    if (mode == QuranMode.read) {
      await _audioController.pause();
      return;
    }

    if (_detail?.ayahs.isEmpty ?? true) {
      return;
    }

    await _audioController.playFromIndex(_audioController.activeIndex);
  }

  Future<void> _toggleBookmark(String verseKey) async {
    final bookmarks = await _preferences.toggleBookmarkedVerse(verseKey);
    if (!mounted) {
      return;
    }
    setState(() => _bookmarks = bookmarks);
  }

  String _readerLabelFor(String value) {
    return QuranService.readerOptions
            .firstWhere(
              (item) => item.value == value,
              orElse: () => const SelectionOption(value: '', label: 'Reciter'),
            )
            .label;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ayahs = _detail?.ayahs ?? const <AyahRow>[];
    final activeIndex = _audioController.activeIndex;
    final activeAyah =
        ayahs.isEmpty || activeIndex >= ayahs.length ? null : ayahs[activeIndex];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Quran', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Recorded reciter audio now stays persistent across the app, keeps a last-read position, and supports verse bookmarks.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (_detail != null)
          _ResumeCard(
            activeAyahIndex: activeIndex,
            totalAyahs: ayahs.length,
            bookmarkCount: _bookmarks.length,
            onResume: ayahs.isEmpty
                ? null
                : () => _audioController.playFromIndex(activeIndex),
          ),
        if (_detail != null) const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _surahs.any((item) => item.number == _surahNumber)
                      ? _surahNumber
                      : null,
                  decoration: const InputDecoration(labelText: 'Surah'),
                  items: _surahs
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.number,
                          child: Text('${item.number}. ${item.englishName}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    final autoplay = _audioController.isPlaying;
                    setState(() => _surahNumber = value);
                    _reloadSurah(initialIndex: 0, autoplay: autoplay);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _translation,
                  decoration: const InputDecoration(labelText: 'Translation'),
                  items: QuranService.translationOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.value,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    final autoplay = _audioController.isPlaying;
                    setState(() => _translation = value);
                    _reloadSurah(
                      initialIndex: _audioController.activeIndex,
                      autoplay: autoplay,
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _reader,
                  decoration: const InputDecoration(labelText: 'Sheikh'),
                  items: QuranService.readerOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.value,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    final autoplay = _audioController.isPlaying;
                    setState(() => _reader = value);
                    _reloadSurah(
                      initialIndex: _audioController.activeIndex,
                      autoplay: autoplay,
                    );
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<QuranMode>(
                  segments: const [
                    ButtonSegment(
                      value: QuranMode.read,
                      label: Text('Read only'),
                    ),
                    ButtonSegment(
                      value: QuranMode.listen,
                      label: Text('Listen only'),
                    ),
                    ButtonSegment(
                      value: QuranMode.readListen,
                      label: Text('Read + listen'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) => _setMode(value.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(_error),
            ),
          )
        else ...[
          if (_detail?.surah != null) _SurahHeader(surah: _detail!.surah!),
          const SizedBox(height: 12),
          if (_mode == QuranMode.listen)
            _ListenOnlyCard(
              ayah: activeAyah,
              currentIndex: activeIndex,
              totalAyahs: ayahs.length,
              isPlaying: _audioController.isPlaying,
              audioLoading: _audioController.isLoading,
              onTogglePlayback: _audioController.togglePlayback,
              onStepBack: activeIndex > 0 ? _audioController.seekPrevious : null,
              onStepForward:
                  activeIndex + 1 < ayahs.length ? _audioController.seekNext : null,
            )
          else
            ...ayahs.asMap().entries.map((entry) {
              final index = entry.key;
              final ayah = entry.value;
              final isActive = index == activeIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AyahCard(
                  ayah: ayah,
                  isActive: isActive,
                  isBookmarked: _bookmarks.contains(ayah.verseKey),
                  onBookmark: () => _toggleBookmark(ayah.verseKey),
                  onPlay: ayah.audioUrl.isEmpty
                      ? null
                      : () => _audioController.playFromIndex(index),
                ),
              );
            }),
        ],
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.activeAyahIndex,
    required this.totalAyahs,
    required this.bookmarkCount,
    required this.onResume,
  });

  final int activeAyahIndex;
  final int totalAyahs;
  final int bookmarkCount;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resume reading', style: textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Ayah ${activeAyahIndex + 1} of $totalAyahs • $bookmarkCount bookmarks',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onResume,
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah});

  final SurahSummary surah;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(surah.englishName, style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                surah.name,
                style: textTheme.displaySmall?.copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${surah.numberOfAyahs} ayahs • ${surah.englishNameTranslation} • ${surah.revelationType}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard({
    required this.ayah,
    required this.isActive,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onPlay,
  });

  final AyahRow ayah;
  final bool isActive;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isActive
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.65)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, child: Text('${ayah.numberInSurah}')),
                const Spacer(),
                IconButton(
                  onPressed: onBookmark,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  ),
                ),
                if (onPlay != null)
                  IconButton(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_circle_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ayah.arabicText,
                textAlign: TextAlign.right,
                style: theme.textTheme.headlineSmall?.copyWith(height: 1.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(ayah.translationText, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _ListenOnlyCard extends StatelessWidget {
  const _ListenOnlyCard({
    required this.ayah,
    required this.currentIndex,
    required this.totalAyahs,
    required this.isPlaying,
    required this.audioLoading,
    required this.onTogglePlayback,
    required this.onStepBack,
    required this.onStepForward,
  });

  final AyahRow? ayah;
  final int currentIndex;
  final int totalAyahs;
  final bool isPlaying;
  final bool audioLoading;
  final VoidCallback onTogglePlayback;
  final VoidCallback? onStepBack;
  final VoidCallback? onStepForward;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              'Verse ${currentIndex + 1} of $totalAyahs',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (ayah != null) ...[
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  ayah!.arabicText,
                  textAlign: TextAlign.right,
                  style: textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Text(ayah!.translationText, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onStepBack,
                  icon: const Icon(Icons.skip_previous),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: audioLoading ? null : onTogglePlayback,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  label: Text(
                    audioLoading
                        ? 'Loading…'
                        : isPlaying
                        ? 'Pause'
                        : 'Play',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onStepForward,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
