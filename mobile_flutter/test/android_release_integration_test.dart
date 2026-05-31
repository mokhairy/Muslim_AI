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
      reason:
          'Release Android builds need network access for Quran, audio, and prayer APIs.',
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
      reason:
          'Library playback must not create a second background player instance.',
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

  test(
    'android release manifest includes local speaker discovery permissions',
    () {
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
        reason:
            'Speaker discovery should confirm network reachability in release builds.',
      );
    },
  );

  test('ios release plist includes feature parity permissions', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(
      plist.contains('NSLocationWhenInUseUsageDescription'),
      isTrue,
      reason: 'iOS needs location access for prayer times and qibla.',
    );
    expect(
      plist.contains('NSLocalNetworkUsageDescription'),
      isTrue,
      reason: 'iOS needs local network disclosure for smart speaker discovery.',
    );
    expect(
      plist.contains('_googlecast._tcp'),
      isTrue,
      reason:
          'Chromecast discovery on iOS must be declared as a Bonjour service.',
    );
    expect(
      plist.contains('_airplay._tcp'),
      isTrue,
      reason: 'AirPlay discovery on iOS must be declared as a Bonjour service.',
    );
    expect(
      plist.contains('_raop._tcp'),
      isTrue,
      reason:
          'AirPlay audio receivers commonly advertise RAOP and must be discoverable.',
    );
    expect(
      plist.contains('<string>audio</string>'),
      isTrue,
      reason:
          'iOS must keep background audio enabled for Quran and library playback.',
    );
    expect(
      project.contains('TARGETED_DEVICE_FAMILY = "1,2";'),
      isTrue,
      reason:
          'The Flutter app should continue shipping as one iPhone and iPad app.',
    );
  });

  test(
    'prayer audio router exposes real mp3 sources for phone or speaker playback',
    () {
      final options = PrayerAudioRoutingService.audioOptions;

      expect(options, isNotEmpty);
      expect(
        options.any(
          (item) => item.category == 'Quran' && item.audioUrl.endsWith('.mp3'),
        ),
        isTrue,
        reason:
            'Prayer tab speaker routing should include at least one real Quran mp3 source.',
      );
      expect(
        options.any(
          (item) =>
              item.category == 'Prayer Call' && item.audioUrl.endsWith('.mp3'),
        ),
        isTrue,
        reason:
            'Prayer tab speaker routing should include real Arabic adhan mp3 sources.',
      );
      expect(
        options.any(
          (item) => item.category == 'Adhkar' && item.audioUrl.endsWith('.mp3'),
        ),
        isTrue,
        reason:
            'Prayer tab speaker routing should include real Arabic adhkar mp3 sources.',
      );
    },
  );

  test('speaker routing scans and connects every supported cast protocol', () {
    final router = File(
      'lib/src/services/prayer_audio_routing_service.dart',
    ).readAsStringSync();

    expect(
      router.contains('ChromecastDiscoveryProvider()'),
      isTrue,
      reason:
          'Chromecast discovery should be available on both mobile platforms.',
    );
    expect(
      router.contains('AirPlayDiscoveryProvider()'),
      isTrue,
      reason:
          'iOS parity requires AirPlay discovery for local Apple speakers and TVs.',
    );
    expect(
      router.contains('DlnaDiscoveryProvider()'),
      isTrue,
      reason:
          'DLNA discovery should stay available for common LAN speakers and TVs.',
    );
    expect(router.contains('CastProtocol.airplay'), isTrue);
    expect(router.contains('AirPlaySession(device)'), isTrue);
  });
}
