import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/panel_flyout.dart';
import 'layer_label_controls.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_section_policy.dart';

/// The rail legend's bulk commands (session-backed; the host wires them).
/// Project-state sweeps (sheet/mark/fill-ref) land as ONE undo; the
/// view-ish ones (eye/mute/fx/opacity) mirror their per-row toggles.
class LayerLegendCallbacks {
  const LayerLegendCallbacks({
    required this.onShowAllLayers,
    required this.onHideAllLayers,
    required this.onSoloActiveLayer,
    required this.onSheetAllOn,
    required this.onSheetAllOff,
    required this.onClearAllMarks,
    required this.onClearAllFillReferences,
    required this.onMuteAllSe,
    required this.onUnmuteAllSe,
    required this.onBypassAllFx,
    required this.onEnableAllFx,
    required this.onResetAllOpacity,
  });

  final VoidCallback onShowAllLayers;
  final VoidCallback onHideAllLayers;
  final VoidCallback onSoloActiveLayer;
  final VoidCallback onSheetAllOn;
  final VoidCallback onSheetAllOff;
  final VoidCallback onClearAllMarks;
  final VoidCallback onClearAllFillReferences;
  final VoidCallback onMuteAllSe;
  final VoidCallback onUnmuteAllSe;
  final VoidCallback onBypassAllFx;
  final VoidCallback onEnableAllFx;
  final VoidCallback onResetAllOpacity;
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
  });

  final TimelineGridMetrics metrics;
  final VoidCallback onAddLayer;

  /// Null renders a display-only legend (no flyouts) — passive hosts.
  final LayerLegendCallbacks? legend;

  final Set<TimelineSection> hiddenSections;
  final ValueChanged<TimelineSection>? onToggleSection;

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

    Widget legendIcon(IconData icon) =>
        Icon(icon, size: 13, color: AppColors.accent);

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
                          ],
                    child: legendIcon(Icons.table_chart_outlined),
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
                          ],
                    child: legendIcon(Icons.label_outline),
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
                          ],
                    child: legendIcon(Icons.format_color_fill),
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
                          ],
                    child: Text(
                      'fx',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
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
                              label: 'Active only (solo)',
                              icon: Icons.center_focus_strong_outlined,
                              onSelected: legend.onSoloActiveLayer,
                            ),
                          ],
                    child: legendIcon(Icons.visibility_outlined),
                  ),
                  cell(
                    keyValue: 'legend-mute',
                    width: layerMuteSlotWidth,
                    tooltip: 'SE mute column',
                    entriesBuilder: legend == null
                        ? null
                        : () => [
                            PanelFlyoutItem(
                              keyValue: 'legend-mute-all',
                              label: 'Mute all SE',
                              icon: Icons.volume_off,
                              onSelected: legend.onMuteAllSe,
                            ),
                            PanelFlyoutItem(
                              keyValue: 'legend-unmute-all',
                              label: 'Unmute all SE',
                              icon: Icons.volume_up,
                              onSelected: legend.onUnmuteAllSe,
                            ),
                          ],
                    child: legendIcon(Icons.volume_up_outlined),
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
