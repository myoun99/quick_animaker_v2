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
              key: const ValueKey<String>(
                'storyboard-timeline-horizontal-viewport',
              ),
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
                      timelineScale: _timelineScale,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryboardTrackRow extends StatelessWidget {
  const _StoryboardTrackRow({
    required this.track,
    required this.layoutEntries,
    required this.trackLabel,
    required this.activeCutId,
    required this.onCutSelected,
    required this.timelineScale,
  });

  final Track track;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final String trackLabel;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;
  final TimelineScale timelineScale;

  @override
  Widget build(BuildContext context) {
    final timelineWidth = _timelineWidthFor(layoutEntries, timelineScale);

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
          SizedBox(
            key: ValueKey<String>(
              'storyboard-track-timeline-area-${track.id.value}',
            ),
            width: timelineWidth,
            height: 64,
            child: Stack(
              children: [
                for (final entry in layoutEntries)
                  Positioned(
                    key: ValueKey<String>(
                      'storyboard-cut-positioned-${entry.cutId.value}',
                    ),
                    left: timelineScale.leftForFrame(entry.startFrame),
                    width: timelineScale.widthForDuration(entry.duration),
                    top: 0,
                    bottom: 0,
                    child: _StoryboardCutBlock(
                      layoutEntry: entry,
                      width: timelineScale.widthForDuration(entry.duration),
                      isActive: entry.cutId == activeCutId,
                      onSelected: onCutSelected,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _timelineWidthFor(
    List<StoryboardTimelineLayoutEntry> entries,
    TimelineScale scale,
  ) {
    const trailingPadding = 12.0;

    if (entries.isEmpty) {
      return 0;
    }

    return entries
            .map(
              (entry) =>
                  scale.leftForFrame(entry.startFrame) +
                  scale.widthForDuration(entry.duration),
            )
            .reduce(
              (width, nextWidth) => width > nextWidth ? width : nextWidth,
            ) +
        trailingPadding;
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
      minHeight: 0,
      padding: const EdgeInsets.all(4),
      onTap: isActive ? null : () => onSelected(cut.id),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: isActive ? 48 : 0),
                child: Text(
                  cut.name,
                  key: ValueKey<String>('storyboard-cut-title-${cut.id.value}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Text(
                    '${layoutEntry.duration}f',
                    key: ValueKey<String>(
                      'storyboard-cut-duration-${cut.id.value}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${layoutEntry.startFrame}f - ${layoutEntry.endFrame}f',
                      key: ValueKey<String>(
                        'storyboard-cut-frame-range-${cut.id.value}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Expanded(
                child: storyboardLayer == null
                    ? ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'No Storyboard Layer',
                            key: ValueKey<String>(
                              'storyboard-layer-empty-${cut.id.value}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : Container(
                        key: ValueKey<String>(
                          'storyboard-layer-strip-${cut.id.value}',
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        child: ClipRect(
                          child: Text(
                            storyboardLayer.name,
                            key: ValueKey<String>(
                              'storyboard-layer-name-${cut.id.value}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
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
