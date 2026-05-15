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

enum SpeakerRouteMode { mobileOnly, selectedSpeakers, allDiscoveredSpeakers }

class PrayerAudioOption {
  const PrayerAudioOption({
    required this.id,
    required this.category,
    required this.label,
    required this.description,
    required this.audioUrl,
    required this.mediaType,
  });

  final String id;
  final String category;
  final String label;
  final String description;
  final String audioUrl;
  final String mediaType;
}

class SpeakerRouteSnapshot {
  const SpeakerRouteSnapshot({
    required this.mode,
    required this.audioOptionId,
    required this.selectedDeviceIds,
  });

  final SpeakerRouteMode mode;
  final String audioOptionId;
  final Set<String> selectedDeviceIds;
}

class SpeakerOutputRoutingSnapshot {
  const SpeakerOutputRoutingSnapshot({
    required this.mode,
    required this.selectedDeviceIds,
  });

  final SpeakerRouteMode mode;
  final Set<String> selectedDeviceIds;
}
