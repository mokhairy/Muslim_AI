import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/prayer_models.dart';
import 'offline_cache_service.dart';
import 'shared_audio_player.dart';

class AudioOutputRoutingService extends ChangeNotifier {
  AudioOutputRoutingService({required SharedAudioOwner owner})
    : _owner = owner,
      _castService = CastService(
        discoveryProviders: [
          ChromecastDiscoveryProvider(),
          AirPlayDiscoveryProvider(),
          DlnaDiscoveryProvider(),
        ],
      ) {
    _playerStateSubscription = _sharedAudio.player.playerStateStream.listen((
      _,
    ) {
      if (_sharedAudio.owner == _owner) {
        notifyListeners();
      }
    });
  }

  static const List<PrayerAudioOption> audioOptions = [
    PrayerAudioOption(
      id: 'quran_fatihah_alafasy',
      category: 'Quran',
      label: 'Surah Al-Fatihah · Alafasy',
      description: 'Streams recorded Quran recitation from Quranicaudio.',
      audioUrl:
          'https://download.quranicaudio.com/qdc/mishari_al_afasy/murattal/1.mp3',
      mediaType: 'mp3',
    ),
    PrayerAudioOption(
      id: 'adhan_makkah',
      category: 'Prayer Call',
      label: 'Adhan · Makkah style',
      description: 'Recorded Arabic adhan stream for prayer reminders.',
      audioUrl: 'https://www.islamcan.com/audio/adhan/azan1.mp3',
      mediaType: 'mp3',
    ),
    PrayerAudioOption(
      id: 'adhan_madinah',
      category: 'Prayer Call',
      label: 'Adhan · Madinah style',
      description: 'Alternate recorded Arabic adhan stream.',
      audioUrl: 'https://www.islamcan.com/audio/adhan/azan2.mp3',
      mediaType: 'mp3',
    ),
    PrayerAudioOption(
      id: 'adhkar_morning',
      category: 'Adhkar',
      label: 'Morning Adhkar',
      description: 'Recorded native-Arabic morning adhkar recitation.',
      audioUrl: 'https://www.rslan.org/chains/Wabel2/01_01.mp3',
      mediaType: 'mp3',
    ),
    PrayerAudioOption(
      id: 'adhkar_evening',
      category: 'Adhkar',
      label: 'Evening Adhkar',
      description: 'Recorded native-Arabic evening adhkar recitation.',
      audioUrl: 'https://www.rslan.org/chains/Wabel2/02_01.mp3',
      mediaType: 'mp3',
    ),
  ];

  final SharedAudioOwner _owner;
  final CastService _castService;
  final SharedAudioPlayer _sharedAudio = SharedAudioPlayer.instance;
  final OfflineCacheService _offlineCache = OfflineCacheService.instance;
  final Map<String, CastSession> _activeSessions = <String, CastSession>{};

  StreamSubscription<List<CastDevice>>? _discoverySubscription;
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  List<CastDevice> _devices = const [];
  bool _isDiscovering = false;
  bool _isBusy = false;
  String _statusMessage = '';
  String _errorMessage = '';
  String? _activeAudioOptionId;
  Set<String> _lastBroadcastDeviceIds = <String>{};

  List<CastDevice> get devices => _devices;
  bool get isDiscovering => _isDiscovering;
  bool get isBusy => _isBusy;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;
  bool get isPhonePlaybackActive =>
      _sharedAudio.owner == _owner &&
      _sharedAudio.player.playing &&
      _activeSessions.isEmpty;
  bool get hasRemotePlayback => _activeSessions.isNotEmpty;
  String? get activeAudioOptionId => _activeAudioOptionId;
  Set<String> get lastBroadcastDeviceIds => _lastBroadcastDeviceIds;

  PrayerAudioOption get defaultAudioOption => audioOptions.first;

  PrayerAudioOption? optionById(String optionId) {
    for (final option in audioOptions) {
      if (option.id == optionId) {
        return option;
      }
    }
    return null;
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      return;
    }

    _errorMessage = '';
    _statusMessage = 'Checking local network permissions…';
    notifyListeners();

    final permissionsOk = await _requestDiscoveryPermissions();
    if (!permissionsOk) {
      _statusMessage = '';
      _errorMessage =
          'Local network discovery permission was denied. Allow nearby Wi-Fi and location access, then scan again.';
      notifyListeners();
      return;
    }

    await _discoverySubscription?.cancel();
    _devices = const [];
    _isDiscovering = true;
    _statusMessage =
        'Scanning the local network for Chromecast, AirPlay, and DLNA speakers…';
    _errorMessage = '';
    notifyListeners();

    _discoverySubscription = _castService
        .startDiscovery(
          protocols: const {
            CastProtocol.chromecast,
            CastProtocol.airplay,
            CastProtocol.dlna,
          },
          timeout: const Duration(seconds: 12),
        )
        .listen(
          (devices) {
            _devices = List<CastDevice>.from(devices)
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
            _statusMessage = _devices.isEmpty
                ? 'No smart speakers found yet. Keep the app open while the scan completes.'
                : 'Found ${_devices.length} speaker${_devices.length == 1 ? '' : 's'} on this network.';
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _isDiscovering = false;
            _statusMessage = '';
            _errorMessage = 'Speaker discovery failed: $error';
            notifyListeners();
          },
          onDone: () {
            _isDiscovering = false;
            if (_errorMessage.isEmpty && _statusMessage.isEmpty) {
              _statusMessage = _devices.isEmpty
                  ? 'Scan finished. No supported smart speakers were discovered on this network.'
                  : 'Scan finished. ${_devices.length} speaker${_devices.length == 1 ? '' : 's'} ready.';
            }
            notifyListeners();
          },
        );
  }

  Future<void> stopDiscovery() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _castService.stopDiscovery();
    _isDiscovering = false;
    if (_statusMessage.startsWith('Scanning the local network')) {
      _statusMessage = _devices.isEmpty
          ? 'Speaker scan stopped.'
          : 'Speaker scan stopped with ${_devices.length} device${_devices.length == 1 ? '' : 's'} found.';
    }
    notifyListeners();
  }

  Future<void> playOnPhone(PrayerAudioOption option) async {
    await _runWithBusyState(() async {
      await _stopRemoteSessions();
      await _sharedAudio.claim(_owner);

      final audioUri = await _offlineCache.resolvePlayableAudioUri(
        option.audioUrl,
      );
      await _sharedAudio.player.setAudioSource(
        AudioSource.uri(
          audioUri,
          tag: MediaItem(
            id: option.id,
            album: option.category,
            title: option.label,
            artist: 'MuslimAI',
          ),
        ),
      );
      unawaited(_sharedAudio.player.play());
      _activeAudioOptionId = option.id;
      _lastBroadcastDeviceIds = <String>{};
      _statusMessage = 'Playing ${option.label} on this phone.';
      _errorMessage = '';
    });
  }

  Future<void> broadcast({
    required PrayerAudioOption option,
    required SpeakerRouteMode mode,
    required Set<String> selectedDeviceIds,
  }) async {
    await _runWithBusyState(() async {
      final targets = _resolveTargets(mode, selectedDeviceIds);
      if (targets.isEmpty) {
        throw StateError(
          mode == SpeakerRouteMode.selectedSpeakers
              ? 'Select at least one speaker before broadcasting.'
              : 'No smart speakers are available to broadcast to.',
        );
      }

      await _sharedAudio.claim(_owner);
      await _sharedAudio.player.stop();
      await _stopRemoteSessions();

      final media = await _buildCastMedia(option);
      final successfulDeviceIds = <String>{};
      final failedDevices = <String>[];

      for (final device in targets) {
        try {
          final session = await _connectSession(device);
          await session.loadMedia(media);
          _activeSessions[device.id] = session;
          successfulDeviceIds.add(device.id);
        } catch (error) {
          failedDevices.add('${device.name}: $error');
        }
      }

      if (successfulDeviceIds.isEmpty) {
        throw StateError(
          failedDevices.isEmpty
              ? 'Broadcast could not start on the selected speakers.'
              : failedDevices.join('\n'),
        );
      }

      _activeAudioOptionId = option.id;
      _lastBroadcastDeviceIds = successfulDeviceIds;
      _errorMessage = failedDevices.isEmpty
          ? ''
          : 'Some speakers failed to start:\n${failedDevices.join('\n')}';
      _statusMessage = failedDevices.isEmpty
          ? 'Broadcasting ${option.label} to ${successfulDeviceIds.length} speaker${successfulDeviceIds.length == 1 ? '' : 's'}.'
          : 'Broadcasting ${option.label} to ${successfulDeviceIds.length} speaker${successfulDeviceIds.length == 1 ? '' : 's'}, with ${failedDevices.length} failure${failedDevices.length == 1 ? '' : 's'}.';
    });
  }

  Future<void> stopAllPlayback() async {
    await _runWithBusyState(() async {
      await _stopRemoteSessions();
      if (_sharedAudio.owner == _owner) {
        await _sharedAudio.release(_owner);
      }
      _activeAudioOptionId = null;
      _lastBroadcastDeviceIds = <String>{};
      _statusMessage = 'Playback stopped.';
      _errorMessage = '';
    });
  }

  Future<void> shutdown() async {
    await stopDiscovery();
    await _stopRemoteSessions();
    await _playerStateSubscription.cancel();
    if (_sharedAudio.owner == _owner) {
      await _sharedAudio.release(_owner);
    }
    await _castService.dispose();
  }

  Future<void> _runWithBusyState(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    _isBusy = true;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _errorMessage = error.toString();
      _statusMessage = '';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> _requestDiscoveryPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final nearbyStatus = await Permission.nearbyWifiDevices.request();
    final locationStatus = await Permission.locationWhenInUse.request();
    return nearbyStatus.isGranted && locationStatus.isGranted;
  }

  List<CastDevice> _resolveTargets(
    SpeakerRouteMode mode,
    Set<String> selectedDeviceIds,
  ) {
    switch (mode) {
      case SpeakerRouteMode.mobileOnly:
        return const [];
      case SpeakerRouteMode.selectedSpeakers:
        return _devices
            .where((device) => selectedDeviceIds.contains(device.id))
            .toList(growable: false);
      case SpeakerRouteMode.allDiscoveredSpeakers:
        return List<CastDevice>.from(_devices, growable: false);
    }
  }

  Future<CastMedia> _buildCastMedia(PrayerAudioOption option) async {
    final localPath = await _offlineCache.resolveDownloadedAudioPath(
      option.audioUrl,
    );
    if (localPath != null) {
      return CastMedia.file(
        filePath: localPath,
        type: _castMediaTypeFor(option.mediaType),
        title: option.label,
      );
    }

    return CastMedia(
      url: option.audioUrl,
      type: _castMediaTypeFor(option.mediaType),
      title: option.label,
    );
  }

  CastMediaType _castMediaTypeFor(String value) {
    switch (value) {
      case 'mp3':
      default:
        return CastMediaType.mp3;
    }
  }

  Future<CastSession> _connectSession(CastDevice device) async {
    final session = switch (device.protocol) {
      CastProtocol.chromecast => ChromecastSession(device: device),
      CastProtocol.dlna => DlnaSession.fromDevice(device),
      CastProtocol.airplay => AirPlaySession(device),
    };

    await session.connect();
    return session;
  }

  Future<void> _stopRemoteSessions() async {
    final sessions = List<CastSession>.from(_activeSessions.values);
    _activeSessions.clear();
    for (final session in sessions) {
      try {
        await session.stop();
      } catch (_) {
        // Best-effort cleanup.
      }
      try {
        await session.disconnect();
      } catch (_) {
        // Best-effort cleanup.
      }
      session.dispose();
    }
  }
}

typedef PrayerAudioRoutingService = AudioOutputRoutingService;
