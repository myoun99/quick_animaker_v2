import 'package:flutter/material.dart';

import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/layer.dart';
import '../models/layer_kind.dart';
import '../models/project.dart';
import '../models/track.dart';
import 'storyboard_timeline_layout.dart';
import 'timeline/timeline_block.dart';
import 'timeline/timeline_scale.dart';

class StoryboardPanel extends StatelessWidget {
  const StoryboardPanel({
    super.key,
    required this.project,
    required this.activeCutId,
    required this.onCutSelected,
  });

  static const TimelineScale _timelineScale = TimelineScale();
  static const double _trackLabelWidth = 56;

  final Project project;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final layoutEntries = buildStoryboardTimelineLayout(project);

    return DecoratedBox(
      key: const ValueKey<String>('storyboard-panel'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STORYBOARD',
              key: const ValueKey<String>('storyboard-panel-title'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < project.tracks.length; index++)
                    _StoryboardTrackRow(
                      track: project.tracks[index],
                      layoutEntries: layoutEntries
                          .where((entry) => entry.trackIndex == index)
                          .toList(growable: false),
                      trackLabel: 'V${index + 1}',
                      activeCutId: activeCutId,
                      onCutSelected: onCutSelected,
                      cutWidthFor: _cutWidthFor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _cutWidthFor(Cut cut) {
    return _timelineScale.widthForDuration(cut.duration);
  }
}

class _StoryboardTrackRow extends StatelessWidget {
  const _StoryboardTrackRow({
    required this.track,
    required this.layoutEntries,
    required this.trackLabel,
    required this.activeCutId,
    required this.onCutSelected,
    required this.cutWidthFor,
  });

  final Track track;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final String trackLabel;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;
  final double Function(Cut cut) cutWidthFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey<String>('storyboard-track-row-${track.id.value}'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: StoryboardPanel._trackLabelWidth,
            height: 64,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                trackLabel,
                key: ValueKey<String>(
                  'storyboard-track-label-${track.id.value}',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Row(
            children: [
              for (final entry in layoutEntries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _StoryboardCutBlock(
                    layoutEntry: entry,
                    width: cutWidthFor(entry.cut),
                    isActive: entry.cutId == activeCutId,
                    onSelected: onCutSelected,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoryboardCutBlock extends StatelessWidget {
  const _StoryboardCutBlock({
    required this.layoutEntry,
    required this.width,
    required this.isActive,
    required this.onSelected,
  });

  final StoryboardTimelineLayoutEntry layoutEntry;
  final double width;
  final bool isActive;
  final ValueChanged<CutId> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cut = layoutEntry.cut;
    final storyboardLayer = _storyboardLayerFor(cut);

    return TimelineBlock(
      key: ValueKey<String>('storyboard-cut-block-${cut.id.value}'),
      width: width,
      isActive: isActive,
      onTap: isActive ? null : () => onSelected(cut.id),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(right: isActive ? 48 : 0),
                child: Text(
                  cut.name,
                  key: ValueKey<String>('storyboard-cut-title-${cut.id.value}'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '${layoutEntry.duration}f',
                    key: ValueKey<String>(
                      'storyboard-cut-duration-${cut.id.value}',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${layoutEntry.startFrame}f - ${layoutEntry.endFrame}f',
                      key: ValueKey<String>(
                        'storyboard-cut-frame-range-${cut.id.value}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (storyboardLayer == null)
                Text(
                  'No Storyboard Layer',
                  key: ValueKey<String>(
                    'storyboard-layer-empty-${cut.id.value}',
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                )
              else
                Container(
                  key: ValueKey<String>(
                    'storyboard-layer-strip-${cut.id.value}',
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    storyboardLayer.name,
                    key: ValueKey<String>(
                      'storyboard-layer-name-${cut.id.value}',
                    ),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onPrimaryContainer),
                  ),
                ),
            ],
          ),
          if (isActive)
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                'ACTIVE',
                key: ValueKey<String>(
                  'storyboard-cut-active-indicator-${cut.id.value}',
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Layer? _storyboardLayerFor(Cut cut) {
    for (final layer in cut.layers) {
      if (layer.kind == LayerKind.storyboard) {
        return layer;
      }
    }
    return null;
  }
}
