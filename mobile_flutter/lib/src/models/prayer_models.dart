class PrayerTimesResponse {
  PrayerTimesResponse({
    required this.readableDate,
    required this.hijriDate,
    required this.timezone,
    required this.calculationMethod,
    required this.timings,
  });

  final String readableDate;
  final String hijriDate;
  final String timezone;
  final String calculationMethod;
  final List<PrayerTiming> timings;
}

class PrayerTiming {
  PrayerTiming({required this.name, required this.time});

  final String name;
  final String time;
}

class QiblaResponse {
  QiblaResponse({
    required this.direction,
    required this.latitude,
    required this.longitude,
  });

  final double direction;
  final double latitude;
  final double longitude;
}
