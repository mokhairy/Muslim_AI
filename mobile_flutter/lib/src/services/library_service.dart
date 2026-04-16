import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/library_models.dart';
import 'http_json.dart';

class LibraryService {
  Future<List<HadithItem>> fetchHadithPage({
    String collection = 'eng-bukhari',
    int page = 1,
    int limit = 12,
  }) async {
    final url =
        'https://raw.githubusercontent.com/fawazahmed0/hadith-api/1/editions/$collection/sections/1.min.json';

    try {
      final payload = await fetchJson(url) as Map<String, dynamic>;
      final rows = payload['hadiths'] as List<dynamic>? ?? const [];
      final start = (page - 1) * limit;
      return rows.skip(start).take(limit).map((item) {
        final row = item as Map<String, dynamic>;
        final reference = row['reference'] as Map<String, dynamic>? ?? const {};
        final book = reference['book']?.toString() ?? '';
        final hadith = reference['hadith']?.toString() ?? '';

        return HadithItem(
          number:
              row['hadithnumber']?.toString() ??
              row['arabicnumber']?.toString() ??
              '',
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
    final entries = _flattenEntries(payload[activeCategory]).toList();

    return AdhkarCategoryData(
      categories: categories,
      selectedCategory: activeCategory,
      entries: entries,
    );
  }

  Future<HisnMuslimData> fetchHisnMuslimCollection() async {
    final payload =
        await _loadAssetJson('assets/data/hisn-muslim-27.snapshot.json')
            as Map<String, dynamic>;
    final first = payload.entries.first;
    return HisnMuslimData(
      categoryName: first.key,
      entries: _flattenEntries(first.value).toList(),
    );
  }

  Future<dynamic> _loadAssetJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw);
  }

  Iterable<AdhkarEntry> _flattenEntries(dynamic node) sync* {
    if (node is Map<String, dynamic> && node.containsKey('content')) {
      yield AdhkarEntry(
        title: node['category']?.toString() ?? 'Remembrance',
        text:
            node['content']?.toString().trim() ??
            node['zekr']?.toString().trim() ??
            '',
        repeatCount: int.tryParse(node['count']?.toString() ?? '1') ?? 1,
      );
      return;
    }

    if (node is Map<String, dynamic> && node.containsKey('zekr')) {
      yield AdhkarEntry(
        title: node['category']?.toString() ?? 'Remembrance',
        text: node['zekr']?.toString().trim() ?? '',
        repeatCount: int.tryParse(node['count']?.toString() ?? '1') ?? 1,
      );
      return;
    }

    if (node is List<dynamic>) {
      for (final item in node) {
        yield* _flattenEntries(item);
      }
    }
  }
}
