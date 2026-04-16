import 'package:flutter/widgets.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.mobile_flutter.quran_audio',
    androidNotificationChannelName: 'Quran Playback',
    androidNotificationOngoing: true,
  );
  runApp(const MuslimAiApp());
}
