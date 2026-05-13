import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
