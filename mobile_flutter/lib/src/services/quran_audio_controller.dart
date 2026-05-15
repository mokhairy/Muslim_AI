import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/quran_models.dart';
import 'app_preferences_service.dart';
import 'offline_cache_service.dart';
import 'shared_audio_player.dart';

class QuranAudioController extends ChangeNotifier {
  QuranAudioController._();

  static final QuranAudioController instance = QuranAudioController._();

  final SharedAudioPlayer _sharedAudio = SharedAudioPlayer.instance;
  final AppPreferencesService _preferences = AppPreferencesService.instance;
  final OfflineCacheService _offlineCache = OfflineCacheService.instance;

  SurahSummary? _surah;
  List<AyahRow> _ayahs = const [];
  int _activeIndex = 0;
  String _readerId = '';
  String _readerLabel = '';
  String _translationId = '';
  String _mode = 'read_listen';
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _initialized = false;

  SurahSummary? get surah => _surah;
  List<AyahRow> get ayahs => _ayahs;
  int get activeIndex => _activeIndex;
  String get readerLabel => _readerLabel;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  bool get hasPlaylist => _surah != null && _ayahs.isNotEmpty;
  AyahRow? get currentAyah =>
      _ayahs.isEmpty || _activeIndex >= _ayahs.length ? null : _ayahs[_activeIndex];
  AudioPlayer get _player => _sharedAudio.player;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= _ayahs.length) {
        return;
      }
      _activeIndex = index;
      unawaited(_persistProgress());
      notifyListeners();
    });

    _player.playerStateStream.listen((state) {
      _isLoading =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      _isPlaying = state.playing;
      notifyListeners();
    });

    _initialized = true;
  }

  Future<void> setPlaylist({
    required SurahSummary surah,
    required List<AyahRow> ayahs,
    required String translationId,
    required String readerId,
    required String readerLabel,
    required String mode,
    int initialIndex = 0,
    bool autoplay = false,
  }) async {
    await initialize();
    await _sharedAudio.claim(SharedAudioOwner.quran);

    final safeIndex = ayahs.isEmpty
        ? 0
        : initialIndex.clamp(0, ayahs.length - 1);

    _surah = surah;
    _ayahs = ayahs;
    _translationId = translationId;
    _readerId = readerId;
    _readerLabel = readerLabel;
    _mode = mode;
    _activeIndex = safeIndex;
    _isLoading = true;
    notifyListeners();

    final sources = <AudioSource>[];
    for (final ayah in ayahs) {
      if (ayah.audioUrl.isEmpty) {
        continue;
      }

      final audioUri = await _offlineCache.resolvePlayableAudioUri(ayah.audioUrl);
      sources.add(
        AudioSource.uri(
          audioUri,
          tag: MediaItem(
            id: '${surah.number}:${ayah.numberInSurah}:$readerId',
            album: surah.englishName,
            title: 'Ayah ${ayah.numberInSurah}',
            artist: readerLabel,
          ),
        ),
      );
    }

    if (sources.isEmpty) {
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
      return;
    }

    await _player.setAudioSources(sources, initialIndex: safeIndex, preload: true);
    if (autoplay && mode != 'read') {
      await _player.play();
    } else {
      await _player.pause();
    }

    _isLoading = false;
    await _persistProgress();
    notifyListeners();
  }

  Future<void> updateMode(String mode) async {
    _mode = mode;
    await _persistProgress();
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    if (!hasPlaylist) {
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> playFromIndex(int index) async {
    if (!hasPlaylist || index < 0 || index >= _ayahs.length) {
      return;
    }

    _activeIndex = index;
    notifyListeners();
    await _player.seek(Duration.zero, index: index);
    await _player.play();
    await _persistProgress();
  }

  Future<void> setExternalActiveIndex(int index) async {
    if (!hasPlaylist || index < 0 || index >= _ayahs.length) {
      return;
    }

    _activeIndex = index;
    await _persistProgress();
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _sharedAudio.release(SharedAudioOwner.quran);
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> clearSessionForExternalPlayback() async {
    if (!hasPlaylist && _sharedAudio.owner != SharedAudioOwner.quran) {
      return;
    }

    if (_sharedAudio.owner == SharedAudioOwner.quran) {
      await _sharedAudio.release(SharedAudioOwner.quran);
    }

    _surah = null;
    _ayahs = const [];
    _activeIndex = 0;
    _readerId = '';
    _readerLabel = '';
    _translationId = '';
    _mode = 'read_listen';
    _isLoading = false;
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> seekPrevious() async {
    if (_activeIndex <= 0) {
      return;
    }
    await playFromIndex(_activeIndex - 1);
  }

  Future<void> seekNext() async {
    if (_activeIndex + 1 >= _ayahs.length) {
      return;
    }
    await playFromIndex(_activeIndex + 1);
  }

  Future<void> _persistProgress() async {
    if (_surah == null) {
      return;
    }

    await _preferences.saveQuranSession(
      surahNumber: _surah!.number,
      translationId: _translationId,
      readerId: _readerId,
      mode: _mode,
      activeAyahIndex: _activeIndex,
    );
  }

}
