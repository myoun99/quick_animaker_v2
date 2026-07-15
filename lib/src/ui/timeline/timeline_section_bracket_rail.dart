import 'package:flutter/material.dart';

import '../../models/layer_kind.dart';
import '../widgets/panel_flyout.dart';
import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_section_policy.dart';
import 'timeline_section_runs.dart';
import 'upright_vertical_text.dart';

/// The section flyout's commands (host-wired; null leaves the rail
/// display-only, the pre-R-toolbar behavior).
class TimelineSectionRailCallbacks {
  const TimelineSectionRailCallbacks({
    required this.onToggleSection,
    required this.onAddLayerOfKind,
    required this.onSetSectionLayersVisibility,
    required this.onSoloSection,
  });

  /// Folds/unfolds a hideable section (the shared hiddenSections state).
  final ValueChanged<TimelineSection> onToggleSection;

  /// Adds a layer of the section's home kind.
  final ValueChanged<LayerKind> onAddLayerOfKind;

  /// Shows/hides every layer belonging to the section.
  final void Function(TimelineSection section, bool visible)
  onSetSectionLayersVisibility;

  /// Folds every OTHER hideable section.
  final ValueChanged<TimelineSection> onSoloSection;
}

/// The section-bracket gutter beside the timeline rail: one enclosing
/// bracket cell per section run — the paper timesheet's ACTION/SE/CAMERA
/// group heading wrapping its columns, laid along the layer axis. Labels
/// are written the paper way: upright glyphs stacked top-to-bottom (never
/// rotated).
///
/// R-toolbar round: tapping the bracket opens the section flyout (fold /
/// add layer here / solo / section-wide eye). Unfolding a hidden section
/// lives on the legend corner and the Layer ▾ menu — a folded section has
/// no bracket.
///
/// UI-R3 feedback #5/#6: the bracket draws NO box of its own — just a
/// bottom hairline landing exactly on the section's last row boundary and
/// the shared right-edge divider, so the gutter and the layer rows read as
/// ONE table (and the old top fold chevron is gone; folding lives in the
/// section flyout).
class TimelineSectionBracketRail extends StatelessWidget {
  const TimelineSectionBracketRail({
    super.key,
    required this.rows,
    required this.metrics,
    this.callbacks,
  });

  final List<TimelineDisplayRow> rows;
  final TimelineGridMetrics metrics;
  final TimelineSectionRailCallbacks? callbacks;

  /// The kind the section's 'Add layer here' creates.
  static LayerKind sectionHomeKind(TimelineSection section) {
    return switch (section) {
      TimelineSection.drawing => LayerKind.animation,
      TimelineSection.se => LayerKind.se,
      // The camera itself is one-per-cut; the section's addable rows are
      // instructions.
      TimelineSection.camera => LayerKind.instruction,
    };
  }

  List<PanelFlyoutEntry> _sectionEntries(TimelineSection section) {
    final callbacks = this.callbacks!;
    final name = section.name;
    return [
      PanelFlyoutHeader(timelineSectionLabel(section)),
      if (timelineSectionHideable(section))
        PanelFlyoutItem(
          keyValue: 'section-flyout-fold-$name',
          label: 'Fold section',
          icon: Icons.unfold_less,
          onSelected: () => callbacks.onToggleSection(section),
        ),
      PanelFlyoutItem(
        keyValue: 'section-flyout-add-$name',
        label: 'Add layer here',
        icon: Icons.add,
        onSelected: () => callbacks.onAddLayerOfKind(sectionHomeKind(section)),
      ),
      PanelFlyoutItem(
        keyValue: 'section-flyout-solo-$name',
        label: 'Only this section',
        icon: Icons.filter_center_focus,
        onSelected: () => callbacks.onSoloSection(section),
      ),
      const PanelFlyoutDivider(),
      PanelFlyoutItem(
        keyValue: 'section-flyout-show-$name',
        label: 'Show section layers',
        icon: Icons.visibility,
        onSelected: () => callbacks.onSetSectionLayersVisibility(section, true),
      ),
      PanelFlyoutItem(
        keyValue: 'section-flyout-hide-$name',
        label: 'Hide section layers',
        icon: Icons.visibility_off,
        onSelected: () =>
            callbacks.onSetSectionLayersVisibility(section, false),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (metrics.sectionLabelGutterWidth <= 0) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final runs = timelineSectionRuns(rows);
    final callbacks = this.callbacks;
    return SizedBox(
      width: metrics.sectionLabelGutterWidth,
      child: Column(
        children: [
          for (final run in runs)
            Builder(
              builder: (anchorContext) {
                final content = Container(
                  width: metrics.sectionLabelGutterWidth,
                  height: timelineSectionRunExtent(run, rows, metrics),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    // One shared table (R3 #5/#6): the bottom hairline sits
                    // on the run's last row boundary, the right hairline is
                    // the gutter/rail divider — no enclosing box.
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                      right: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Center(
                    child: ClipRect(
                      child: UprightVerticalText(
                        text: timelineSectionLabel(run.section),
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
                if (callbacks == null) {
                  return content;
                }
                return InkWell(
                  key: ValueKey<String>('section-bracket-${run.section.name}'),
                  onTap: () => showPanelFlyout(
                    anchorContext,
                    entries: _sectionEntries(run.section),
                  ),
                  child: content,
                );
              },
            ),
        ],
      ),
    );
  }
}
