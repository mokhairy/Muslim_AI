import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/library_models.dart';
import '../models/prayer_models.dart';
import '../screenshot_scene.dart';
import '../services/app_preferences_service.dart';
import '../services/library_service.dart';
import '../services/offline_cache_service.dart';
import '../services/prayer_audio_routing_service.dart';
import '../services/quran_audio_controller.dart';
import '../services/shared_audio_player.dart';
import '../widgets/arabic_text.dart';
import '../widgets/audio_output_routing_card.dart';

enum LibrarySection { hadith, adhkar, hisn }

enum AdhkarMode { read, listen, readListen }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _service = LibraryService();
  final _preferences = AppPreferencesService.instance;
  final _sharedAudio = SharedAudioPlayer.instance;
  final _quranAudioController = QuranAudioController.instance;
  final _offlineCache = OfflineCacheService.instance;
  final _audioRouting = AudioOutputRoutingService(owner: SharedAudioOwner.library);

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
  bool _downloadBusy = false;
  int _adhkarActiveEntryIndex = 0;
  int _downloadedAudioCount = 0;
  SpeakerRouteMode _speakerRouteMode = SpeakerRouteMode.mobileOnly;
  Set<String> _selectedSpeakerIds = <String>{};
  String _error = '';
  String _loadedAdhkarSignature = '';
  List<HadithItem> _hadithItems = const [];
  List<int> _adhkarTrackToEntryIndex = const [];
  AdhkarCategoryData? _adhkarData;
  HisnMuslimData? _hisnData;
  AdhkarAudioSource? _adhkarAudioSource;
  StreamSubscription<PlayerState>? _adhkarPlayerStateSubscription;
  StreamSubscription<int?>? _adhkarCurrentIndexSubscription;

  AudioPlayer get _adhkarPlayer => _sharedAudio.player;

  int get _downloadableAudioCount => _activeDownloadUrls.length;

  @override
  void initState() {
    super.initState();
    _audioRouting.addListener(_handleAudioRoutingChanged);
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
    _audioRouting.removeListener(_handleAudioRoutingChanged);
    _adhkarPlayerStateSubscription?.cancel();
    _adhkarCurrentIndexSubscription?.cancel();
    unawaited(_audioRouting.shutdown());
    unawaited(_sharedAudio.release(SharedAudioOwner.library));
    super.dispose();
  }

  void _handleAudioRoutingChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final savedRouting = await _preferences.loadAudioOutputRouting(
        scope: 'library',
        defaultMode: SpeakerRouteMode.mobileOnly,
      );
      _speakerRouteMode = savedRouting.mode;
      _selectedSpeakerIds = savedRouting.selectedDeviceIds;

      if (_section == LibrarySection.hadith) {
        await _sharedAudio.release(SharedAudioOwner.library);
        final hadith = await _service.fetchHadithPage();
        if (!mounted) {
          return;
        }
        setState(() {
          _hadithItems = hadith;
          _adhkarData = null;
          _hisnData = null;
          _adhkarAudioSource = null;
          _downloadedAudioCount = 0;
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
        await _refreshDownloadStatus();
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
      await _refreshDownloadStatus();
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

  List<String> get _activeDownloadUrls {
    final source = _activeAudioSource;
    if (source == null) {
      return const <String>[];
    }

    if (!source.supportsEntrySync) {
      final url = source.url;
      return url == null || url.isEmpty ? const <String>[] : [url];
    }

    final urls = <String>{
      for (final entry in _activeEntries)
        ...entry.audioUrls.where((url) => url.isNotEmpty),
    };
    return urls.toList(growable: false);
  }

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

    if (_sharedAudio.owner == SharedAudioOwner.library) {
      await _adhkarPlayer.stop();
    }
    _loadedAdhkarSignature = '';
    _adhkarTrackToEntryIndex = const [];
    _adhkarUsesEntrySync = false;
    _adhkarActiveEntryIndex = 0;
  }

  Future<void> _refreshDownloadStatus() async {
    final urls = _activeDownloadUrls;
    final downloadedCount = await _offlineCache.countDownloadedAudioUrls(urls);
    if (!mounted) {
      return;
    }
    setState(() => _downloadedAudioCount = downloadedCount);
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

    await _quranAudioController.clearSessionForExternalPlayback();
    await _sharedAudio.claim(SharedAudioOwner.library);

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
              await _offlineCache.resolvePlayableAudioUri(trackUrls[trackIndex]),
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
        await _offlineCache.resolvePlayableAudioUri(categoryUrl),
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

  Future<void> _downloadCurrentCollectionAudio() async {
    final urls = _activeDownloadUrls;
    if (urls.isEmpty) {
      return;
    }

    final wasPlaying = _adhkarPlayer.playing;
    setState(() => _downloadBusy = true);
    try {
      await _offlineCache.downloadAudioUrls(urls);
      await _resetAudioForCurrentContent(
        title: _activeCollectionTitle,
        entries: _activeEntries,
        source: _activeAudioSource,
      );
      await _refreshDownloadStatus();
      if (_adhkarMode != AdhkarMode.read) {
        await _ensureAdhkarAudioLoaded();
        if (wasPlaying) {
          await _adhkarPlayer.play();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _downloadBusy = false);
      }
    }
  }

  Future<void> _removeCurrentCollectionAudio() async {
    final urls = _activeDownloadUrls;
    if (urls.isEmpty) {
      return;
    }

    final wasPlaying = _adhkarPlayer.playing;
    setState(() => _downloadBusy = true);
    try {
      await _offlineCache.removeAudioUrls(urls);
      await _resetAudioForCurrentContent(
        title: _activeCollectionTitle,
        entries: _activeEntries,
        source: _activeAudioSource,
      );
      await _refreshDownloadStatus();
      if (_adhkarMode != AdhkarMode.read) {
        await _ensureAdhkarAudioLoaded();
        if (wasPlaying) {
          await _adhkarPlayer.play();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _downloadBusy = false);
      }
    }
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

    if (_speakerRouteMode != SpeakerRouteMode.mobileOnly) {
      if (_audioRouting.hasRemotePlayback) {
        await _audioRouting.stopAllPlayback();
        return;
      }
      await _broadcastLibrarySelection();
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
    if (_speakerRouteMode != SpeakerRouteMode.mobileOnly) {
      await _broadcastLibrarySelection(entryIndex: targetEntryIndex);
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
    if (_speakerRouteMode != SpeakerRouteMode.mobileOnly) {
      await _broadcastLibrarySelection(entryIndex: targetEntryIndex);
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
    if (_speakerRouteMode != SpeakerRouteMode.mobileOnly) {
      await _broadcastLibrarySelection(entryIndex: entryIndex);
      return;
    }
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

    if (mode != AdhkarMode.read && _speakerRouteMode != SpeakerRouteMode.mobileOnly) {
      await _broadcastLibrarySelection();
      return;
    }

    await _ensureAdhkarAudioLoaded();
    await _adhkarPlayer.play();
  }

  Future<void> _persistAudioRouting() {
    return _preferences.saveAudioOutputRouting(
      scope: 'library',
      mode: _speakerRouteMode,
      selectedDeviceIds: _selectedSpeakerIds,
    );
  }

  PrayerAudioOption? _libraryAudioOption({int? entryIndex}) {
    final source = _activeAudioSource;
    if (source == null) {
      return null;
    }

    if (!source.supportsEntrySync) {
      final url = source.url;
      if (url == null || url.isEmpty) {
        return null;
      }
      return PrayerAudioOption(
        id: 'library:${_section.name}:$_activeCollectionTitle',
        category: _section == LibrarySection.hisn ? 'Hisn Muslim' : 'Adhkar',
        label: source.label,
        description: source.voiceDescription,
        audioUrl: url,
        mediaType: 'mp3',
      );
    }

    final entries = _activeEntries;
    final safeIndex = entryIndex ?? _adhkarActiveEntryIndex;
    if (safeIndex < 0 || safeIndex >= entries.length) {
      return null;
    }
    final entry = entries[safeIndex];
    String? url;
    for (final item in entry.audioUrls) {
      if (item.isNotEmpty) {
        url = item;
        break;
      }
    }
    if (url == null) return null;
    return PrayerAudioOption(
      id: 'library:${_section.name}:${safeIndex + 1}',
      category: _section == LibrarySection.hisn ? 'Hisn Muslim' : 'Adhkar',
      label: entry.title,
      description: source.voiceDescription,
      audioUrl: url,
      mediaType: 'mp3',
    );
  }

  Future<void> _broadcastLibrarySelection({int? entryIndex}) async {
    final option = _libraryAudioOption(entryIndex: entryIndex);
    if (option == null) {
      return;
    }
    if (entryIndex != null) {
      setState(() => _adhkarActiveEntryIndex = entryIndex);
    }
    await _persistAudioRouting();
    await _adhkarPlayer.pause();
    await _audioRouting.broadcast(
      option: option,
      mode: _speakerRouteMode,
      selectedDeviceIds: _selectedSpeakerIds,
    );
  }

  Future<void> _playCurrentLibrarySelection() async {
    if (_speakerRouteMode != SpeakerRouteMode.mobileOnly) {
      await _broadcastLibrarySelection();
      return;
    }
    if (_activeAudioSource == null) {
      return;
    }
    await _ensureAdhkarAudioLoaded();
    if (_adhkarUsesEntrySync) {
      await _playAdhkarEntry(_adhkarActiveEntryIndex);
      return;
    }
    await _adhkarPlayer.play();
  }

  Future<void> _updateAudioRouteMode(SpeakerRouteMode mode) async {
    setState(() => _speakerRouteMode = mode);
    if (mode != SpeakerRouteMode.mobileOnly && _adhkarPlayer.playing) {
      await _adhkarPlayer.pause();
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

  Future<void> _stopLibraryAudioOutput() async {
    await _audioRouting.stopAllPlayback();
    await _adhkarPlayer.pause();
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
              if (_adhkarAudioSource != null) ...[
                AudioOutputRoutingCard(
                  title: 'Speaker Output',
                  description:
                      'Save an Adhkar-specific output preset. Keep playback on this phone, or broadcast the current category or active dhikr to selected LAN speakers.',
                  routeMode: _speakerRouteMode,
                  selectedSpeakerIds: _selectedSpeakerIds,
                  discoveredDevices: _audioRouting.devices,
                  isDiscovering: _audioRouting.isDiscovering,
                  isBusy: _audioRouting.isBusy,
                  statusMessage: _audioRouting.statusMessage,
                  errorMessage: _audioRouting.errorMessage,
                  isPhonePlaybackActive:
                      _adhkarAudioPlaying || _audioRouting.isPhonePlaybackActive,
                  hasRemotePlayback: _audioRouting.hasRemotePlayback,
                  onScanPressed: _audioRouting.isDiscovering
                      ? _audioRouting.stopDiscovery
                      : _audioRouting.startDiscovery,
                  onPlayPressed: _playCurrentLibrarySelection,
                  onStopPressed: _stopLibraryAudioOutput,
                  onRouteModeChanged: _updateAudioRouteMode,
                  onSpeakerSelectionChanged: _toggleSpeakerSelection,
                  settings: Text(
                    _adhkarUsesEntrySync && currentAdhkarEntry != null
                        ? 'Current selection: ${currentAdhkarEntry.title}'
                        : 'Current selection: ${_adhkarAudioSource!.label}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  playButtonLabel: 'Broadcast current adhkar',
                  mobilePlayButtonLabel: 'Play current adhkar',
                ),
                const SizedBox(height: 12),
              ],
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
              if (_adhkarAudioSource != null) ...[
                if (_adhkarMode != AdhkarMode.read) const SizedBox(height: 12),
                _OfflineAudioCard(
                  downloadedCount: _downloadedAudioCount,
                  totalCount: _downloadableAudioCount,
                  isBusy: _downloadBusy,
                  onDownload: _downloadCurrentCollectionAudio,
                  onRemove: _downloadedAudioCount > 0
                      ? _removeCurrentCollectionAudio
                      : null,
                ),
              ],
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
              if (_activeAudioSource != null) ...[
                AudioOutputRoutingCard(
                  title: 'Speaker Output',
                  description:
                      'Save a Hisn Muslim output preset. Keep playback on this phone, or broadcast the current entry to selected LAN speakers.',
                  routeMode: _speakerRouteMode,
                  selectedSpeakerIds: _selectedSpeakerIds,
                  discoveredDevices: _audioRouting.devices,
                  isDiscovering: _audioRouting.isDiscovering,
                  isBusy: _audioRouting.isBusy,
                  statusMessage: _audioRouting.statusMessage,
                  errorMessage: _audioRouting.errorMessage,
                  isPhonePlaybackActive:
                      _adhkarAudioPlaying || _audioRouting.isPhonePlaybackActive,
                  hasRemotePlayback: _audioRouting.hasRemotePlayback,
                  onScanPressed: _audioRouting.isDiscovering
                      ? _audioRouting.stopDiscovery
                      : _audioRouting.startDiscovery,
                  onPlayPressed: _playCurrentLibrarySelection,
                  onStopPressed: _stopLibraryAudioOutput,
                  onRouteModeChanged: _updateAudioRouteMode,
                  onSpeakerSelectionChanged: _toggleSpeakerSelection,
                  settings: Text(
                    _adhkarUsesEntrySync && currentAdhkarEntry != null
                        ? 'Current selection: ${currentAdhkarEntry.title}'
                        : 'Current selection: ${_activeAudioSource!.label}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  playButtonLabel: 'Broadcast current entry',
                  mobilePlayButtonLabel: 'Play current entry',
                ),
                const SizedBox(height: 12),
              ],
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
              if (_activeAudioSource != null) ...[
                if (_adhkarMode != AdhkarMode.read) const SizedBox(height: 12),
                _OfflineAudioCard(
                  downloadedCount: _downloadedAudioCount,
                  totalCount: _downloadableAudioCount,
                  isBusy: _downloadBusy,
                  onDownload: _downloadCurrentCollectionAudio,
                  onRemove: _downloadedAudioCount > 0
                      ? _removeCurrentCollectionAudio
                      : null,
                ),
              ],
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

class _OfflineAudioCard extends StatelessWidget {
  const _OfflineAudioCard({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline audio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              totalCount == 0
                  ? 'No downloadable recording is attached to this collection yet.'
                  : fullyDownloaded
                  ? 'All $totalCount audio files for this collection are saved on the device.'
                  : '$downloadedCount of $totalCount audio files are saved on the device.',
            ),
            const SizedBox(height: 14),
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
