class HadithItem {
  const HadithItem({
    required this.number,
    required this.arabicText,
    required this.translation,
    required this.reference,
  });

  final String number;
  final String arabicText;
  final String translation;
  final String reference;
}

class AdhkarEntry {
  const AdhkarEntry({
    required this.title,
    required this.text,
    required this.repeatCount,
    required this.reference,
    required this.audioUrls,
  });

  final String title;
  final String text;
  final int repeatCount;
  final String reference;
  final List<String> audioUrls;
}

class AdhkarAudioSource {
  const AdhkarAudioSource({
    required this.label,
    required this.supportsEntrySync,
    this.url,
    this.voiceDescription = '',
  });

  final String label;
  final bool supportsEntrySync;
  final String? url;
  final String voiceDescription;
}

class AdhkarCategoryData {
  AdhkarCategoryData({
    required this.categories,
    required this.selectedCategory,
    required this.entries,
    this.audioSource,
  });

  final List<String> categories;
  final String selectedCategory;
  final List<AdhkarEntry> entries;
  final AdhkarAudioSource? audioSource;
}

class HisnMuslimData {
  HisnMuslimData({
    required this.categoryName,
    required this.entries,
    this.audioSource,
  });

  final String categoryName;
  final List<AdhkarEntry> entries;
  final AdhkarAudioSource? audioSource;
}
