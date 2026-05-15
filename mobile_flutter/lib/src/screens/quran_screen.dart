import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prayer_models.dart';
import '../screenshot_scene.dart';
import '../models/quran_models.dart';
import '../services/app_preferences_service.dart';
import '../services/offline_cache_service.dart';
import '../services/prayer_audio_routing_service.dart';
import '../services/quran_audio_controller.dart';
import '../services/quran_service.dart';
import '../services/shared_audio_player.dart';
import '../widgets/arabic_text.dart';
import '../widgets/audio_output_routing_card.dart';

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
  final _offlineCache = OfflineCacheService.instance;
  final _audioRouting = AudioOutputRoutingService(owner: SharedAudioOwner.quran);

  List<SurahSummary> _surahs = const [];
  SurahDetail? _detail;
  Set<String> _bookmarks = <String>{};
  QuranMode _mode = QuranMode.readListen;
  String _translation = QuranService.translationOptions.first.value;
  String _reader = QuranService.readerOptions.first.value;
  int _surahNumber = 1;
  int _initialAyahIndex = 0;
  bool _loading = true;
  bool _downloadBusy = false;
  int _downloadedAyahAudioCount = 0;
  SpeakerRouteMode _speakerRouteMode = SpeakerRouteMode.mobileOnly;
  Set<String> _selectedSpeakerIds = <String>{};
  String _error = '';

  @override
  void initState() {
    super.initState();
    _audioController.addListener(_onAudioStateChanged);
    _audioRouting.addListener(_onAudioRoutingChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _audioController.removeListener(_onAudioStateChanged);
    _audioRouting.removeListener(_onAudioRoutingChanged);
    unawaited(_audioRouting.shutdown());
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _onAudioRoutingChanged() {
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
      final screenshotMode = AppScreenshotScene.quranMode;
      final session = screenshotMode == null
          ? await _preferences.loadQuranSession(
              defaultSurahNumber: _surahNumber,
              defaultTranslationId: _translation,
              defaultReaderId: _reader,
              defaultMode: _quranModeValue(_mode),
            )
          : QuranSessionSnapshot(
              surahNumber: 2,
              translationId: '85',
              readerId: '7',
              mode: screenshotMode,
              activeAyahIndex: 1,
              bookmarkedVerses: const {'2:2', '2:3', '2:5'},
            );

      final savedRouting = await _preferences.loadAudioOutputRouting(
        scope: 'quran',
        defaultMode: SpeakerRouteMode.mobileOnly,
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
        _speakerRouteMode = savedRouting.mode;
        _selectedSpeakerIds = savedRouting.selectedDeviceIds;
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
      await _refreshDownloadStatus();
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
      await _refreshDownloadStatus();
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

    if (_speakerRouteMode == SpeakerRouteMode.mobileOnly) {
      await _audioController.playFromIndex(_audioController.activeIndex);
      return;
    }

    await _broadcastAyahAtIndex(_audioController.activeIndex);
  }

  Future<void> _toggleBookmark(String verseKey) async {
    final bookmarks = await _preferences.toggleBookmarkedVerse(verseKey);
    if (!mounted) {
      return;
    }
    setState(() => _bookmarks = bookmarks);
  }

  List<String> get _currentAudioUrls =>
      (_detail?.ayahs ?? const <AyahRow>[])
          .where((ayah) => ayah.audioUrl.isNotEmpty)
          .map((ayah) => ayah.audioUrl)
          .toSet()
          .toList(growable: false);

  Future<void> _refreshDownloadStatus() async {
    final downloadedCount = await _offlineCache.countDownloadedAudioUrls(
      _currentAudioUrls,
    );
    if (!mounted) {
      return;
    }
    setState(() => _downloadedAyahAudioCount = downloadedCount);
  }

  Future<void> _downloadCurrentSurahAudio() async {
    final urls = _currentAudioUrls;
    if (urls.isEmpty) {
      return;
    }

    final shouldResume = _audioController.isPlaying && _mode != QuranMode.read;
    setState(() => _downloadBusy = true);
    try {
      await _offlineCache.downloadAudioUrls(urls);
      if (_detail?.surah != null) {
        await _audioController.setPlaylist(
          surah: _detail!.surah!,
          ayahs: _detail!.ayahs,
          translationId: _translation,
          readerId: _reader,
          readerLabel: _readerLabelFor(_reader),
          mode: _quranModeValue(_mode),
          initialIndex: _audioController.activeIndex,
          autoplay: shouldResume,
        );
      }
      await _refreshDownloadStatus();
    } finally {
      if (mounted) {
        setState(() => _downloadBusy = false);
      }
    }
  }

  Future<void> _removeCurrentSurahAudio() async {
    final urls = _currentAudioUrls;
    if (urls.isEmpty) {
      return;
    }

    final shouldResume = _audioController.isPlaying && _mode != QuranMode.read;
    setState(() => _downloadBusy = true);
    try {
      await _offlineCache.removeAudioUrls(urls);
      if (_detail?.surah != null) {
        await _audioController.setPlaylist(
          surah: _detail!.surah!,
          ayahs: _detail!.ayahs,
          translationId: _translation,
          readerId: _reader,
          readerLabel: _readerLabelFor(_reader),
          mode: _quranModeValue(_mode),
          initialIndex: _audioController.activeIndex,
          autoplay: shouldResume,
        );
      }
      await _refreshDownloadStatus();
    } finally {
      if (mounted) {
        setState(() => _downloadBusy = false);
      }
    }
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
                : () => _playAyah(activeIndex),
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
                const SizedBox(height: 16),
                AudioOutputRoutingCard(
                  title: 'Speaker Output',
                  description:
                      'Save a Quran-specific output preset. Keep recitation on this phone, or scan the local network and broadcast the current ayah to selected smart speakers.',
                  routeMode: _speakerRouteMode,
                  selectedSpeakerIds: _selectedSpeakerIds,
                  discoveredDevices: _audioRouting.devices,
                  isDiscovering: _audioRouting.isDiscovering,
                  isBusy: _audioRouting.isBusy,
                  statusMessage: _audioRouting.statusMessage,
                  errorMessage: _audioRouting.errorMessage,
                  isPhonePlaybackActive:
                      _audioController.isPlaying || _audioRouting.isPhonePlaybackActive,
                  hasRemotePlayback: _audioRouting.hasRemotePlayback,
                  onScanPressed: _audioRouting.isDiscovering
                      ? _audioRouting.stopDiscovery
                      : _audioRouting.startDiscovery,
                  onPlayPressed: ayahs.isEmpty
                      ? () async {}
                      : () => _playAyah(activeIndex),
                  onStopPressed: _stopAudioOutput,
                  onRouteModeChanged: _updateAudioRouteMode,
                  onSpeakerSelectionChanged: _toggleSpeakerSelection,
                  settings: Text(
                    activeAyah == null
                        ? 'Select a surah to enable remote playback.'
                        : 'Current selection: ${_detail?.surah?.englishName ?? 'Surah'} · Ayah ${activeAyah.numberInSurah} · ${_readerLabelFor(_reader)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  playButtonLabel: 'Broadcast current ayah',
                  mobilePlayButtonLabel: 'Play current ayah',
                ),
                const SizedBox(height: 16),
                _OfflineQuranAudioCard(
                  downloadedCount: _downloadedAyahAudioCount,
                  totalCount: ayahs.where((ayah) => ayah.audioUrl.isNotEmpty).length,
                  isBusy: _downloadBusy,
                  onDownload: _downloadCurrentSurahAudio,
                  onRemove: _downloadedAyahAudioCount > 0
                      ? _removeCurrentSurahAudio
                      : null,
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
              isPlaying: _speakerRouteMode == SpeakerRouteMode.mobileOnly
                  ? _audioController.isPlaying
                  : _audioRouting.hasRemotePlayback,
              audioLoading: _audioController.isLoading,
              onTogglePlayback: _toggleQuranPlayback,
              onStepBack: activeIndex > 0 ? _seekPreviousQuran : null,
              onStepForward:
                  activeIndex + 1 < ayahs.length ? _seekNextQuran : null,
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
                      : () => _playAyah(index),
                ),
              );
            }),
        ],
      ],
    );
  }

  Future<void> _persistAudioRouting() {
    return _preferences.saveAudioOutputRouting(
      scope: 'quran',
      mode: _speakerRouteMode,
      selectedDeviceIds: _selectedSpeakerIds,
    );
  }

  PrayerAudioOption? _optionForAyah(int index) {
    final surah = _detail?.surah;
    final ayahs = _detail?.ayahs;
    if (surah == null || ayahs == null || index < 0 || index >= ayahs.length) {
      return null;
    }
    final ayah = ayahs[index];
    if (ayah.audioUrl.isEmpty) {
      return null;
    }
    return PrayerAudioOption(
      id: 'quran:${surah.number}:${ayah.numberInSurah}:$_reader',
      category: 'Quran',
      label: '${surah.englishName} · Ayah ${ayah.numberInSurah}',
      description: 'Recorded Quran recitation by ${_readerLabelFor(_reader)}.',
      audioUrl: ayah.audioUrl,
      mediaType: 'mp3',
    );
  }

  Future<void> _playAyah(int index) async {
    if (_speakerRouteMode == SpeakerRouteMode.mobileOnly) {
      await _audioController.playFromIndex(index);
      return;
    }
    await _broadcastAyahAtIndex(index);
  }

  Future<void> _broadcastAyahAtIndex(int index) async {
    final option = _optionForAyah(index);
    if (option == null) {
      return;
    }
    await _persistAudioRouting();
    await _audioController.setExternalActiveIndex(index);
    await _audioRouting.broadcast(
      option: option,
      mode: _speakerRouteMode,
      selectedDeviceIds: _selectedSpeakerIds,
    );
  }

  Future<void> _toggleQuranPlayback() async {
    if (_speakerRouteMode == SpeakerRouteMode.mobileOnly) {
      await _audioController.togglePlayback();
      return;
    }
    if (_audioRouting.hasRemotePlayback) {
      await _audioRouting.stopAllPlayback();
      return;
    }
    await _broadcastAyahAtIndex(_audioController.activeIndex);
  }

  Future<void> _seekPreviousQuran() async {
    final targetIndex = _audioController.activeIndex - 1;
    if (targetIndex < 0) {
      return;
    }
    if (_speakerRouteMode == SpeakerRouteMode.mobileOnly) {
      await _audioController.seekPrevious();
      return;
    }
    await _broadcastAyahAtIndex(targetIndex);
  }

  Future<void> _seekNextQuran() async {
    final targetIndex = _audioController.activeIndex + 1;
    final ayahs = _detail?.ayahs ?? const <AyahRow>[];
    if (targetIndex >= ayahs.length) {
      return;
    }
    if (_speakerRouteMode == SpeakerRouteMode.mobileOnly) {
      await _audioController.seekNext();
      return;
    }
    await _broadcastAyahAtIndex(targetIndex);
  }

  Future<void> _updateAudioRouteMode(SpeakerRouteMode mode) async {
    setState(() => _speakerRouteMode = mode);
    if (mode != SpeakerRouteMode.mobileOnly && _audioController.isPlaying) {
      await _audioController.pause();
    }
    await _persistAudioRouting();
  }

  Future<void> _toggleSpeakerSelection(String deviceId, bool selected) async {
    setState(() {
      if (selected) {
        _selectedSpeakerIds = {..._selectedSpeakerIds, deviceId};
      } else {
        _selectedSpeakerIds = {..._selectedSpeakerIds}..remove(deviceId);
      }
    });
    await _persistAudioRouting();
  }

  Future<void> _stopAudioOutput() async {
    await _audioRouting.stopAllPlayback();
    await _audioController.pause();
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

class _OfflineQuranAudioCard extends StatelessWidget {
  const _OfflineQuranAudioCard({
    required this.downloadedCount,
    required this.totalCount,
    required this.isBusy,
    required this.onDownload,
    required this.onRemove,
  });

  final int downloadedCount;
  final int totalCount;
  final bool isBusy;
  final VoidCallback onDownload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final fullyDownloaded = totalCount > 0 && downloadedCount == totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullyDownloaded
              ? 'This surah audio is fully saved for offline playback.'
              : '$downloadedCount of $totalCount ayah audio files are saved for offline playback.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: isBusy || totalCount == 0 ? null : onDownload,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(isBusy ? 'Working…' : 'Download audio'),
            ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove offline'),
            ),
          ],
        ),
      ],
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
            Align(
              alignment: Alignment.centerRight,
              child: ArabicText(
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
            Align(
              alignment: Alignment.centerRight,
              child: ArabicText(
                ayah.arabicText,
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
              Align(
                alignment: Alignment.centerRight,
                child: ArabicText(
                  ayah!.arabicText,
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
