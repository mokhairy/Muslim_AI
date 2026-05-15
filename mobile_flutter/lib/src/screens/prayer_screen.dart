import 'dart:async';
import 'dart:math' as math;

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/prayer_models.dart';
import '../services/app_preferences_service.dart';
import '../services/prayer_audio_routing_service.dart';
import '../services/prayer_service.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  final _service = PrayerService();
  final _preferences = AppPreferencesService.instance;
  final _audioRouting = PrayerAudioRoutingService();
  final _latitudeController = TextEditingController(text: '23.5880');
  final _longitudeController = TextEditingController(text: '58.3829');

  DateTime _selectedDate = DateTime.now();
  PrayerTimesResponse? _prayerTimes;
  QiblaResponse? _qibla;
  bool _loading = true;
  bool _locating = false;
  bool _locationFromDevice = false;
  double? _heading;
  SpeakerRouteMode _speakerRouteMode = SpeakerRouteMode.mobileOnly;
  late String _selectedAudioOptionId;
  Set<String> _selectedSpeakerIds = <String>{};
  StreamSubscription<CompassEvent>? _compassSubscription;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _selectedAudioOptionId = _audioRouting.defaultAudioOption.id;
    _audioRouting.addListener(_handleAudioRoutingChanged);
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (!mounted || event.heading == null) {
        return;
      }
      setState(() => _heading = event.heading);
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _audioRouting.removeListener(_handleAudioRoutingChanged);
    unawaited(_audioRouting.shutdown());
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final nextDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _selectedDate,
    );

    if (nextDate != null) {
      setState(() => _selectedDate = nextDate);
      await _load();
    }
  }

  Future<void> _bootstrap() async {
    final savedLocation = await _preferences.loadPrayerLocation();
    if (savedLocation != null) {
      _latitudeController.text = savedLocation.latitude.toStringAsFixed(4);
      _longitudeController.text = savedLocation.longitude.toStringAsFixed(4);
      _locationFromDevice = savedLocation.fromDevice;
    }
    final savedRouting = await _preferences.loadSpeakerRouting(
      defaultMode: SpeakerRouteMode.mobileOnly,
      defaultAudioOptionId: _audioRouting.defaultAudioOption.id,
    );
    _speakerRouteMode = savedRouting.mode;
    _selectedAudioOptionId =
        _audioRouting.optionById(savedRouting.audioOptionId)?.id ??
        _audioRouting.defaultAudioOption.id;
    _selectedSpeakerIds = savedRouting.selectedDeviceIds;
    await _load();
  }

  void _handleAudioRoutingChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _persistSpeakerRouting() {
    return _preferences.saveSpeakerRouting(
      mode: _speakerRouteMode,
      audioOptionId: _selectedAudioOptionId,
      selectedDeviceIds: _selectedSpeakerIds,
    );
  }

  PrayerAudioOption get _selectedAudioOption =>
      _audioRouting.optionById(_selectedAudioOptionId) ??
      _audioRouting.defaultAudioOption;

  Future<void> _load() async {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());

    if (latitude == null || longitude == null) {
      setState(() {
        _error = 'Enter valid latitude and longitude values.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final results = await Future.wait([
        _service.fetchPrayerTimes(
          date: _selectedDate,
          latitude: latitude,
          longitude: longitude,
        ),
        _service.fetchQibla(latitude: latitude, longitude: longitude),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _prayerTimes = results[0] as PrayerTimesResponse;
        _qibla = results[1] as QiblaResponse;
        _loading = false;
      });
      await _preferences.savePrayerLocation(
        latitude: latitude,
        longitude: longitude,
        fromDevice: _locationFromDevice,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = '';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on this device.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Open system settings and allow location access for MuslimAI.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _latitudeController.text = position.latitude.toStringAsFixed(4);
      _longitudeController.text = position.longitude.toStringAsFixed(4);
      _locationFromDevice = true;
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _playSelectedAudio() async {
    final option = _selectedAudioOption;
    await _persistSpeakerRouting();

    if (_speakerRouteMode == SpeakerRouteMode.mobileOnly) {
      await _audioRouting.playOnPhone(option);
      return;
    }

    await _audioRouting.broadcast(
      option: option,
      mode: _speakerRouteMode,
      selectedDeviceIds: _selectedSpeakerIds,
    );
  }

  Future<void> _toggleSpeakerSelection(String deviceId, bool selected) async {
    setState(() {
      if (selected) {
        _selectedSpeakerIds = {..._selectedSpeakerIds, deviceId};
      } else {
        _selectedSpeakerIds = {..._selectedSpeakerIds}..remove(deviceId);
      }
    });
    await _persistSpeakerRouting();
  }

  Future<void> _updateRouteMode(SpeakerRouteMode mode) async {
    setState(() => _speakerRouteMode = mode);
    await _persistSpeakerRouting();
  }

  Future<void> _updateAudioOption(String optionId) async {
    setState(() => _selectedAudioOptionId = optionId);
    await _persistSpeakerRouting();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Prayer Times', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'AlAdhan-backed prayer schedule with saved coordinates, a device-location shortcut, local qibla guidance, and local-network audio routing for Quran, adhan, and adhkar.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextField(
                  controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(DateFormat.yMMMMd().format(_selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location_outlined),
                    label: Text(
                      _locating
                          ? 'Locating…'
                          : _locationFromDevice
                          ? 'Refresh current location'
                          : 'Use current location',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _locationFromDevice
                        ? 'Using device coordinates'
                        : 'Using saved manual coordinates',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(_error),
            ),
          )
        else ...[
          if (_prayerTimes != null) _PrayerTimesCard(data: _prayerTimes!),
          const SizedBox(height: 12),
          if (_qibla != null) _QiblaCard(data: _qibla!, heading: _heading),
          const SizedBox(height: 12),
          _SpeakerRoutingCard(
            routeMode: _speakerRouteMode,
            selectedAudioOptionId: _selectedAudioOptionId,
            selectedSpeakerIds: _selectedSpeakerIds,
            audioOptions: PrayerAudioRoutingService.audioOptions,
            discoveredDevices: _audioRouting.devices,
            isDiscovering: _audioRouting.isDiscovering,
            isBusy: _audioRouting.isBusy,
            statusMessage: _audioRouting.statusMessage,
            errorMessage: _audioRouting.errorMessage,
            isPhonePlaybackActive: _audioRouting.isPhonePlaybackActive,
            hasRemotePlayback: _audioRouting.hasRemotePlayback,
            onScanPressed: _audioRouting.isDiscovering
                ? _audioRouting.stopDiscovery
                : _audioRouting.startDiscovery,
            onPlayPressed: _playSelectedAudio,
            onStopPressed: _audioRouting.stopAllPlayback,
            onRouteModeChanged: _updateRouteMode,
            onAudioOptionChanged: _updateAudioOption,
            onSpeakerSelectionChanged: _toggleSpeakerSelection,
          ),
        ],
      ],
    );
  }
}

class _PrayerTimesCard extends StatelessWidget {
  const _PrayerTimesCard({required this.data});

  final PrayerTimesResponse data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.readableDate, style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${data.hijriDate} • ${data.timezone}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(data.calculationMethod, style: textTheme.bodyMedium),
            const SizedBox(height: 18),
            for (final item in data.timings) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(item.name, style: textTheme.titleMedium),
                  ),
                  Text(item.time, style: textTheme.titleLarge),
                ],
              ),
              if (item != data.timings.last) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _QiblaCard extends StatelessWidget {
  const _QiblaCard({required this.data, required this.heading});

  final QiblaResponse data;
  final double? heading;

  double get _relativeAngle {
    if (heading == null) {
      return data.direction;
    }
    return (data.direction - heading! + 360) % 360;
  }

  bool get _isAligned {
    if (heading == null) {
      return false;
    }
    final delta = _relativeAngle > 180 ? 360 - _relativeAngle : _relativeAngle;
    return delta <= 10;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qibla', style: textTheme.titleLarge),
            const SizedBox(height: 10),
            Center(
              child: _QiblaDial(
                qiblaBearing: data.direction,
                heading: heading,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              heading == null
                  ? '${data.direction.toStringAsFixed(1)}° from north'
                  : 'Turn ${(heading! + _relativeAngle) % 360 >= 0 ? _relativeAngle.toStringAsFixed(1) : data.direction.toStringAsFixed(1)}° toward the Kaaba',
              style: textTheme.displaySmall?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 8),
            if (heading != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isAligned
                      ? scheme.primaryContainer
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isAligned
                      ? 'Aligned with qibla'
                      : 'Rotate until the gold marker points up',
                  style: textTheme.titleMedium,
                ),
              )
            else
              Text(
                'Compass heading is unavailable on this device, so the finder is showing the qibla bearing from north.',
                style: textTheme.bodyMedium,
              ),
            const SizedBox(height: 8),
            Text(
              'Coordinates ${data.latitude.toStringAsFixed(4)}, ${data.longitude.toStringAsFixed(4)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _QiblaDial extends StatelessWidget {
  const _QiblaDial({
    required this.qiblaBearing,
    required this.heading,
  });

  final double qiblaBearing;
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final relativeAngle = heading == null
        ? qiblaBearing
        : (qiblaBearing - heading! + 360) % 360;

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
            ),
          ),
          Positioned(top: 18, child: Text('N', style: Theme.of(context).textTheme.titleMedium)),
          Positioned(bottom: 18, child: Text('S', style: Theme.of(context).textTheme.titleMedium)),
          Positioned(left: 18, child: Text('W', style: Theme.of(context).textTheme.titleMedium)),
          Positioned(right: 18, child: Text('E', style: Theme.of(context).textTheme.titleMedium)),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Transform.rotate(
            angle: -math.pi * 2 * (heading ?? 0) / 360,
            child: Icon(
              Icons.navigation_rounded,
              size: 88,
              color: scheme.primary.withValues(alpha: 0.28),
            ),
          ),
          Transform.rotate(
            angle: math.pi * 2 * relativeAngle / 360,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_drop_up_rounded,
                  size: 92,
                  color: Color(0xFFC89545),
                ),
                SizedBox(height: 112),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakerRoutingCard extends StatelessWidget {
  const _SpeakerRoutingCard({
    required this.routeMode,
    required this.selectedAudioOptionId,
    required this.selectedSpeakerIds,
    required this.audioOptions,
    required this.discoveredDevices,
    required this.isDiscovering,
    required this.isBusy,
    required this.statusMessage,
    required this.errorMessage,
    required this.isPhonePlaybackActive,
    required this.hasRemotePlayback,
    required this.onScanPressed,
    required this.onPlayPressed,
    required this.onStopPressed,
    required this.onRouteModeChanged,
    required this.onAudioOptionChanged,
    required this.onSpeakerSelectionChanged,
  });

  final SpeakerRouteMode routeMode;
  final String selectedAudioOptionId;
  final Set<String> selectedSpeakerIds;
  final List<PrayerAudioOption> audioOptions;
  final List<CastDevice> discoveredDevices;
  final bool isDiscovering;
  final bool isBusy;
  final String statusMessage;
  final String errorMessage;
  final bool isPhonePlaybackActive;
  final bool hasRemotePlayback;
  final Future<void> Function() onScanPressed;
  final Future<void> Function() onPlayPressed;
  final Future<void> Function() onStopPressed;
  final Future<void> Function(SpeakerRouteMode mode) onRouteModeChanged;
  final Future<void> Function(String optionId) onAudioOptionChanged;
  final Future<void> Function(String deviceId, bool selected)
  onSpeakerSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Speaker Routing', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Scan the local network for Chromecast and DLNA speakers, then choose whether Quran, adhan, or adhkar should play on this phone only or broadcast to selected speakers.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedAudioOptionId,
              decoration: const InputDecoration(
                labelText: 'Audio content',
                border: OutlineInputBorder(),
              ),
              items: audioOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.id,
                      child: Text('${option.category} · ${option.label}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value != null) {
                        unawaited(onAudioOptionChanged(value));
                      }
                    },
            ),
            const SizedBox(height: 12),
            Text(
              audioOptions
                      .firstWhere((option) => option.id == selectedAudioOptionId)
                      .description,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Playback target', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('This phone'),
                  selected: routeMode == SpeakerRouteMode.mobileOnly,
                  onSelected: isBusy
                      ? null
                      : (_) {
                          unawaited(
                            onRouteModeChanged(SpeakerRouteMode.mobileOnly),
                          );
                        },
                ),
                ChoiceChip(
                  label: const Text('Selected speakers'),
                  selected: routeMode == SpeakerRouteMode.selectedSpeakers,
                  onSelected: isBusy
                      ? null
                      : (_) {
                          unawaited(
                            onRouteModeChanged(
                              SpeakerRouteMode.selectedSpeakers,
                            ),
                          );
                        },
                ),
                ChoiceChip(
                  label: const Text('All speakers'),
                  selected: routeMode == SpeakerRouteMode.allDiscoveredSpeakers,
                  onSelected: isBusy
                      ? null
                      : (_) {
                          unawaited(
                            onRouteModeChanged(
                              SpeakerRouteMode.allDiscoveredSpeakers,
                            ),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => unawaited(onScanPressed()),
                    icon: Icon(
                      isDiscovering
                          ? Icons.stop_circle_outlined
                          : Icons.speaker_group_outlined,
                    ),
                    label: Text(isDiscovering ? 'Stop scan' : 'Scan speakers'),
                  ),
                ),
              ],
            ),
            if (statusMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusMessage, style: textTheme.bodyMedium),
              ),
            ],
            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  errorMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Discovered speakers', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (discoveredDevices.isEmpty)
              Text(
                isDiscovering
                    ? 'Scanning… supported speakers will appear here.'
                    : 'No supported speakers discovered yet.',
                style: textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (final CastDevice device in discoveredDevices)
                    CheckboxListTile(
                      dense: true,
                      value: selectedSpeakerIds.contains(device.id),
                      onChanged:
                          routeMode == SpeakerRouteMode.mobileOnly || isBusy
                          ? null
                          : (value) {
                              if (value != null) {
                                unawaited(
                                  onSpeakerSelectionChanged(device.id, value),
                                );
                              }
                            },
                      title: Text(device.name.toString()),
                      subtitle: Text(
                        '${device.protocol.name.toUpperCase()} • ${device.address.address}',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : () => unawaited(onPlayPressed()),
                    icon: Icon(
                      routeMode == SpeakerRouteMode.mobileOnly
                          ? Icons.play_arrow_rounded
                          : Icons.cast_connected_rounded,
                    ),
                    label: Text(
                      routeMode == SpeakerRouteMode.mobileOnly
                          ? 'Play on this phone'
                          : 'Broadcast now',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy || (!isPhonePlaybackActive && !hasRemotePlayback)
                        ? null
                        : () => unawaited(onStopPressed()),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop playback'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
