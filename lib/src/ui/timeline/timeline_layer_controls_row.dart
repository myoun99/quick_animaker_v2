import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import '../widgets/field_slider.dart';
import '../widgets/panel_flyout.dart';
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
    this.onLayerOpacityChangeEnd,
    required this.onToggleLayerTimesheet,
    required this.onLayerMarkSelected,
    this.onToggleLayerFillReference,
    this.onToggleLayerMuted,
    this.hasLanes = false,
    this.lanesExpanded = false,
    this.onToggleLanes,
    this.fxEnabled = true,
    this.onToggleLayerFx,
    this.sectionLabel,
    this.sectionFlyoutEntries,
    this.opacityDragPreview,
  });

  final Layer layer;
  final bool active;
  final TimelineGridMetrics metrics;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;

  /// Commit-on-release hook (R4 #4): per-move values ride
  /// [onLayerOpacityChanged] as a cheap preview; the release lands here as
  /// the real write. Null keeps the legacy per-move-write behavior.
  final void Function(LayerId layerId, double opacity)? onLayerOpacityChangeEnd;

  final ValueChanged<LayerId> onToggleLayerTimesheet;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

  /// Drawing rows' FILL-reference toggle (R20-C2, the CSP lighthouse);
  /// null hides it.
  final ValueChanged<LayerId>? onToggleLayerFillReference;

  /// SE rows' speaker button (the audio counterpart of visibility); null
  /// hides it.
  final ValueChanged<LayerId>? onToggleLayerMuted;

  /// AE-style property-lane twirl-down: layers with lanes get a chevron
  /// leading the row; rows without lanes keep an empty slot so labels stay
  /// column-aligned.
  final bool hasLanes;
  final bool lanesExpanded;
  final ValueChanged<LayerId>? onToggleLanes;

  /// The AE-style fx switch (session view state): bypasses the layer's
  /// transform/FX on every composite route while off. Null hides it.
  final bool fxEnabled;
  final ValueChanged<LayerId>? onToggleLayerFx;

  /// The INLINE section tag (UI-R5): the section's FIRST row carries its
  /// label (ACTION/SE/CAM) in the leading slot; every other row reserves
  /// the slot empty so the control columns stay aligned. Tapping the tag
  /// opens the section flyout ([sectionFlyoutEntries]).
  final String? sectionLabel;
  final List<PanelFlyoutEntry> Function()? sectionFlyoutEntries;

  /// The session's live opacity-drag preview (UI-R6 #2): while the master
  /// bar (or another surface) drags THIS layer's opacity, the row's slider
  /// follows live instead of waiting for the release commit.
  final ValueListenable<({Set<LayerId> layerIds, double opacity})?>?
  opacityDragPreview;

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
        // The section band hugs the row's LEFT edge (UI-R6 #5); the 8px
        // breathing room moves between the band and the lane chevron.
        padding: const EdgeInsets.only(right: 8),
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
              // The inline section BAND (UI-R5/R6 #5): a tinted vertical
              // zone on every row; the section's first row carries its
              // label inside it.
              LayerSectionBandCell(
                child: sectionLabel == null
                    ? null
                    : Builder(
                        builder: (anchorContext) => InkWell(
                          key: ValueKey<String>(
                            'timeline-section-tag-${layer.id}',
                          ),
                          onTap: sectionFlyoutEntries == null
                              ? null
                              : () => showPanelFlyout(
                                  anchorContext,
                                  entries: sectionFlyoutEntries!(),
                                ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              sectionLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              if (hasLanes && onToggleLanes != null)
                InkWell(
                  key: ValueKey<String>('timeline-lane-toggle-${layer.id}'),
                  onTap: () => onToggleLanes!(layer.id),
                  child: SizedBox(
                    width: layerLaneToggleSlotWidth,
                    height: 24,
                    child: Icon(
                      lanesExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 16,
                    ),
                  ),
                )
              else
                const SizedBox(width: layerLaneToggleSlotWidth),
              // Timesheet + mark chips lead the label; ineligible rows keep
              // empty slots so kind icons and names stay column-aligned.
              // Attach rows (W5) hide the sheet toggle — they are display
              // accessories of their base, never sheet columns.
              if (layerKindEligibleForTimesheetToggle(layer.kind) &&
                  layer.attachedToLayerId == null)
                LayerTimesheetToggleButton(
                  keyPrefix: 'timeline',
                  layerId: layer.id,
                  onTimesheet: layer.onTimesheet,
                  onToggle: onToggleLayerTimesheet,
                )
              else
                const SizedBox(width: layerTimesheetSlotWidth),
              const SizedBox(width: layerControlChipGap),
              LayerMarkChip(
                keyPrefix: 'timeline',
                layerId: layer.id,
                mark: layer.mark,
                onMarkSelected: onLayerMarkSelected,
              ),
              const SizedBox(width: layerControlChipGap),
              Expanded(
                child: InkWell(
                  key: ValueKey<String>('timeline-layer-name-${layer.id}'),
                  onTap: () => onSelectLayer(layer.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        // Attach rows (W5) indent under their base with a
                        // branch glyph — the row reads as part of the
                        // base's group.
                        if (layer.attachedToLayerId != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, right: 2),
                            child: Icon(
                              Icons.subdirectory_arrow_right,
                              key: ValueKey<String>(
                                'timeline-layer-attach-indent-${layer.id}',
                              ),
                              size: 14,
                            ),
                          ),
                        Semantics(
                          label: _semanticLabelForLayerKind(layer.kind),
                          container: true,
                          child: ExcludeSemantics(
                            child: Icon(
                              layerKindIcon(layer.kind),
                              key: ValueKey<String>(
                                'timeline-layer-kind-icon-${layer.id}',
                              ),
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Selection reads by COLOR only (user rule): no
                        // bold flip, so the text never reflows on select.
                        Flexible(
                          child: Text(
                            layer.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Fill-reference toggle (R20-C2): drawing rows only — every
              // OTHER kind reserves the slot so the legend header's column
              // icons line up over one Excel-style grid (R-toolbar round).
              if (onToggleLayerFillReference != null &&
                  layer.kind == LayerKind.animation)
                SizedBox(
                  width: layerFillReferenceSlotWidth,
                  height: 26,
                  child: IconButton(
                    key: ValueKey<String>(
                      'timeline-layer-fill-reference-${layer.id}',
                    ),
                    tooltip: layer.isFillReference
                        ? 'Fill reference layer (on)'
                        : 'Fill reference layer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: layerFillReferenceSlotWidth,
                      height: 26,
                    ),
                    icon: Icon(
                      Icons.format_color_fill,
                      size: 16,
                      color: layer.isFillReference
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.45),
                    ),
                    onPressed: () => onToggleLayerFillReference!(layer.id),
                  ),
                )
              else
                const SizedBox(width: layerFillReferenceSlotWidth),
              // Attach rows hide the fx switch — the BASE's switch governs
              // the shared transform/opacity lanes (W5 fx sharing).
              if (onToggleLayerFx != null &&
                  layerKindShowsFxToggle(layer.kind) &&
                  layer.attachedToLayerId == null)
                LayerFxToggleButton(
                  keyPrefix: 'timeline',
                  layerId: layer.id,
                  fxEnabled: fxEnabled,
                  onToggle: onToggleLayerFx!,
                )
              else
                const SizedBox(width: layerFxSlotWidth),
              SizedBox(
                width: layerVisibilitySlotWidth,
                height: 26,
                child: IconButton(
                  key: ValueKey<String>(
                    'timeline-layer-visibility-${layer.id}',
                  ),
                  tooltip: layer.isVisible ? 'Hide layer' : 'Show layer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: layerVisibilitySlotWidth,
                    height: 26,
                  ),
                  icon: Icon(
                    layer.isVisible ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                  ),
                  onPressed: () => onToggleLayerVisibility(layer.id),
                ),
              ),
              // SE rows carry the mute speaker beside the eye (sounds
              // silence, waveforms keep displaying). Tight SizedBox: the M3
              // IconButton otherwise inflates its layout box to the 48px
              // minimum tap target, overflowing the rail row.
              if (layer.kind == LayerKind.se && onToggleLayerMuted != null)
                SizedBox(
                  width: layerMuteSlotWidth,
                  height: 26,
                  child: IconButton(
                    key: ValueKey<String>('timeline-layer-mute-${layer.id}'),
                    tooltip: layer.muted ? 'Unmute layer' : 'Mute layer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: layerMuteSlotWidth,
                      height: 26,
                    ),
                    icon: Icon(
                      layer.muted ? Icons.volume_off : Icons.volume_up,
                      size: 16,
                    ),
                    onPressed: () => onToggleLayerMuted!(layer.id),
                  ),
                )
              else
                const SizedBox(width: layerMuteSlotWidth),
              // The camera row's slider drives the camera-view DIM opacity
              // (unified layer controls); every row shrinks alike so the
              // control columns stay aligned.
              if (layerKindShowsOpacityControl(layer.kind))
                SizedBox(width: layerOpacitySlotWidth, child: _opacityField())
              else
                const SizedBox(width: layerOpacitySlotWidth),
            ],
          ),
        ),
      ),
    );

    // Section boundaries draw ONE shared hairline like every row boundary
    // (R3 feedback #6) — the old extra 2px overlay double-lined them; the
    // gutter bracket carries the section identity.
    return row;
  }

  /// The row's opacity slider, live-following the session's drag preview
  /// when it targets this layer (the master bar sweep, UI-R6 #2).
  Widget _opacityField() {
    Widget slider(double value) => FieldSlider(
      key: ValueKey<String>('timeline-layer-opacity-${layer.id}'),
      min: 0,
      max: 1,
      value: value,
      valueText: '${(value * 100).round()}%',
      valueTextBuilder: (next) => '${(next * 100).round()}%',
      displayFactor: 100,
      height: 18,
      onChanged: (opacity) => onLayerOpacityChanged(layer.id, opacity),
      onChangeEnd: onLayerOpacityChangeEnd == null
          ? null
          : (opacity) => onLayerOpacityChangeEnd!(layer.id, opacity),
    );

    final preview = opacityDragPreview;
    final resting = layer.opacity.clamp(0.0, 1.0).toDouble();
    if (preview == null) {
      return slider(resting);
    }
    return ValueListenableBuilder<({Set<LayerId> layerIds, double opacity})?>(
      valueListenable: preview,
      builder: (context, dragging, _) => slider(
        dragging != null && dragging.layerIds.contains(layer.id)
            ? dragging.opacity
            : resting,
      ),
    );
  }
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
