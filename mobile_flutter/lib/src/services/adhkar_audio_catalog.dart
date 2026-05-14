import '../models/library_models.dart';

class AdhkarAudioCatalog {
  static const quranRecitationReaderId = '7';

  static const Map<String, AdhkarAudioSource> categoryAudio = {
    'أذكار الصباح': AdhkarAudioSource(
      url: 'https://www.rslan.org/chains/Wabel2/01_01.mp3',
      label: 'Recorded morning adhkar',
      supportsEntrySync: false,
      voiceDescription: 'Native Arabic recitation',
    ),
    'أذكار المساء': AdhkarAudioSource(
      url: 'https://www.rslan.org/chains/Wabel2/02_01.mp3',
      label: 'Recorded evening adhkar',
      supportsEntrySync: false,
      voiceDescription: 'Native Arabic recitation',
    ),
    'أذكار بعد السلام من الصلاة المفروضة': AdhkarAudioSource(
      label: 'Hisn al-Muslim post-prayer adhkar',
      supportsEntrySync: true,
      voiceDescription: 'حصن المسلم بصوت عربي مسجل',
    ),
    'تسابيح': AdhkarAudioSource(
      label: 'Recorded tasbeeh collection',
      supportsEntrySync: true,
      voiceDescription: 'حصن المسلم بصوت عربي مسجل',
    ),
    'أذكار النوم': AdhkarAudioSource(
      label: 'Hisn al-Muslim sleep adhkar',
      supportsEntrySync: true,
      voiceDescription: 'حصن المسلم بصوت عربي مسجل',
    ),
    'أذكار الاستيقاظ': AdhkarAudioSource(
      label: 'Hisn al-Muslim waking adhkar',
      supportsEntrySync: true,
      voiceDescription: 'حصن المسلم بصوت عربي مسجل',
    ),
    'أدعية قرآنية': AdhkarAudioSource(
      label: 'Quran recitation for Quranic supplications',
      supportsEntrySync: true,
      voiceDescription: 'Sheikh Alafasy Quran recitation',
    ),
    'أدعية الأنبياء': AdhkarAudioSource(
      label: 'Quran recitation for supplications of the Prophets',
      supportsEntrySync: true,
      voiceDescription: 'Sheikh Alafasy Quran recitation',
    ),
  };

  static const Map<String, int> hisnMuslimCategoryIds = {
    'أذكار بعد السلام من الصلاة المفروضة': 25,
    'تسابيح': 130,
    'أذكار النوم': 28,
    'أذكار الاستيقاظ': 1,
  };
}
