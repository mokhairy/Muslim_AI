import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/library_models.dart';
import 'adhkar_audio_catalog.dart';
import 'http_json.dart';

const _quranApiBase = 'https://api.quran.com/api/v4';
const _quranAudioBase = 'https://verses.quran.com/';

const Map<String, int> _arabicSurahNumberMap = {
  'البقرة': 2,
  'آل عمران': 3,
  'الأعراف': 7,
  'التوبة': 9,
  'يونس': 10,
  'هود': 11,
  'يوسف': 12,
  'إبراهيم': 14,
  'الإسراء': 17,
  'الكهف': 18,
  'طه': 20,
  'الأنبياء': 21,
  'المؤمنون': 23,
  'العنكبوت': 29,
  'الصافات': 37,
  'الممتحنة': 60,
  'نوح': 71,
};

class LibraryService {
  final Map<int, List<AdhkarEntry>> _hisnCategoryCache = {};
  final Map<int, Map<int, String>> _quranVerseAudioCache = {};

  Future<List<HadithItem>> fetchHadithPage({
    String collection = 'eng-bukhari',
    int page = 1,
    int limit = 12,
  }) async {
    final englishUrl =
        'https://raw.githubusercontent.com/fawazahmed0/hadith-api/1/editions/$collection/sections/1.min.json';
    final arabicUrl =
        'https://raw.githubusercontent.com/fawazahmed0/hadith-api/1/editions/ara-bukhari/sections/1.min.json';

    try {
      final englishPayload = await fetchJson(englishUrl) as Map<String, dynamic>;
      final arabicPayload = await fetchJson(arabicUrl) as Map<String, dynamic>;
      final englishRows =
          englishPayload['hadiths'] as List<dynamic>? ?? const [];
      final arabicRows = arabicPayload['hadiths'] as List<dynamic>? ?? const [];
      final start = (page - 1) * limit;
      return List.generate(limit, (index) => start + index)
          .where((index) => index < englishRows.length)
          .map((index) {
        final row = englishRows[index] as Map<String, dynamic>;
        final arabicRow = index < arabicRows.length
            ? arabicRows[index] as Map<String, dynamic>
            : const <String, dynamic>{};
        final reference = row['reference'] as Map<String, dynamic>? ?? const {};
        final book = reference['book']?.toString() ?? '';
        final hadith = reference['hadith']?.toString() ?? '';

        return HadithItem(
          number:
              row['hadithnumber']?.toString() ??
              row['arabicnumber']?.toString() ??
              '',
          arabicText: arabicRow['text']?.toString() ?? '',
          translation: row['text']?.toString() ?? '',
          reference: [
            if (book.isNotEmpty) 'Book $book',
            if (hadith.isNotEmpty) 'Hadith $hadith',
          ].join(' • '),
        );
      }).toList();
    } catch (_) {
      return const [
        HadithItem(
          number: '1',
          arabicText:
              'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى.',
          translation:
              'Narrated Umar ibn Al-Khattab: deeds are judged by intentions, and every person will have only what they intended.',
          reference: 'Sahih al-Bukhari',
        ),
      ];
    }
  }

  Future<AdhkarCategoryData> fetchAzkarCategory([
    String? selectedCategory,
  ]) async {
    final payload =
        await _loadAssetJson('assets/data/azkar.snapshot.json')
            as Map<String, dynamic>;
    final categories = payload.keys.toList(growable: false);
    final activeCategory =
        selectedCategory != null && payload.containsKey(selectedCategory)
        ? selectedCategory
        : categories.first;
    final localEntries = _flattenEntries(payload[activeCategory]).toList();
    final audioSource = AdhkarAudioCatalog.categoryAudio[activeCategory];
    List<AdhkarEntry> entries = localEntries;

    final hisnCategoryId = AdhkarAudioCatalog.hisnMuslimCategoryIds[activeCategory];
    if (hisnCategoryId != null) {
      try {
        entries = await _fetchHisnMuslimCategoryEntries(
          categoryId: hisnCategoryId,
          fallbackTitle: activeCategory,
        );
      } catch (_) {
        entries = localEntries;
      }
    } else if (activeCategory == 'أدعية قرآنية' || activeCategory == 'أدعية الأنبياء') {
      entries = await _attachQuranRecitationAudio(localEntries);
    }

    return AdhkarCategoryData(
      categories: categories,
      selectedCategory: activeCategory,
      entries: entries,
      audioSource: audioSource,
    );
  }

  Future<HisnMuslimData> fetchHisnMuslimCollection() async {
    try {
      final entries = await _fetchHisnMuslimCategoryEntries(
        categoryId: AdhkarAudioCatalog.hisnCollectionCategoryId,
        fallbackTitle: 'أذكار الصباح والمساء',
      );
      return HisnMuslimData(
        categoryName: 'أذكار الصباح والمساء',
        entries: entries,
        audioSource: const AdhkarAudioSource(
          label: 'Hisn al-Muslim recorded collection',
          supportsEntrySync: true,
          voiceDescription: 'حصن المسلم بصوت عربي مسجل',
        ),
      );
    } catch (_) {
      final payload =
          await _loadAssetJson('assets/data/hisn-muslim-27.snapshot.json')
              as Map<String, dynamic>;
      final first = payload.entries.first;
      return HisnMuslimData(
        categoryName: first.key,
        entries: _flattenEntries(first.value).toList(),
      );
    }
  }

  Future<dynamic> _loadAssetJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw);
  }

  Future<List<AdhkarEntry>> _fetchHisnMuslimCategoryEntries({
    required int categoryId,
    required String fallbackTitle,
  }) async {
    final cached = _hisnCategoryCache[categoryId];
    if (cached != null) {
      return cached;
    }

    final payload =
        await fetchJson('https://www.hisnmuslim.com/api/ar/$categoryId.json')
            as Map<String, dynamic>;
    final title = payload.isEmpty ? fallbackTitle : payload.keys.first;
    final rows = payload.isEmpty
        ? const <dynamic>[]
        : payload.values.first as List<dynamic>? ?? const <dynamic>[];
    final entries = rows.map((item) {
      final row = item as Map<String, dynamic>;
      return AdhkarEntry(
        title: title,
        text: _sanitizeSnapshotText(row['ARABIC_TEXT']?.toString() ?? ''),
        repeatCount: int.tryParse(row['REPEAT']?.toString() ?? '1') ?? 1,
        reference: '',
        audioUrls: [
          if ((row['AUDIO']?.toString().trim() ?? '').isNotEmpty)
            _normalizeAudioUrl(row['AUDIO']!.toString()),
        ],
      );
    }).toList(growable: false);

    _hisnCategoryCache[categoryId] = entries;
    return entries;
  }

  Future<List<AdhkarEntry>> _attachQuranRecitationAudio(
    List<AdhkarEntry> entries,
  ) async {
    final parsedReferences = entries
        .map(_parseQuranReference)
        .toList(growable: false);
    final chapters = {
      for (final reference in parsedReferences)
        if (reference != null) reference.chapterNumber,
    };

    for (final chapterNumber in chapters) {
      if (_quranVerseAudioCache.containsKey(chapterNumber)) {
        continue;
      }
      _quranVerseAudioCache[chapterNumber] = await _fetchQuranChapterAudio(
        chapterNumber: chapterNumber,
        readerId: AdhkarAudioCatalog.quranRecitationReaderId,
      );
    }

    return [
      for (var index = 0; index < entries.length; index++)
        AdhkarEntry(
          title: entries[index].title,
          text: entries[index].text,
          repeatCount: entries[index].repeatCount,
          reference: entries[index].reference,
          audioUrls: _resolveQuranAudioUrls(parsedReferences[index]),
        ),
    ];
  }

  Future<Map<int, String>> _fetchQuranChapterAudio({
    required int chapterNumber,
    required String readerId,
  }) async {
    final verseAudio = <int, String>{};
    var page = 1;

    while (true) {
      final payload =
          await fetchJson(
                '$_quranApiBase/recitations/$readerId/by_chapter/$chapterNumber?per_page=50&page=$page',
              )
              as Map<String, dynamic>;
      final rows = payload['audio_files'] as List<dynamic>? ?? const [];
      for (final item in rows) {
        final row = item as Map<String, dynamic>;
        final verseKey = row['verse_key']?.toString() ?? '';
        final verseNumber = int.tryParse(verseKey.split(':').last) ?? -1;
        final url = _absoluteQuranAudioUrl(row['url']);
        if (verseNumber > 0 && url.isNotEmpty) {
          verseAudio[verseNumber] = url;
        }
      }

      final nextPage = payload['pagination']?['next_page'];
      if (nextPage == null) {
        break;
      }
      page = nextPage as int;
    }

    return verseAudio;
  }

  List<String> _resolveQuranAudioUrls(_QuranReferenceRange? reference) {
    if (reference == null) {
      return const [];
    }

    final chapterAudio = _quranVerseAudioCache[reference.chapterNumber];
    if (chapterAudio == null || chapterAudio.isEmpty) {
      return const [];
    }

    final urls = <String>[];
    for (var verse = reference.startVerse; verse <= reference.endVerse; verse++) {
      final url = chapterAudio[verse];
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  _QuranReferenceRange? _parseQuranReference(AdhkarEntry entry) {
    final match = RegExp(
      r'\[([^\]-]+)\s*-\s*(\d+)(?:\s*-\s*(\d+))?\]',
    ).firstMatch(entry.reference.replaceAll('\u00A0', ' '));
    if (match == null) {
      return null;
    }

    final normalizedName = _normalizeSurahName(match.group(1) ?? '');
    final chapterNumber = _arabicSurahNumberMap[normalizedName];
    final startVerse = int.tryParse(match.group(2) ?? '');
    final endVerse = int.tryParse(match.group(3) ?? '') ?? startVerse;
    if (chapterNumber == null || startVerse == null || endVerse == null) {
      return null;
    }

    return _QuranReferenceRange(
      chapterNumber: chapterNumber,
      startVerse: startVerse,
      endVerse: endVerse,
    );
  }

  Iterable<AdhkarEntry> _flattenEntries(dynamic node) sync* {
    if (node is Map<String, dynamic> && node.containsKey('content')) {
      yield AdhkarEntry(
        title: node['category']?.toString() ?? 'Remembrance',
        text: _sanitizeSnapshotText(
          node['content']?.toString() ?? node['zekr']?.toString() ?? '',
        ),
        repeatCount: int.tryParse(node['count']?.toString() ?? '1') ?? 1,
        reference: _sanitizeSnapshotReference(node['reference']?.toString() ?? ''),
        audioUrls: const [],
      );
      return;
    }

    if (node is Map<String, dynamic> && node.containsKey('zekr')) {
      yield AdhkarEntry(
        title: node['category']?.toString() ?? 'Remembrance',
        text: _sanitizeSnapshotText(node['zekr']?.toString() ?? ''),
        repeatCount: int.tryParse(node['count']?.toString() ?? '1') ?? 1,
        reference: _sanitizeSnapshotReference(node['reference']?.toString() ?? ''),
        audioUrls: const [],
      );
      return;
    }

    if (node is List<dynamic>) {
      for (final item in node) {
        yield* _flattenEntries(item);
      }
    }
  }

  String _sanitizeSnapshotText(String raw) {
    return raw
        .replaceAll(r"\n', '", ' ')
        .replaceAll(r"', '", ' ')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'''^[\s,'"]+'''), '')
        .replaceAll(RegExp(r'''[\s,'"]+$'''), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _sanitizeSnapshotReference(String raw) {
    return raw
        .replaceAll(r'\n', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeAudioUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('http://')) {
      return 'https://${trimmed.substring('http://'.length)}';
    }
    return trimmed;
  }

  String _absoluteQuranAudioUrl(dynamic value) {
    final url = value?.toString().trim() ?? '';
    if (url.isEmpty) {
      return '';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '$_quranAudioBase${url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  String _normalizeSurahName(String value) {
    return value
        .replaceAll(r"\n', '", ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll('إبرهيم', 'إبراهيم')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _QuranReferenceRange {
  const _QuranReferenceRange({
    required this.chapterNumber,
    required this.startVerse,
    required this.endVerse,
  });

  final int chapterNumber;
  final int startVerse;
  final int endVerse;
}
