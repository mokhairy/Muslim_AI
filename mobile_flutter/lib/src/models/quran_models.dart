class SurahSummary {
  SurahSummary({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;
}

class AyahRow {
  AyahRow({
    required this.verseKey,
    required this.numberInSurah,
    required this.arabicText,
    required this.translationText,
    required this.audioUrl,
  });

  final String verseKey;
  final int numberInSurah;
  final String arabicText;
  final String translationText;
  final String audioUrl;
}

class SurahDetail {
  SurahDetail({required this.surah, required this.ayahs});

  final SurahSummary? surah;
  final List<AyahRow> ayahs;
}

class SelectionOption {
  const SelectionOption({required this.value, required this.label});

  final String value;
  final String label;
}
