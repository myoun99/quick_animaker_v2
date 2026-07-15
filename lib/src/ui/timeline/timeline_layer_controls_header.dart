import 'package:flutter/material.dart';

import '../../models/layer_mark.dart';
import '../theme/app_theme.dart';
import '../widgets/field_slider.dart';
import '../widgets/panel_flyout.dart';
import 'layer_label_controls.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_row_filter.dart';
import 'timeline_section_policy.dart';

/// A small 0–100% picker for the legend's inactive-dim and bulk-opacity
/// items (both numeric percentages). Commits on OK; cancel leaves state.
Future<void> _showValueDialog(
  BuildContext context, {
  required String title,
  required double initial,
  required ValueChanged<double> onCommit,
}) async {
  var value = initial.clamp(0.0, 1.0);
  final result = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      content: SizedBox(
        width: 240,
        child: StatefulBuilder(
          builder: (context, setState) => FieldSlider(
            key: const ValueKey<String>('legend-value-dialog-slider'),
            value: value,
            min: 0,
            max: 1,
            label: 'Value',
            valueText: '${(value * 100).round()}%',
            displayFactor: 100,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('legend-value-dialog-ok'),
          onPressed: () => Navigator.of(context).pop(value),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (result != null) {
    onCommit(result);
  }
}

/// The rail legend's bulk commands (session-backed; the host wires them).
/// Project-state sweeps (sheet/mark/fill-ref) land as ONE undo; the
/// view-ish ones (eye/mute/fx/opacity) mirror their per-row toggles. The
/// R2 filter/dim/bulk-opacity facets ride the same struct.
class LayerLegendCallbacks {
  const LayerLegendCallbacks({
    required this.onShowAllLayers,
    required this.onHideAllLayers,
    required this.onToggleVisibilitySolo,
    required this.onSheetAllOn,
    required this.onSheetAllOff,
    required this.onClearAllMarks,
    required this.onClearAllFillReferences,
    required this.onMuteAllSe,
    required this.onUnmuteAllSe,
    required this.onBypassAllFx,
    required this.onEnableAllFx,
    required this.onResetAllOpacity,
    required this.onToggleMarkFilter,
    required this.onToggleSheetOnlyFilter,
    required this.onToggleFxOnlyFilter,
    required this.onToggleFillReferenceOnlyFilter,
    required this.onSetInactiveDim,
    required this.onSetAllOpacity,
  });

  final VoidCallback onShowAllLayers;
  final VoidCallback onHideAllLayers;

  /// Toggles the visibility SOLO MODE (follows the active layer; R3
  /// feedback #3) — a mode switch, not a one-shot eye sweep.
  final VoidCallback onToggleVisibilitySolo;
  final VoidCallback onSheetAllOn;
  final VoidCallback onSheetAllOff;
  final VoidCallback onClearAllMarks;
  final VoidCallback onClearAllFillReferences;
  final VoidCallback onMuteAllSe;
  final VoidCallback onUnmuteAllSe;
  final VoidCallback onBypassAllFx;
  final VoidCallback onEnableAllFx;
  final VoidCallback onResetAllOpacity;

  /// R2 row-filter facet toggles.
  final ValueChanged<LayerMark> onToggleMarkFilter;
  final VoidCallback onToggleSheetOnlyFilter;
  final VoidCallback onToggleFxOnlyFilter;
  final VoidCallback onToggleFillReferenceOnlyFilter;

  /// The lighttable dim strength (0..1) and the numeric bulk-opacity set.
  final ValueChanged<double> onSetInactiveDim;
  final ValueChanged<double> onSetAllOpacity;
}

/// The rail header cell, reborn as the LEGEND (R-toolbar round): the wide
/// '+ Layer' button is gone — instead each control column gets an icon
/// lined up exactly over its slot (Excel-header reading), and clicking a
/// legend icon opens the shared flyout with that column's bulk commands.
/// The corner cell above the section gutter opens the sections flyout.
class TimelineLayerControlsHeader extends StatelessWidget {
  const TimelineLayerControlsHeader({
    super.key,
    required this.metrics,
    required this.onAddLayer,
    this.legend,
    this.hiddenSections = const {},
    this.onToggleSection,
    this.onCollapseAllLanes,
    this.onExpandAllLanes,
    this.rowFilter = TimelineRowFilter.none,
    this.marksInUse = const {},
    this.inactiveDimStrength = 0.0,
    this.visibilitySoloEnabled = false,
    this.anyLanesExpanded = false,
    this.allSeMuted = false,
  });

  final TimelineGridMetrics metrics;
  final VoidCallback onAddLayer;

  /// Null renders a display-only legend (no flyouts) — passive hosts.
  final LayerLegendCallbacks? legend;

  final Set<TimelineSection> hiddenSections;
  final ValueChanged<TimelineSection>? onToggleSection;

  /// The active row filter (for the legend flyouts' check marks).
  final TimelineRowFilter rowFilter;

  /// Marks currently assigned across the active cut's layers — the
  /// "show only color X" list is built from these (empty color set skipped).
  final Set<LayerMark> marksInUse;

  /// The lighttable dim strength (for the eye flyout's slider readout).
  final double inactiveDimStrength;

  /// Whether the visibility SOLO MODE is on (eye legend state color +
  /// flyout check).
  final bool visibilitySoloEnabled;

  /// Whether any layer's lanes are expanded — the lane-column header
  /// toggle folds/unfolds ALL layers based on this (R3 feedback #5).
  final bool anyLanesExpanded;

  /// Whether every SE row is muted — the mute legend cell is a direct
  /// all-SE toggle (R3 feedback #10), colored by this state.
  final bool allSeMuted;

  /// Grid-provided lane sweeps (the grid owns lane expansion knowledge).
  final VoidCallback? onCollapseAllLanes;
  final VoidCallback? onExpandAllLanes;

  List<PanelFlyoutEntry> _sectionEntries() {
    return [
      const PanelFlyoutHeader('Sections'),
      PanelFlyoutItem(
        keyValue: 'legend-section-se',
        label: 'Show SE rows',
        icon: Icons.music_note_outlined,
        enabled: onToggleSection != null,
        checked: !hiddenSections.contains(TimelineSection.se),
        onSelected: () => onToggleSection?.call(TimelineSection.se),
      ),
      PanelFlyoutItem(
        keyValue: 'legend-section-camera',
        label: 'Show camera rows',
        icon: Icons.videocam_outlined,
        enabled: onToggleSection != null,
        checked: !hiddenSections.contains(TimelineSection.camera),
        onSelected: () => onToggleSection?.call(TimelineSection.camera),
      ),
    ];
  }

  List<PanelFlyoutEntry> _layerEntries() {
    return [
      PanelFlyoutItem(
        keyValue: 'legend-layer-add',
        label: 'Add layer',
        icon: Icons.add,
        onSelected: onAddLayer,
      ),
      const PanelFlyoutDivider(),
      PanelFlyoutItem(
        keyValue: 'legend-lanes-expand',
        label: 'Expand all lanes',
        icon: Icons.unfold_more,
        enabled: onExpandAllLanes != null,
        onSelected: onExpandAllLanes,
      ),
      PanelFlyoutItem(
        keyValue: 'legend-lanes-collapse',
        label: 'Collapse all lanes',
        icon: Icons.unfold_less,
        enabled: onCollapseAllLanes != null,
        onSelected: onCollapseAllLanes,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final legend = this.legend;

    Widget cell({
      required String keyValue,
      required double width,
      required String tooltip,
      required Widget child,
      List<PanelFlyoutEntry> Function()? entriesBuilder,
    }) {
      final content = Center(child: child);
      // The key stays on the cell whether or not it can open a flyout —
      // it's the column's stable address (legend alignment tests).
      if (entriesBuilder == null) {
        return SizedBox(
          key: ValueKey<String>(keyValue),
          width: width,
          child: Tooltip(message: tooltip, child: content),
        );
      }
      return SizedBox(
        width: width,
        child: Builder(
          builder: (anchorContext) => Tooltip(
            message: tooltip,
            child: InkWell(
              key: ValueKey<String>(keyValue),
              onTap: () =>
                  showPanelFlyout(anchorContext, entries: entriesBuilder()),
              child: content,
            ),
          ),
        ),
      );
    }

    // Legend icons read like the row toggles now (R3 feedback #2): GRAY at
    // rest, ACCENT while their column's display-solo/state is engaged.
    final restColor = colorScheme.onSurfaceVariant;
    Widget legendIcon(IconData icon, {bool engaged = false}) =>
        Icon(icon, size: 13, color: engaged ? AppColors.accent : restColor);

    return Container(
      width: metrics.layerControlsWidth,
      height: metrics.layerRowHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Corner over the section gutter: the sections flyout.
          cell(
            keyValue: 'legend-sections',
            width: metrics.sectionLabelGutterWidth,
            tooltip: 'Sections',
            entriesBuilder: _sectionEntries,
            child: Icon(
              Icons.view_agenda_outlined,
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colorScheme.outlineVariant,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // The lane column's header: fold/unfold EVERY layer's
                  // lanes in one tap (R3 feedback #5).
                  if (onExpandAllLanes != null && onCollapseAllLanes != null)
                    SizedBox(
                      width: layerLaneToggleSlotWidth,
                      child: Tooltip(
                        message: anyLanesExpanded
                            ? 'Collapse all layers'
                            : 'Expand all layers',
                        child: InkWell(
                          key: const ValueKey<String>('legend-lanes-toggle'),
                          onTap: anyLanesExpanded
                              ? onCollapseAllLanes
                              : onExpandAllLanes,
                          child: Center(
                            child: Icon(
                              anyLanesExpanded
                                  ? Icons.unfold_less
                                  : Icons.unfold_more,
                              size: 13,
                              color: restColor,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: layerLaneToggleSlotWidth),
                  cell(
                    keyValue: 'legend-sheet',
                    width: layerTimesheetSlotWidth,
                    tooltip: 'Timesheet column',
                    entriesBuilder: legend == null
                        ? null
                        : () => [
                            PanelFlyoutItem(
                              keyValue: 'legend-sheet-all-on',
                              label: 'All on timesheet',
                              icon: Icons.table_chart,
                              onSelected: legend.onSheetAllOn,
                            ),
                            PanelFlyoutItem(
                              keyValue: 'legend-sheet-all-off',
                              label: 'All off timesheet',
                              icon: Icons.table_chart_outlined,
                              onSelected: legend.onSheetAllOff,
                            ),
                            const PanelFlyoutDivider(),
                            PanelFlyoutItem(
                              keyValue: 'legend-filter-sheet',
                              label: 'Solo sheet-on rows',
                              icon: Icons.center_focus_strong_outlined,
                              checked: rowFilter.onTimesheetOnly,
                              onSelected: legend.onToggleSheetOnlyFilter,
                            ),
                          ],
                    child: legendIcon(
                      Icons.table_chart_outlined,
                      engaged: rowFilter.onTimesheetOnly,
                    ),
                  ),
                  const SizedBox(width: layerControlChipGap),
                  cell(
                    keyValue: 'legend-mark',
                    width: layerMarkSlotWidth,
                    tooltip: 'Mark column',
                    entriesBuilder: legend == null
                        ? null
                        : () => [
                            PanelFlyoutItem(
                              keyValue: 'legend-mark-clear',
                              label: 'Clear all marks',
                              icon: Icons.label_off_outlined,
                              onSelected: legend.onClearAllMarks,
                            ),
                            if (marksInUse.isNotEmpty) ...[
                              const PanelFlyoutDivider(),
                              const PanelFlyoutHeader('Solo color'),
                              for (final mark in LayerMark.values)
                                if (mark != LayerMark.none &&
                                    marksInUse.contains(mark))
                                  PanelFlyoutItem(
                                    keyValue: 'legend-filter-mark-${mark.name}',
                                    label: layerMarkDisplayName(mark),
                                    checked: rowFilter.markColors.contains(
                                      mark,
                                    ),
                                    onSelected: () =>
                                        legend.onToggleMarkFilter(mark),
                                  ),
                            ],
                          ],
                    child: legendIcon(
                      Icons.label_outline,
                      engaged: rowFilter.markColors.isNotEmpty,
                    ),
                  ),
                  const SizedBox(width: layerControlChipGap),
                  Expanded(
                    child: Builder(
                      builder: (anchorContext) => InkWell(
                        key: const ValueKey<String>('legend-layer'),
                        onTap: () => showPanelFlyout(
                          anchorContext,
                          entries: _layerEntries(),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'LAYER ▾',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  cell(
                    keyValue: 'legend-fill-ref',
                    width: layerFillReferenceSlotWidth,
                    tooltip: 'Fill reference column',
                    entriesBuilder: legend == null
                        ? null
                        : () => [
                            PanelFlyoutItem(
                              keyValue: 'legend-fill-ref-clear',
                              label: 'Clear all fill references',
                              icon: Icons.format_color_reset_outlined,
                              onSelected: legend.onClearAllFillReferences,
                            ),
                            const PanelFlyoutDivider(),
                            PanelFlyoutItem(
                              keyValue: 'legend-filter-fill-ref',
                              label: 'Solo fill references',
                              icon: Icons.center_focus_strong_outlined,
                              checked: rowFilter.fillReferenceOnly,
                              onSelected:
                                  legend.onToggleFillReferenceOnlyFilter,
                            ),
                          ],
                    child: legendIcon(
                      Icons.format_color_fill,
                      engaged: rowFilter.fillReferenceOnly,
                    ),
                  ),
                  cell(
                    keyValue: 'legend-fx',
                    width: layerFxSlotWidth,
                    tooltip: 'FX column',
                    entriesBuilder: legend == null
                        ? null
                        : () => [
                            PanelFlyoutItem(
                              keyValue: 'legend-fx-enable-all',
                              label: 'Apply all fx',
                              onSelected: legend.onEnableAllFx,
                            ),
                            PanelFlyoutItem(
                              keyValue: 'legend-fx-bypass-all',
                              label: 'Bypass all fx',
                              onSelected: legend.onBypassAllFx,
                            ),
                            const PanelFlyoutDivider(),
                            PanelFlyoutItem(
                              keyValue: 'legend-filter-fx',
                              label: 'Solo fx-on rows',
                              icon: Icons.center_focus_strong_outlined,
                              checked: rowFilter.fxOnly,
                              onSelected: legend.onToggleFxOnlyFilter,
                            ),
                          ],
                    child: Text(
                      'fx',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        color: rowFilter.fxOnly ? AppColors.accent : restColor,
                      ),
                    ),
                  ),
                  cell(
                    keyValue: 'legend-eye',
                    width: layerVisibilitySlotWidth,
                    tooltip: 'Visibility column',
                    entriesBuilder: legend == null
                        ? null
                        : () => [
                            PanelFlyoutItem(
                              keyValue: 'legend-eye-show-all',
                              label: 'Show all',
                              icon: Icons.visibility,
                              onSelected: legend.onShowAllLayers,
                            ),
                            PanelFlyoutItem(
                              keyValue: 'legend-eye-hide-all',
                              label: 'Hide all',
                              icon: Icons.visibility_off,
                              onSelected: legend.onHideAllLayers,
                            ),
                            PanelFlyoutItem(
                              keyValue: 'legend-eye-solo',
                              label: 'Solo active layer',
                              icon: Icons.center_focus_strong_outlined,
                              checked: visibilitySoloEnabled,
                              onSelected: legend.onToggleVisibilitySolo,
                            ),
                            const PanelFlyoutDivider(),
                            PanelFlyoutItem(
                              keyValue: 'legend-inactive-dim',
                              label: inactiveDimStrength > 0
                                  ? 'Inactive dim… '
                                        '(${(inactiveDimStrength * 100).round()}%)'
                                  : 'Inactive dim…',
                              icon: Icons.contrast,
                              checked: inactiveDimStrength > 0,
                              onSelected: () => _showValueDialog(
                                context,
                                title: 'Inactive layer dim',
                                initial: inactiveDimStrength,
                                onCommit: legend.onSetInactiveDim,
                              ),
                            ),
                          ],
                    child: legendIcon(
                      Icons.visibility_outlined,
                      engaged: visibilitySoloEnabled,
                    ),
                  ),
                  // The mute cell is a DIRECT all-SE toggle (R3 feedback
                  // #10): one tap mutes/unmutes every SE row, colored by
                  // the muted state — no flyout.
                  SizedBox(
                    width: layerMuteSlotWidth,
                    child: Tooltip(
                      message: allSeMuted ? 'Unmute all SE' : 'Mute all SE',
                      child: InkWell(
                        key: const ValueKey<String>('legend-mute'),
                        onTap: legend == null
                            ? null
                            : (allSeMuted
                                  ? legend.onUnmuteAllSe
                                  : legend.onMuteAllSe),
                        child: Center(
                          child: legendIcon(
                            allSeMuted
                                ? Icons.volume_off
                                : Icons.volume_up_outlined,
                            engaged: allSeMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  cell(
                    keyValue: 'legend-opacity',
                    width: layerOpacitySlotWidth,
                    tooltip: 'Opacity column',
                    entriesBuilder: legend == null
                        ? null
                        : () => [
                            PanelFlyoutItem(
                              keyValue: 'legend-opacity-reset',
                              label: 'Reset all to 100%',
                              icon: Icons.opacity,
                              onSelected: legend.onResetAllOpacity,
                            ),
                            PanelFlyoutItem(
                              keyValue: 'legend-opacity-set-all',
                              label: 'Set all to…',
                              icon: Icons.tune,
                              onSelected: () => _showValueDialog(
                                context,
                                title: 'Set all layers opacity',
                                initial: 1.0,
                                onCommit: legend.onSetAllOpacity,
                              ),
                            ),
                          ],
                    child: Text(
                      'OPAC',
                      style: TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
