import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/library_models.dart';
import '../screenshot_scene.dart';
import '../services/library_service.dart';
import '../widgets/arabic_text.dart';

enum LibrarySection { hadith, adhkar, hisn }

enum AdhkarMode { read, listen, readListen }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _service = LibraryService();
  final _adhkarPlayer = AudioPlayer();

  LibrarySection _section = AppScreenshotScene.librarySection == 'adhkar'
      ? LibrarySection.adhkar
      : AppScreenshotScene.librarySection == 'hisn'
      ? LibrarySection.hisn
      : LibrarySection.hadith;
  AdhkarMode _adhkarMode = AppScreenshotScene.adhkarMode == 'read_listen'
      ? AdhkarMode.readListen
      : AppScreenshotScene.adhkarMode == 'listen'
      ? AdhkarMode.listen
      : AdhkarMode.read;
  String _azkarCategory = AppScreenshotScene.adhkarCategory ?? '';
  bool _loading = true;
  bool _adhkarAudioLoading = false;
  bool _adhkarAudioPlaying = false;
  bool _adhkarUsesEntrySync = false;
  int _adhkarActiveEntryIndex = 0;
  String _error = '';
  String _loadedAdhkarSignature = '';
  List<HadithItem> _hadithItems = const [];
  List<int> _adhkarTrackToEntryIndex = const [];
  AdhkarCategoryData? _adhkarData;
  HisnMuslimData? _hisnData;
  AdhkarAudioSource? _adhkarAudioSource;
  StreamSubscription<PlayerState>? _adhkarPlayerStateSubscription;
  StreamSubscription<int?>? _adhkarCurrentIndexSubscription;

  @override
  void initState() {
    super.initState();
    _adhkarPlayerStateSubscription = _adhkarPlayer.playerStateStream.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _adhkarAudioLoading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
        _adhkarAudioPlaying = state.playing;
      });
    });
    _adhkarCurrentIndexSubscription = _adhkarPlayer.currentIndexStream.listen((
      index,
    ) {
      if (!mounted || !_adhkarUsesEntrySync || index == null) {
        return;
      }
      if (index < 0 || index >= _adhkarTrackToEntryIndex.length) {
        return;
      }
      setState(() => _adhkarActiveEntryIndex = _adhkarTrackToEntryIndex[index]);
    });
    _load();
  }

  @override
  void dispose() {
    _adhkarPlayerStateSubscription?.cancel();
    _adhkarCurrentIndexSubscription?.cancel();
    _adhkarPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      if (_section == LibrarySection.hadith) {
        await _adhkarPlayer.stop();
        final hadith = await _service.fetchHadithPage();
        if (!mounted) {
          return;
        }
        setState(() {
          _hadithItems = hadith;
          _adhkarData = null;
          _hisnData = null;
          _adhkarAudioSource = null;
          _loading = false;
        });
        return;
      }

      if (_section == LibrarySection.adhkar) {
        final adhkar = await _service.fetchAzkarCategory(
          _azkarCategory.isEmpty ? null : _azkarCategory,
        );
        await _resetAdhkarPlaybackForCategory(adhkar);
        if (!mounted) {
          return;
        }
        setState(() {
          _adhkarData = adhkar;
          _hisnData = null;
          _azkarCategory = adhkar.selectedCategory;
          _adhkarAudioSource = adhkar.audioSource;
          _loading = false;
        });
        return;
      }

      final hisn = await _service.fetchHisnMuslimCollection();
      await _resetAudioForCurrentContent(
        title: hisn.categoryName,
        entries: hisn.entries,
        source: hisn.audioSource,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _adhkarData = null;
        _hisnData = hisn;
        _adhkarAudioSource = hisn.audioSource;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<AdhkarEntry> get _activeEntries =>
      _section == LibrarySection.hisn
          ? (_hisnData?.entries ?? const <AdhkarEntry>[])
          : (_adhkarData?.entries ?? const <AdhkarEntry>[]);

  AdhkarAudioSource? get _activeAudioSource =>
      _section == LibrarySection.hisn
          ? _hisnData?.audioSource
          : _adhkarAudioSource;

  String get _activeCollectionTitle =>
      _section == LibrarySection.hisn
          ? (_hisnData?.categoryName ?? 'Hisn Muslim')
          : (_adhkarData?.selectedCategory ?? 'Adhkar');

  Future<void> _resetAdhkarPlaybackForCategory(
    AdhkarCategoryData categoryData,
  ) async {
    await _resetAudioForCurrentContent(
      title: categoryData.selectedCategory,
      entries: categoryData.entries,
      source: categoryData.audioSource,
    );
  }

  Future<void> _resetAudioForCurrentContent({
    required String title,
    required List<AdhkarEntry> entries,
    required AdhkarAudioSource? source,
  }) async {
    final nextSignature = _buildAdhkarAudioSignature(
      title: title,
      entries: entries,
      source: source,
    );
    if (_loadedAdhkarSignature == nextSignature) {
      return;
    }

    await _adhkarPlayer.stop();
    _loadedAdhkarSignature = '';
    _adhkarTrackToEntryIndex = const [];
    _adhkarUsesEntrySync = false;
    _adhkarActiveEntryIndex = 0;
  }

  Future<void> _ensureAdhkarAudioLoaded() async {
    final entries = _activeEntries;
    final source = _activeAudioSource;
    if (entries.isEmpty || source == null) {
      return;
    }

    final signature = _buildAdhkarAudioSignature(
      title: _activeCollectionTitle,
      entries: entries,
      source: source,
    );
    if (_loadedAdhkarSignature == signature) {
      return;
    }

    if (source.supportsEntrySync) {
      final trackUrls = <String>[];
      final trackToEntryIndex = <int>[];
      for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
        final entry = entries[entryIndex];
        for (final url in entry.audioUrls) {
          if (url.isEmpty) {
            continue;
          }
          trackUrls.add(url);
          trackToEntryIndex.add(entryIndex);
        }
      }

      if (trackUrls.isEmpty) {
        return;
      }

      await _adhkarPlayer.setAudioSources(
        [
          for (var trackIndex = 0; trackIndex < trackUrls.length; trackIndex++)
            AudioSource.uri(
              Uri.parse(trackUrls[trackIndex]),
              tag: _buildAdhkarMediaItem(
                entryIndex: trackToEntryIndex[trackIndex],
                url: trackUrls[trackIndex],
              ),
            ),
        ],
        initialIndex: 0,
        preload: true,
      );
      _adhkarUsesEntrySync = true;
      _adhkarTrackToEntryIndex = trackToEntryIndex;
      _adhkarActiveEntryIndex = trackToEntryIndex.first;
      _loadedAdhkarSignature = signature;
      return;
    }

    final categoryUrl = source.url;
    if (categoryUrl == null || categoryUrl.isEmpty) {
      return;
    }

    await _adhkarPlayer.setAudioSource(
      AudioSource.uri(
        Uri.parse(categoryUrl),
        tag: MediaItem(
          id: '$_activeCollectionTitle:category',
          album: _activeCollectionTitle,
          title: source.label,
          artist: source.voiceDescription.isEmpty
              ? 'MuslimAI'
              : source.voiceDescription,
        ),
      ),
      preload: true,
    );
    _adhkarUsesEntrySync = false;
    _adhkarTrackToEntryIndex = const [];
    _adhkarActiveEntryIndex = 0;
    _loadedAdhkarSignature = signature;
  }

  String _buildAdhkarAudioSignature({
    required String title,
    required List<AdhkarEntry> entries,
    required AdhkarAudioSource? source,
  }) {
    if (source == null) {
      return '$title:silent';
    }

    if (!source.supportsEntrySync) {
      return '$title:${source.url ?? ''}';
    }

    final urls = [for (final entry in entries) ...entry.audioUrls];
    return '$title:${urls.join('|')}';
  }

  Future<void> _toggleAdhkarPlayback() async {
    if (_activeAudioSource == null) {
      return;
    }

    if (_adhkarPlayer.playing) {
      await _adhkarPlayer.pause();
      return;
    }

    await _ensureAdhkarAudioLoaded();
    await _adhkarPlayer.play();
  }

  MediaItem _buildAdhkarMediaItem({
    required int entryIndex,
    required String url,
  }) {
    final entries = _activeEntries;
    final entry = entryIndex < entries.length ? entries[entryIndex] : null;
    final title = _activeCollectionTitle;
    return MediaItem(
      id: '$title:${entryIndex + 1}:$url',
      album: title,
      title: 'Dhikr ${entryIndex + 1}',
      artist: entry?.title ?? title,
    );
  }

  Future<void> _seekAdhkarPrevious() async {
    if (!_adhkarUsesEntrySync || _adhkarTrackToEntryIndex.isEmpty) {
      return;
    }

    final targetEntryIndex = _adhkarActiveEntryIndex - 1;
    if (targetEntryIndex < 0) {
      return;
    }
    await _playAdhkarEntry(targetEntryIndex);
  }

  Future<void> _seekAdhkarNext() async {
    final entries = _activeEntries;
    if (!_adhkarUsesEntrySync || entries.isEmpty) {
      return;
    }

    final targetEntryIndex = _adhkarActiveEntryIndex + 1;
    if (targetEntryIndex >= entries.length) {
      return;
    }
    await _playAdhkarEntry(targetEntryIndex);
  }

  Future<void> _playAdhkarEntry(int entryIndex) async {
    if (!_adhkarUsesEntrySync || _activeEntries.isEmpty) {
      return;
    }

    await _ensureAdhkarAudioLoaded();
    final trackIndex = _adhkarTrackToEntryIndex.indexOf(entryIndex);
    if (trackIndex < 0) {
      return;
    }

    setState(() => _adhkarActiveEntryIndex = entryIndex);
    await _adhkarPlayer.seek(Duration.zero, index: trackIndex);
    await _adhkarPlayer.play();
  }

  Future<void> _setAdhkarMode(AdhkarMode mode) async {
    setState(() => _adhkarMode = mode);

    if (mode == AdhkarMode.read) {
      await _adhkarPlayer.pause();
      return;
    }

    if (_activeAudioSource == null) {
      return;
    }

    await _ensureAdhkarAudioLoaded();
    await _adhkarPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final adhkarEntries = _adhkarData?.entries ?? const <AdhkarEntry>[];
    final hisnEntries = _hisnData?.entries ?? const <AdhkarEntry>[];
    final currentAdhkarEntry =
        _activeEntries.isEmpty || _adhkarActiveEntryIndex >= _activeEntries.length
        ? null
        : _activeEntries[_adhkarActiveEntryIndex];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Library', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Quran, adhkar, and Hisn al-Muslim content now aim for real recorded Arabic voice wherever a verified source exists. Entry-level sync is used when the source exposes per-item audio.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SegmentedButton<LibrarySection>(
          segments: const [
            ButtonSegment(value: LibrarySection.hadith, label: Text('Hadith')),
            ButtonSegment(value: LibrarySection.adhkar, label: Text('Adhkar')),
            ButtonSegment(
              value: LibrarySection.hisn,
              label: Text('Hisn Muslim'),
            ),
          ],
          selected: {_section},
          onSelectionChanged: (value) {
            setState(() => _section = value.first);
            _load();
          },
        ),
        const SizedBox(height: 16),
        if (_section == LibrarySection.adhkar)
          Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _azkarCategory.isEmpty ? null : _azkarCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: (_adhkarData?.categories ?? const <String>[])
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: ArabicText(
                          item,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _azkarCategory = value);
                  _load();
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<AdhkarMode>(
                segments: const [
                  ButtonSegment(
                    value: AdhkarMode.read,
                    label: Text('Read only'),
                  ),
                  ButtonSegment(
                    value: AdhkarMode.listen,
                    label: Text('Listen only'),
                  ),
                  ButtonSegment(
                    value: AdhkarMode.readListen,
                    label: Text('Read + listen'),
                  ),
                ],
                selected: {_adhkarMode},
                onSelectionChanged: (value) => _setAdhkarMode(value.first),
              ),
              const SizedBox(height: 12),
              if (_adhkarAudioSource != null && _adhkarMode != AdhkarMode.read)
                _AdhkarPlayerCard(
                  source: _adhkarAudioSource!,
                  isPlaying: _adhkarAudioPlaying,
                  isLoading: _adhkarAudioLoading,
                  usesEntrySync: _adhkarUsesEntrySync,
                  onTogglePlayback: _toggleAdhkarPlayback,
                  onPrevious: _adhkarUsesEntrySync ? _seekAdhkarPrevious : null,
                  onNext: _adhkarUsesEntrySync ? _seekAdhkarNext : null,
                )
              else if (_adhkarMode != AdhkarMode.read)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'This category is text-first right now because no verified recorded Arabic source is attached to it yet.',
                    ),
                  ),
                ),
              if (_adhkarMode != AdhkarMode.read) const SizedBox(height: 12),
            ],
          ),
        if (_section == LibrarySection.hisn)
          Column(
            children: [
              SegmentedButton<AdhkarMode>(
                segments: const [
                  ButtonSegment(
                    value: AdhkarMode.read,
                    label: Text('Read only'),
                  ),
                  ButtonSegment(
                    value: AdhkarMode.listen,
                    label: Text('Listen only'),
                  ),
                  ButtonSegment(
                    value: AdhkarMode.readListen,
                    label: Text('Read + listen'),
                  ),
                ],
                selected: {_adhkarMode},
                onSelectionChanged: (value) => _setAdhkarMode(value.first),
              ),
              const SizedBox(height: 12),
              if (_activeAudioSource != null && _adhkarMode != AdhkarMode.read)
                _AdhkarPlayerCard(
                  source: _activeAudioSource!,
                  isPlaying: _adhkarAudioPlaying,
                  isLoading: _adhkarAudioLoading,
                  usesEntrySync: _adhkarUsesEntrySync,
                  onTogglePlayback: _toggleAdhkarPlayback,
                  onPrevious: _adhkarUsesEntrySync ? _seekAdhkarPrevious : null,
                  onNext: _adhkarUsesEntrySync ? _seekAdhkarNext : null,
                ),
              if (_adhkarMode != AdhkarMode.read) const SizedBox(height: 12),
            ],
          ),
        if (_section == LibrarySection.hadith)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Recorded native-Arabic hadith narration is not attached yet. This section can render authentic Arabic text now, but Quran-style synchronized listening still requires a licensed hadith audio corpus with timing metadata.',
              ),
            ),
          ),
        if (_section == LibrarySection.hadith) const SizedBox(height: 12),
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
        else if (_section == LibrarySection.hadith)
          ..._hadithItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HadithCard(item: item),
            ),
          )
        else if (_section == LibrarySection.adhkar)
          ..._buildAdhkarContent(
            entries: adhkarEntries,
            currentEntry: currentAdhkarEntry,
          )
        else if (_section == LibrarySection.hisn)
          ..._buildAdhkarContent(
            entries: hisnEntries,
            currentEntry: currentAdhkarEntry,
          )
      ],
    );
  }

  List<Widget> _buildAdhkarContent({
    required List<AdhkarEntry> entries,
    required AdhkarEntry? currentEntry,
  }) {
    if (_adhkarMode == AdhkarMode.listen) {
      if (_adhkarUsesEntrySync && currentEntry != null) {
        return [
          _AdhkarListenOnlyCard(
            entry: currentEntry,
            indexLabel:
                '${_adhkarActiveEntryIndex + 1} of ${entries.length}',
            isPlaying: _adhkarAudioPlaying,
            isLoading: _adhkarAudioLoading,
            onTogglePlayback: _toggleAdhkarPlayback,
            onPrevious: _adhkarActiveEntryIndex > 0 ? _seekAdhkarPrevious : null,
            onNext: _adhkarActiveEntryIndex + 1 < entries.length
                ? _seekAdhkarNext
                : null,
          ),
        ];
      }

      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              _activeAudioSource == null
                  ? 'Listen mode is waiting on a verified recorded source for this category.'
                  : 'Listen mode is using a category-level recorded recitation. Switch to read + listen to keep the text visible while the recording plays.',
            ),
          ),
        ),
      ];
    }

    return entries
        .asMap()
        .entries
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ArabicEntryCard(
              title: entry.value.title,
              body: entry.value.text,
              badge: '${entry.value.repeatCount}x',
              reference: entry.value.reference,
              isActive:
                  _adhkarUsesEntrySync && entry.key == _adhkarActiveEntryIndex,
              onPlay: entry.value.audioUrls.isNotEmpty
                  ? () => _playAdhkarEntry(entry.key)
                  : null,
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _AdhkarPlayerCard extends StatelessWidget {
  const _AdhkarPlayerCard({
    required this.source,
    required this.isPlaying,
    required this.isLoading,
    required this.usesEntrySync,
    required this.onTogglePlayback,
    this.onPrevious,
    this.onNext,
  });

  final AdhkarAudioSource source;
  final bool isPlaying;
  final bool isLoading;
  final bool usesEntrySync;
  final VoidCallback onTogglePlayback;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.label, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              source.supportsEntrySync
                  ? 'This category is running on entry-level recorded audio, so the active dhikr can stay synchronized with playback.'
                  : 'This category is using a real Arabic recording, but the source is one continuous recitation rather than entry-timestamped audio.',
              style: textTheme.bodyMedium,
            ),
            if (source.voiceDescription.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(source.voiceDescription, style: textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: isLoading ? null : onPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: isLoading ? null : onTogglePlayback,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  label: Text(
                    isLoading
                        ? 'Loading…'
                        : isPlaying
                        ? 'Pause recording'
                        : 'Play recording',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isLoading ? null : onNext,
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

class _AdhkarListenOnlyCard extends StatelessWidget {
  const _AdhkarListenOnlyCard({
    required this.entry,
    required this.indexLabel,
    required this.isPlaying,
    required this.isLoading,
    required this.onTogglePlayback,
    this.onPrevious,
    this.onNext,
  });

  final AdhkarEntry entry;
  final String indexLabel;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTogglePlayback;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(indexLabel, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ArabicText(
                entry.text,
                style: textTheme.headlineSmall?.copyWith(
                  height: 1.7,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (entry.reference.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: ArabicText(
                  entry.reference,
                  style: textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: isLoading ? null : onPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: isLoading ? null : onTogglePlayback,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                  label: Text(
                    isLoading ? 'Loading…' : isPlaying ? 'Pause' : 'Play',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isLoading ? null : onNext,
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

class _HadithCard extends StatelessWidget {
  const _HadithCard({required this.item});

  final HadithItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hadith ${item.number}', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            if (item.arabicText.isNotEmpty) ...[
              ArabicText(
                item.arabicText,
                style: textTheme.headlineSmall?.copyWith(
                  height: 1.7,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(item.translation, style: textTheme.bodyLarge),
            if (item.reference.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(item.reference, style: textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArabicEntryCard extends StatelessWidget {
  const _ArabicEntryCard({
    required this.title,
    required this.body,
    required this.badge,
    required this.reference,
    this.isActive = false,
    this.onPlay,
  });

  final String title;
  final String body;
  final String badge;
  final String reference;
  final bool isActive;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: isActive
          ? scheme.primaryContainer.withValues(alpha: 0.7)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: ArabicText(title, style: textTheme.titleMedium),
                ),
                if (onPlay != null) ...[
                  IconButton(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_circle_fill),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ArabicText(
                body,
                style: textTheme.headlineSmall?.copyWith(
                  height: 1.65,
                  fontSize: 22,
                ),
              ),
            ),
            if (reference.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ArabicText(reference, style: textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
