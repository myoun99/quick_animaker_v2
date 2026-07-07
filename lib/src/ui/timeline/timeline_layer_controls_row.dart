import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import 'layer_label_controls.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_section_policy.dart';

/// The rail's leading gutter cell: empty spacer on most rows, the rotated
/// section label (+ fold chevron on collapsible sections) on each section's
/// first visible row — the paper sheet's column-group headings on their
/// side.
class TimelineSectionGutterSlot extends StatelessWidget {
  const TimelineSectionGutterSlot({
    super.key,
    required this.metrics,
    required this.section,
    this.onToggleSection,
    this.collapsed = false,
  });

  final TimelineGridMetrics metrics;
  final TimelineSection? section;
  final VoidCallback? onToggleSection;

  /// Whether this slot sits on a collapsed-section stub row (flips the
  /// chevron).
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final section = this.section;
    if (metrics.sectionLabelGutterWidth <= 0) {
      return const SizedBox.shrink();
    }
    if (section == null) {
      return SizedBox(width: metrics.sectionLabelGutterWidth);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final collapsible =
        timelineSectionCollapsible(section) && onToggleSection != null;
    final content = Column(
      children: [
        if (collapsible)
          Icon(
            collapsed ? Icons.chevron_right : Icons.expand_more,
            size: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        Expanded(
          child: Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                timelineSectionLabel(section),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      width: metrics.sectionLabelGutterWidth,
      child: collapsible
          ? InkWell(
              key: ValueKey<String>(
                'timeline-section-collapse-${section.name}',
              ),
              onTap: onToggleSection,
              child: Semantics(
                label:
                    '${collapsed ? 'Expand' : 'Collapse'} '
                    '${timelineSectionLabel(section)} section',
                button: true,
                child: content,
              ),
            )
          : ExcludeSemantics(child: content),
    );
  }
}

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
    this.sectionStart = false,
    this.sectionStartOf,
    this.onToggleSection,
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

  /// Whether this row opens a new timesheet section (drawing/SE/camera);
  /// draws a heavier divider along the rail row's top edge.
  final bool sectionStart;

  /// The section this row is the FIRST VISIBLE row of, if any: the gutter
  /// slot prints its rotated label there (with the fold chevron on
  /// collapsible sections). Unlike [sectionStart] this is also set on the
  /// very first row.
  final TimelineSection? sectionStartOf;

  /// Folds [sectionStartOf] away (collapsible sections only).
  final VoidCallback? onToggleSection;

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
        width: metrics.layerControlsWidth,
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
              TimelineSectionGutterSlot(
                metrics: metrics,
                section: sectionStartOf,
                onToggleSection: onToggleSection,
              ),
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
              if (layer.kind != LayerKind.camera)
                LayerMarkChip(
                  keyPrefix: 'timeline',
                  layerId: layer.id,
                  mark: layer.mark,
                  onMarkSelected: onLayerMarkSelected,
                )
              else
                const SizedBox(width: layerMarkSlotWidth),
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
              // Camera and instruction rows never composite; hide the
              // opacity slider rather than offering a dead control.
              if (layerKindHoldsDrawings(layer.kind)) ...[
                SizedBox(
                  width: 64,
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
                  width: 34,
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
