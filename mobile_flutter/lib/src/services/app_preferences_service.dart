import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_models.dart';

class PrayerLocationSnapshot {
  const PrayerLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.fromDevice,
  });

  final double latitude;
  final double longitude;
  final bool fromDevice;
}

class QuranSessionSnapshot {
  const QuranSessionSnapshot({
    required this.surahNumber,
    required this.translationId,
    required this.readerId,
    required this.mode,
    required this.activeAyahIndex,
    required this.bookmarkedVerses,
  });

  final int surahNumber;
  final String translationId;
  final String readerId;
  final String mode;
  final int activeAyahIndex;
  final Set<String> bookmarkedVerses;
}

class AppPreferencesService {
  AppPreferencesService._();

  static final AppPreferencesService instance = AppPreferencesService._();
  static Future<SharedPreferences>? _prefsFuture;

  static const _prayerLatitudeKey = 'prayer.latitude';
  static const _prayerLongitudeKey = 'prayer.longitude';
  static const _prayerFromDeviceKey = 'prayer.from_device';
  static const _speakerRouteModeKey = 'prayer.speaker_route_mode';
  static const _speakerAudioOptionKey = 'prayer.speaker_audio_option';
  static const _speakerDeviceIdsKey = 'prayer.speaker_device_ids';

  static const _quranSurahKey = 'quran.surah';
  static const _quranTranslationKey = 'quran.translation';
  static const _quranReaderKey = 'quran.reader';
  static const _quranModeKey = 'quran.mode';
  static const _quranAyahIndexKey = 'quran.ayah_index';
  static const _quranBookmarksKey = 'quran.bookmarks';

  Future<SharedPreferences> _prefs() {
    _prefsFuture ??= SharedPreferences.getInstance();
    return _prefsFuture!;
  }

  Future<void> savePrayerLocation({
    required double latitude,
    required double longitude,
    required bool fromDevice,
  }) async {
    final prefs = await _prefs();
    await prefs.setDouble(_prayerLatitudeKey, latitude);
    await prefs.setDouble(_prayerLongitudeKey, longitude);
    await prefs.setBool(_prayerFromDeviceKey, fromDevice);
  }

  Future<PrayerLocationSnapshot?> loadPrayerLocation() async {
    final prefs = await _prefs();
    final latitude = prefs.getDouble(_prayerLatitudeKey);
    final longitude = prefs.getDouble(_prayerLongitudeKey);
    if (latitude == null || longitude == null) {
      return null;
    }

    return PrayerLocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      fromDevice: prefs.getBool(_prayerFromDeviceKey) ?? false,
    );
  }

  Future<void> saveSpeakerRouting({
    required SpeakerRouteMode mode,
    required String audioOptionId,
    required Set<String> selectedDeviceIds,
  }) async {
    final prefs = await _prefs();
    await prefs.setString(_speakerRouteModeKey, mode.name);
    await prefs.setString(_speakerAudioOptionKey, audioOptionId);
    await prefs.setStringList(
      _speakerDeviceIdsKey,
      selectedDeviceIds.toList(growable: false),
    );
  }

  Future<SpeakerRouteSnapshot> loadSpeakerRouting({
    required SpeakerRouteMode defaultMode,
    required String defaultAudioOptionId,
  }) async {
    final prefs = await _prefs();
    final modeName = prefs.getString(_speakerRouteModeKey);
    SpeakerRouteMode? mode;
    for (final item in SpeakerRouteMode.values) {
      if (item.name == modeName) {
        mode = item;
        break;
      }
    }
    return SpeakerRouteSnapshot(
      mode: mode ?? defaultMode,
      audioOptionId:
          prefs.getString(_speakerAudioOptionKey) ?? defaultAudioOptionId,
      selectedDeviceIds:
          prefs.getStringList(_speakerDeviceIdsKey)?.toSet() ?? <String>{},
    );
  }

  Future<void> saveQuranSession({
    required int surahNumber,
    required String translationId,
    required String readerId,
    required String mode,
    required int activeAyahIndex,
  }) async {
    final prefs = await _prefs();
    await prefs.setInt(_quranSurahKey, surahNumber);
    await prefs.setString(_quranTranslationKey, translationId);
    await prefs.setString(_quranReaderKey, readerId);
    await prefs.setString(_quranModeKey, mode);
    await prefs.setInt(_quranAyahIndexKey, activeAyahIndex);
  }

  Future<QuranSessionSnapshot> loadQuranSession({
    required int defaultSurahNumber,
    required String defaultTranslationId,
    required String defaultReaderId,
    required String defaultMode,
  }) async {
    final prefs = await _prefs();
    return QuranSessionSnapshot(
      surahNumber: prefs.getInt(_quranSurahKey) ?? defaultSurahNumber,
      translationId:
          prefs.getString(_quranTranslationKey) ?? defaultTranslationId,
      readerId: prefs.getString(_quranReaderKey) ?? defaultReaderId,
      mode: prefs.getString(_quranModeKey) ?? defaultMode,
      activeAyahIndex: prefs.getInt(_quranAyahIndexKey) ?? 0,
      bookmarkedVerses:
          prefs.getStringList(_quranBookmarksKey)?.toSet() ?? <String>{},
    );
  }

  Future<Set<String>> toggleBookmarkedVerse(String verseKey) async {
    final prefs = await _prefs();
    final bookmarks =
        prefs.getStringList(_quranBookmarksKey)?.toSet() ?? <String>{};

    if (bookmarks.contains(verseKey)) {
      bookmarks.remove(verseKey);
    } else {
      bookmarks.add(verseKey);
    }

    await prefs.setStringList(
      _quranBookmarksKey,
      bookmarks.toList(growable: false),
    );
    return bookmarks;
  }
}
