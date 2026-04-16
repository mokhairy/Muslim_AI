import 'package:intl/intl.dart';

import '../models/prayer_models.dart';
import 'http_json.dart';

class PrayerService {
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
    final payload =
        await fetchJson('https://api.aladhan.com/v1/qibla/$latitude/$longitude')
            as Map<String, dynamic>;

    if (payload['code'] != 200) {
      throw Exception(payload['status']?.toString() ?? 'Qibla lookup failed');
    }

    return QiblaResponse(
      direction: (payload['data']['direction'] as num).toDouble(),
      latitude: latitude,
      longitude: longitude,
    );
  }
}
