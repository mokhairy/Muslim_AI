import 'dart:async';

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/material.dart';

import '../models/prayer_models.dart';

class AudioOutputRoutingCard extends StatelessWidget {
  const AudioOutputRoutingCard({
    super.key,
    required this.title,
    required this.description,
    required this.routeMode,
    required this.selectedSpeakerIds,
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
    required this.onSpeakerSelectionChanged,
    this.settings,
    this.playButtonLabel = 'Play now',
    this.mobilePlayButtonLabel = 'Play on this phone',
  });

  final String title;
  final String description;
  final SpeakerRouteMode routeMode;
  final Set<String> selectedSpeakerIds;
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
  final Future<void> Function(String deviceId, bool selected)
  onSpeakerSelectionChanged;
  final Widget? settings;
  final String playButtonLabel;
  final String mobilePlayButtonLabel;

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
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description, style: textTheme.bodyMedium),
            if (settings != null) ...[
              const SizedBox(height: 16),
              settings!,
            ],
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
                      : (_) => unawaited(
                          onRouteModeChanged(SpeakerRouteMode.mobileOnly),
                        ),
                ),
                ChoiceChip(
                  label: const Text('Selected speakers'),
                  selected: routeMode == SpeakerRouteMode.selectedSpeakers,
                  onSelected: isBusy
                      ? null
                      : (_) => unawaited(
                          onRouteModeChanged(
                            SpeakerRouteMode.selectedSpeakers,
                          ),
                        ),
                ),
                ChoiceChip(
                  label: const Text('All speakers'),
                  selected: routeMode == SpeakerRouteMode.allDiscoveredSpeakers,
                  onSelected: isBusy
                      ? null
                      : (_) => unawaited(
                          onRouteModeChanged(
                            SpeakerRouteMode.allDiscoveredSpeakers,
                          ),
                        ),
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
                          ? mobilePlayButtonLabel
                          : playButtonLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isBusy || (!isPhonePlaybackActive && !hasRemotePlayback)
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
