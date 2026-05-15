import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/src/services/prayer_audio_routing_service.dart';
import 'package:mobile_flutter/src/services/prayer_service.dart';

void main() {
  test('android release manifest includes internet permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest.contains('android.permission.INTERNET'),
      isTrue,
      reason: 'Release Android builds need network access for Quran, audio, and prayer APIs.',
    );
  });

  test('qibla direction is computed locally from coordinates', () async {
    final service = PrayerService();
    final qibla = await service.fetchQibla(
      latitude: 23.5880,
      longitude: 58.3829,
    );

    expect(qibla.direction, closeTo(266.44, 0.2));
  });

  test('library playback uses the shared app audio player', () {
    final libraryScreen = File(
      'lib/src/screens/library_screen.dart',
    ).readAsStringSync();
    final quranController = File(
      'lib/src/services/quran_audio_controller.dart',
    ).readAsStringSync();

    expect(
      libraryScreen.contains('final _adhkarPlayer = AudioPlayer();'),
      isFalse,
      reason: 'Library playback must not create a second background player instance.',
    );
    expect(
      libraryScreen.contains('SharedAudioPlayer.instance'),
      isTrue,
      reason: 'Library playback should reuse the app-wide shared player.',
    );
    expect(
      quranController.contains('SharedAudioPlayer.instance'),
      isTrue,
      reason: 'Quran playback should also use the shared player path.',
    );
  });

  test('android release manifest includes local speaker discovery permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest.contains('android.permission.ACCESS_WIFI_STATE'),
      isTrue,
      reason: 'Speaker discovery needs Wi-Fi state access on Android.',
    );
    expect(
      manifest.contains('android.permission.CHANGE_WIFI_MULTICAST_STATE'),
      isTrue,
      reason: 'Chromecast and DLNA discovery require multicast on Android.',
    );
    expect(
      manifest.contains('android.permission.ACCESS_NETWORK_STATE'),
      isTrue,
      reason: 'Speaker discovery should confirm network reachability in release builds.',
    );
  });

  test('prayer audio router exposes real mp3 sources for phone or speaker playback', () {
    final options = PrayerAudioRoutingService.audioOptions;

    expect(options, isNotEmpty);
    expect(
      options.any((item) => item.category == 'Quran' && item.audioUrl.endsWith('.mp3')),
      isTrue,
      reason: 'Prayer tab speaker routing should include at least one real Quran mp3 source.',
    );
    expect(
      options.any((item) => item.category == 'Prayer Call' && item.audioUrl.endsWith('.mp3')),
      isTrue,
      reason: 'Prayer tab speaker routing should include real Arabic adhan mp3 sources.',
    );
    expect(
      options.any((item) => item.category == 'Adhkar' && item.audioUrl.endsWith('.mp3')),
      isTrue,
      reason: 'Prayer tab speaker routing should include real Arabic adhkar mp3 sources.',
    );
  });
}
