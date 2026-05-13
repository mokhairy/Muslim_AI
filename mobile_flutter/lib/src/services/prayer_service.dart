import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../models/prayer_models.dart';
import 'http_json.dart';

class PrayerService {
  static const _kaabaLatitude = 21.4225;
  static const _kaabaLongitude = 39.8262;

  Future<PrayerTimesResponse> fetchPrayerTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) async {
    final formatted = DateFormat('dd-MM-yyyy').format(date);
    final query = Uri(
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'method': '4',
      },
    ).query;
    final payload =
        await fetchJson('https://api.aladhan.com/v1/timings/$formatted?$query')
            as Map<String, dynamic>;

    if (payload['code'] != 200) {
      throw Exception(
        payload['status']?.toString() ?? 'Prayer times lookup failed',
      );
    }

    final data = payload['data'] as Map<String, dynamic>;
    final timings = data['timings'] as Map<String, dynamic>;
    const order = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return PrayerTimesResponse(
      readableDate: data['date']['readable']?.toString() ?? '',
      hijriDate: data['date']['hijri']['date']?.toString() ?? '',
      timezone: data['meta']['timezone']?.toString() ?? '',
      calculationMethod: data['meta']['method']['name']?.toString() ?? '',
      timings: order
          .map(
            (name) => PrayerTiming(
              name: name,
              time: timings[name].toString().split(' ').first,
            ),
          )
          .toList(),
    );
  }

  Future<QiblaResponse> fetchQibla({
    required double latitude,
    required double longitude,
  }) async {
    return QiblaResponse(
      direction: _computeQiblaDirection(
        latitude: latitude,
        longitude: longitude,
      ),
      latitude: latitude,
      longitude: longitude,
    );
  }

  double _computeQiblaDirection({
    required double latitude,
    required double longitude,
  }) {
    final latRad = _toRadians(latitude);
    final deltaLonRad = _toRadians(_kaabaLongitude - longitude);
    final kaabaLatRad = _toRadians(_kaabaLatitude);

    final y = math.sin(deltaLonRad);
    final x =
        math.cos(latRad) * math.tan(kaabaLatRad) -
        math.sin(latRad) * math.cos(deltaLonRad);

    final bearing = _toDegrees(math.atan2(y, x));
    return (bearing + 360) % 360;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180.0;

  double _toDegrees(double radians) => radians * 180.0 / math.pi;
}
