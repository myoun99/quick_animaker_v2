import 'package:flutter/material.dart';

import '../../models/playback_quality.dart';
import 'canvas_playback_controller.dart';

/// Play/stop, loop mode and quality transport row.
///
/// One widget serves both contexts: the timeline hosts it with
/// [PlaybackScope.activeCut] (play the active cut) and the storyboard with
/// [PlaybackScope.allCuts] (play every cut of the track in sequence).
class PlaybackTransportControls extends StatelessWidget {
  const PlaybackTransportControls({
    super.key,
    required this.controller,
    required this.scope,
    required this.quality,
    required this.onQualityChanged,
    this.playbackStartFrame,
  });

  final CanvasPlaybackController controller;
  final PlaybackScope scope;
  final PlaybackQuality quality;
  final ValueChanged<PlaybackQuality> onQualityChanged;

  /// Where playback begins in this scope (e.g. the timeline playhead);
  /// defaults to frame 0.
  final int Function()? playbackStartFrame;

  static String qualityLabel(PlaybackQuality quality) {
    return switch (quality) {
      PlaybackQuality.full => 'Full',
      PlaybackQuality.half => '1/2',
      PlaybackQuality.quarter => '1/4',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final controlsThisScope =
            controller.isActive && controller.scope == scope;
        final isPlayingHere = controlsThisScope && controller.isPlaying;

        return Row(
          key: ValueKey<String>('playback-transport-${scope.name}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey<String>('playback-play-button'),
              tooltip: isPlayingHere ? 'Pause' : 'Play',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: Icon(isPlayingHere ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (isPlayingHere) {
                  controller.pause();
                } else if (controlsThisScope) {
                  controller.resume();
                } else {
                  controller.play(
                    scope: scope,
                    startGlobalFrame: playbackStartFrame?.call(),
                  );
                }
              },
            ),
            IconButton(
              key: const ValueKey<String>('playback-stop-button'),
              tooltip: 'Stop',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.stop),
              onPressed: controlsThisScope ? controller.stop : null,
            ),
            IconButton(
              key: const ValueKey<String>('playback-loop-toggle'),
              tooltip: controller.loopMode == PlaybackLoopMode.loop
                  ? 'Loop (click for play once)'
                  : 'Play once (click for loop)',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              isSelected: controller.loopMode == PlaybackLoopMode.loop,
              selectedIcon: Icon(
                Icons.repeat,
                color: Theme.of(context).colorScheme.primary,
              ),
              icon: const Icon(Icons.repeat),
              onPressed: () {
                controller.loopMode =
                    controller.loopMode == PlaybackLoopMode.loop
                    ? PlaybackLoopMode.once
                    : PlaybackLoopMode.loop;
              },
            ),
            PopupMenuButton<PlaybackQuality>(
              key: const ValueKey<String>('playback-quality-selector'),
              tooltip: 'Playback quality',
              initialValue: quality,
              onSelected: onQualityChanged,
              itemBuilder: (context) => [
                for (final candidate in PlaybackQuality.values)
                  PopupMenuItem(
                    key: ValueKey<String>('playback-quality-${candidate.name}'),
                    value: candidate,
                    child: Text(qualityLabel(candidate)),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  qualityLabel(quality),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
