import '../models/quran_models.dart';
import 'http_json.dart';

const _quranApiBase = 'https://api.quran.com/api/v4';
const _quranAudioBase = 'https://verses.quran.com/';

class QuranService {
  static const translationOptions = [
    SelectionOption(value: '85', label: 'English · Abdel Haleem'),
    SelectionOption(value: '19', label: 'English · Pickthall'),
    SelectionOption(value: '22', label: 'English · Yusuf Ali'),
    SelectionOption(value: '31', label: 'French · Hamidullah'),
    SelectionOption(value: '234', label: 'Urdu · Jalandhry'),
  ];

  static const readerOptions = [
    SelectionOption(value: '7', label: 'Sheikh Alafasy'),
    SelectionOption(value: '2', label: 'Sheikh Abdul Samad'),
    SelectionOption(value: '3', label: 'Sheikh Sudais'),
    SelectionOption(value: '4', label: 'Sheikh Abu Bakr Al-Shatri'),
    SelectionOption(value: '6', label: 'Sheikh Husary'),
  ];

  Future<List<SurahSummary>> fetchSurahList() async {
    final payload =
        await fetchJson('$_quranApiBase/chapters?language=en')
            as Map<String, dynamic>;
    final chapters = (payload['chapters'] as List<dynamic>? ?? const []);

    return chapters
        .map(
          (item) => SurahSummary(
            number: item['id'] as int,
            name: item['name_arabic']?.toString() ?? '',
            englishName: item['name_simple']?.toString() ?? '',
            englishNameTranslation:
                item['translated_name']?['name']?.toString() ?? '',
            numberOfAyahs: item['verses_count'] as int,
            revelationType: item['revelation_place']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<SurahDetail> fetchSurahDetail({
    required int surahNumber,
    required String translationId,
    required String readerId,
  }) async {
    final results = await Future.wait([
      fetchJson('$_quranApiBase/chapters/$surahNumber?language=en'),
      fetchJson(
        '$_quranApiBase/quran/verses/uthmani?chapter_number=$surahNumber',
      ),
      _fetchAllPages(
        (page) =>
            '$_quranApiBase/verses/by_chapter/$surahNumber?language=en&words=false&translations=$translationId&per_page=50&page=$page',
        'verses',
      ),
      _fetchAllPages(
        (page) =>
            '$_quranApiBase/recitations/$readerId/by_chapter/$surahNumber?per_page=50&page=$page',
        'audio_files',
      ),
    ]);

    final chapterPayload = results[0] as Map<String, dynamic>;
    final arabicPayload = results[1] as Map<String, dynamic>;
    final translationRows = results[2] as List<dynamic>;
    final audioRows = results[3] as List<dynamic>;

    final chapter = chapterPayload['chapter'] as Map<String, dynamic>?;
    final arabicVerses = arabicPayload['verses'] as List<dynamic>? ?? const [];
    final translationByKey = {
      for (final item in translationRows)
        if (item is Map<String, dynamic> && item['verse_key'] != null)
          item['verse_key'].toString(): item,
    };
    final audioByKey = {
      for (final item in audioRows)
        if (item is Map<String, dynamic> && item['verse_key'] != null)
          item['verse_key'].toString(): item,
    };

    final ayahs = arabicVerses.map((item) {
      final verse = item as Map<String, dynamic>;
      final verseKey = verse['verse_key'].toString();
      final translation =
          translationByKey[verseKey] ?? const <String, dynamic>{};
      final audio = audioByKey[verseKey] ?? const <String, dynamic>{};
      final verseNo = int.tryParse(verseKey.split(':').last) ?? 1;

      return AyahRow(
        verseKey: verseKey,
        numberInSurah: verseNo,
        arabicText: verse['text_uthmani']?.toString().trim() ?? '',
        translationText: _sanitizeTranslation(
          translation['translations']?[0]?['text'],
        ),
        audioUrl: _absoluteAudioUrl(audio['url']),
      );
    }).toList();

    return SurahDetail(
      surah: chapter == null
          ? null
          : SurahSummary(
              number: chapter['id'] as int,
              name: chapter['name_arabic']?.toString() ?? '',
              englishName: chapter['name_simple']?.toString() ?? '',
              englishNameTranslation:
                  chapter['translated_name']?['name']?.toString() ?? '',
              numberOfAyahs: chapter['verses_count'] as int,
              revelationType: chapter['revelation_place']?.toString() ?? '',
            ),
      ayahs: ayahs,
    );
  }

  Future<List<dynamic>> _fetchAllPages(
    String Function(int page) buildUrl,
    String key,
  ) async {
    final items = <dynamic>[];
    var page = 1;

    while (true) {
      final payload = await fetchJson(buildUrl(page)) as Map<String, dynamic>;
      items.addAll(payload[key] as List<dynamic>? ?? const []);
      final nextPage = payload['pagination']?['next_page'];
      if (nextPage == null) {
        break;
      }
      page = nextPage as int;
    }

    return items;
  }

  String _sanitizeTranslation(dynamic value) {
    return value
            ?.toString()
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&amp;', '&')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
  }

  String _absoluteAudioUrl(dynamic value) {
    final url = value?.toString().trim() ?? '';
    if (url.isEmpty) {
      return '';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '$_quranAudioBase${url.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
