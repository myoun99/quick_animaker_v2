import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import 'layer_label_controls.dart';
import 'timeline_grid_metrics.dart';

class TimelineLayerControlsRow extends StatelessWidget {
  const TimelineLayerControlsRow({
    super.key,
    required this.layer,
    required this.active,
    required this.metrics,
    required this.onSelectLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    required this.onToggleLayerTimesheet,
    required this.onLayerMarkSelected,
    this.onToggleLayerMuted,
    this.sectionStart = false,
    this.hasLanes = false,
    this.lanesExpanded = false,
    this.onToggleLanes,
  });

  final Layer layer;
  final bool active;
  final TimelineGridMetrics metrics;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
  final ValueChanged<LayerId> onToggleLayerTimesheet;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

  /// SE rows' speaker button (the audio counterpart of visibility); null
  /// hides it.
  final ValueChanged<LayerId>? onToggleLayerMuted;

  /// Whether this row opens a new timesheet section (drawing/SE/camera);
  /// draws a heavier divider along the rail row's top edge.
  final bool sectionStart;

  /// AE-style property-lane twirl-down: layers with lanes get a chevron
  /// leading the row; rows without lanes keep an empty slot so labels stay
  /// column-aligned.
  final bool hasLanes;
  final bool lanesExpanded;
  final ValueChanged<LayerId>? onToggleLanes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.secondaryContainer.withValues(alpha: 0.55);

    final row = InkWell(
      key: ValueKey<String>('timeline-layer-row-${layer.id}'),
      onTap: () => onSelectLayer(layer.id),
      child: Container(
        // The section bracket occupies the leading gutter beside the rail.
        width: metrics.layerControlsWidth - metrics.sectionLabelGutterWidth,
        height: metrics.layerRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : colorScheme.surface,
          border: Border.all(
            color: active ? colorScheme.secondary : colorScheme.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: Semantics(
          key: active
              ? const ValueKey<String>('timeline-selected-layer')
              : null,
          label: active ? 'selected layer' : 'layer',
          container: true,
          explicitChildNodes: true,
          child: Row(
            children: [
              if (hasLanes && onToggleLanes != null)
                InkWell(
                  key: ValueKey<String>('timeline-lane-toggle-${layer.id}'),
                  onTap: () => onToggleLanes!(layer.id),
                  child: SizedBox(
                    width: 16,
                    height: 24,
                    child: Icon(
                      lanesExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 16,
                    ),
                  ),
                )
              else
                const SizedBox(width: 16),
              // Timesheet + mark chips lead the label; ineligible rows keep
              // empty slots so kind icons and names stay column-aligned.
              if (layerKindEligibleForTimesheetToggle(layer.kind))
                LayerTimesheetToggleButton(
                  keyPrefix: 'timeline',
                  layerId: layer.id,
                  onTimesheet: layer.onTimesheet,
                  onToggle: onToggleLayerTimesheet,
                )
              else
                const SizedBox(width: layerTimesheetSlotWidth),
              const SizedBox(width: 4),
              LayerMarkChip(
                keyPrefix: 'timeline',
                layerId: layer.id,
                mark: layer.mark,
                onMarkSelected: onLayerMarkSelected,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  key: ValueKey<String>('timeline-layer-name-${layer.id}'),
                  onTap: () => onSelectLayer(layer.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Semantics(
                          label: _semanticLabelForLayerKind(layer.kind),
                          container: true,
                          child: ExcludeSemantics(
                            child: Icon(
                              _iconForLayerKind(layer.kind),
                              key: ValueKey<String>(
                                'timeline-layer-kind-icon-${layer.id}',
                              ),
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            layer.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: active ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey<String>('timeline-layer-visibility-${layer.id}'),
                tooltip: layer.isVisible ? 'Hide layer' : 'Show layer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: Icon(
                  layer.isVisible ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                onPressed: () => onToggleLayerVisibility(layer.id),
              ),
              // SE rows carry the mute speaker beside the eye (sounds
              // silence, waveforms keep displaying). Tight SizedBox: the M3
              // IconButton otherwise inflates its layout box to the 48px
              // minimum tap target, overflowing the rail row.
              if (layer.kind == LayerKind.se && onToggleLayerMuted != null)
                SizedBox(
                  width: 20,
                  height: 32,
                  child: IconButton(
                    key: ValueKey<String>('timeline-layer-mute-${layer.id}'),
                    tooltip: layer.muted ? 'Unmute layer' : 'Mute layer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 20,
                      height: 32,
                    ),
                    icon: Icon(
                      layer.muted ? Icons.volume_off : Icons.volume_up,
                      size: 18,
                    ),
                    onPressed: () => onToggleLayerMuted!(layer.id),
                  ),
                ),
              // The camera row's slider drives the camera-view DIM opacity
              // (unified layer controls). 56+30: the SE rows' mute slot
              // needs the 12px back — every row shrinks alike so the
              // control columns stay aligned.
              if (layerKindShowsOpacityControl(layer.kind)) ...[
                SizedBox(
                  width: 56,
                  child: Slider(
                    key: ValueKey<String>('timeline-layer-opacity-${layer.id}'),
                    min: 0,
                    max: 1,
                    value: layer.opacity.clamp(0.0, 1.0).toDouble(),
                    onChanged: (opacity) =>
                        onLayerOpacityChanged(layer.id, opacity),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${(layer.opacity * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!sectionStart) {
      return row;
    }
    return Stack(
      children: [
        row,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 2,
          child: IgnorePointer(
            child: Container(
              key: ValueKey<String>(
                'timeline-section-divider-rail-${layer.id}',
              ),
              color: colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

IconData _iconForLayerKind(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation => Icons.brush_outlined,
    LayerKind.storyboard => Icons.auto_stories_outlined,
    LayerKind.art => Icons.landscape_outlined,
    LayerKind.se => Icons.music_note_outlined,
    LayerKind.instruction => Icons.theaters_outlined,
    LayerKind.camera => Icons.videocam_outlined,
  };
}

String _semanticLabelForLayerKind(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation => 'Animation layer',
    LayerKind.storyboard => 'Storyboard layer',
    LayerKind.art => 'Art layer',
    LayerKind.se => 'SE layer',
    LayerKind.instruction => 'Instruction layer',
    LayerKind.camera => 'Camera layer',
  };
}
