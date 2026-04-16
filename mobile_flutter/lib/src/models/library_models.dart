class HadithItem {
  const HadithItem({
    required this.number,
    required this.translation,
    required this.reference,
  });

  final String number;
  final String translation;
  final String reference;
}

class AdhkarEntry {
  const AdhkarEntry({
    required this.title,
    required this.text,
    required this.repeatCount,
  });

  final String title;
  final String text;
  final int repeatCount;
}

class AdhkarAudioSource {
  const AdhkarAudioSource({
    required this.url,
    required this.label,
    required this.supportsEntrySync,
  });

  final String url;
  final String label;
  final bool supportsEntrySync;
}

class AdhkarCategoryData {
  AdhkarCategoryData({
    required this.categories,
    required this.selectedCategory,
    required this.entries,
  });

  final List<String> categories;
  final String selectedCategory;
  final List<AdhkarEntry> entries;
}

class HisnMuslimData {
  HisnMuslimData({required this.categoryName, required this.entries});

  final String categoryName;
  final List<AdhkarEntry> entries;
}
