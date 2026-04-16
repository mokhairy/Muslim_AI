import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/library_models.dart';
import '../services/adhkar_audio_catalog.dart';
import '../services/library_service.dart';

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

  LibrarySection _section = LibrarySection.hadith;
  AdhkarMode _adhkarMode = AdhkarMode.read;
  String _azkarCategory = '';
  bool _loading = true;
  bool _adhkarAudioLoading = false;
  bool _adhkarAudioPlaying = false;
  String _error = '';
  String _loadedAdhkarUrl = '';
  List<HadithItem> _hadithItems = const [];
  AdhkarCategoryData? _adhkarData;
  HisnMuslimData? _hisnData;
  AdhkarAudioSource? _adhkarAudioSource;
  StreamSubscription<PlayerState>? _adhkarPlayerStateSubscription;

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
    _load();
  }

  @override
  void dispose() {
    _adhkarPlayerStateSubscription?.cancel();
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
        final hadith = await _service.fetchHadithPage();
        if (!mounted) {
          return;
        }
        setState(() {
          _hadithItems = hadith;
          _loading = false;
        });
        return;
      }

      if (_section == LibrarySection.adhkar) {
        final adhkar = await _service.fetchAzkarCategory(
          _azkarCategory.isEmpty ? null : _azkarCategory,
        );
        final audioSource =
            AdhkarAudioCatalog.categoryAudio[adhkar.selectedCategory];
        if (!mounted) {
          return;
        }
        setState(() {
          _adhkarData = adhkar;
          _azkarCategory = adhkar.selectedCategory;
          _adhkarAudioSource = audioSource;
          _loading = false;
        });
        if (_loadedAdhkarUrl.isNotEmpty &&
            audioSource?.url != _loadedAdhkarUrl) {
          await _adhkarPlayer.stop();
          _loadedAdhkarUrl = '';
        }
        return;
      }

      final hisn = await _service.fetchHisnMuslimCollection();
      if (!mounted) {
        return;
      }
      setState(() {
        _hisnData = hisn;
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

  Future<void> _ensureAdhkarAudioLoaded() async {
    final source = _adhkarAudioSource;
    if (source == null) {
      return;
    }
    if (_loadedAdhkarUrl == source.url) {
      return;
    }

    await _adhkarPlayer.setUrl(source.url);
    _loadedAdhkarUrl = source.url;
  }

  Future<void> _toggleAdhkarPlayback() async {
    if (_adhkarAudioSource == null) {
      return;
    }

    if (_adhkarPlayer.playing) {
      await _adhkarPlayer.pause();
      return;
    }

    await _ensureAdhkarAudioLoaded();
    await _adhkarPlayer.play();
  }

  Future<void> _setAdhkarMode(AdhkarMode mode) async {
    setState(() => _adhkarMode = mode);

    if (mode == AdhkarMode.read) {
      await _adhkarPlayer.pause();
      return;
    }

    if (_adhkarAudioSource == null) {
      return;
    }

    await _ensureAdhkarAudioLoaded();
    await _adhkarPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Library', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Hadith stays remote with fallback content. Adhkar and Hisn Muslim are loaded from local snapshots, while verified native-speaker adhkar audio is wired category by category.',
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
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
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
                  onTogglePlayback: _toggleAdhkarPlayback,
                )
              else if (_adhkarMode != AdhkarMode.read)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Recorded audio is currently verified for morning and evening adhkar only. This category remains text-first until a matching audio source is added.',
                    ),
                  ),
                ),
              if (_adhkarMode != AdhkarMode.read) const SizedBox(height: 12),
            ],
          ),
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
          ...(_adhkarMode == AdhkarMode.listen
              ? <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        _adhkarAudioSource == null
                            ? 'Listen mode is waiting on a verified recorded source for this category.'
                            : 'Listen mode is playing the recorded category recitation while keeping the text available when you switch to read + listen.',
                      ),
                    ),
                  ),
                ]
              : (_adhkarData?.entries
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ArabicEntryCard(
                              title: item.title,
                              body: item.text,
                              badge: '${item.repeatCount}x',
                            ),
                          ),
                        )
                        .toList() ??
                    const <Widget>[]))
        else
          ...?_hisnData?.entries.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ArabicEntryCard(
                title: _hisnData!.categoryName,
                body: item.text,
                badge: '${item.repeatCount}x',
              ),
            ),
          ),
      ],
    );
  }
}

class _AdhkarPlayerCard extends StatelessWidget {
  const _AdhkarPlayerCard({
    required this.source,
    required this.isPlaying,
    required this.isLoading,
    required this.onTogglePlayback,
  });

  final AdhkarAudioSource source;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTogglePlayback;

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
                  ? 'This source includes entry-level sync support.'
                  : 'This verified recording is category-level audio. It preserves native Arabic recitation but does not expose entry timestamps.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
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
  });

  final String title;
  final String body;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: textTheme.titleMedium)),
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
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                body,
                textAlign: TextAlign.right,
                style: textTheme.headlineSmall?.copyWith(
                  height: 1.65,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
