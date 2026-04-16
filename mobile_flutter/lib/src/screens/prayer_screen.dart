import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/prayer_models.dart';
import '../services/app_preferences_service.dart';
import '../services/prayer_service.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  final _service = PrayerService();
  final _preferences = AppPreferencesService.instance;
  final _latitudeController = TextEditingController(text: '23.5880');
  final _longitudeController = TextEditingController(text: '58.3829');

  DateTime _selectedDate = DateTime.now();
  PrayerTimesResponse? _prayerTimes;
  QiblaResponse? _qibla;
  bool _loading = true;
  bool _locating = false;
  bool _locationFromDevice = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
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
    await _load();
  }

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Prayer Times', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'AlAdhan-backed prayer schedule with saved coordinates and a device-location shortcut for accurate local prayer times.',
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
          if (_qibla != null) _QiblaCard(data: _qibla!),
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
  const _QiblaCard({required this.data});

  final QiblaResponse data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qibla', style: textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              '${data.direction.toStringAsFixed(1)}° from north',
              style: textTheme.displaySmall?.copyWith(fontSize: 28),
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
