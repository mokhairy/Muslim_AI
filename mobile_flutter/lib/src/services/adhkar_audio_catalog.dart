import '../models/library_models.dart';

class AdhkarAudioCatalog {
  static const Map<String, AdhkarAudioSource> categoryAudio = {
    'أذكار الصباح': AdhkarAudioSource(
      url: 'https://www.rslan.org/chains/Wabel2/01_01.mp3',
      label: 'Recorded morning adhkar',
      supportsEntrySync: false,
    ),
    'أذكار المساء': AdhkarAudioSource(
      url: 'https://www.rslan.org/chains/Wabel2/02_01.mp3',
      label: 'Recorded evening adhkar',
      supportsEntrySync: false,
    ),
  };
}
