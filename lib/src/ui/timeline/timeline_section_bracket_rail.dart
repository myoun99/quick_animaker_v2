import 'package:flutter/material.dart';

import '../../models/layer_kind.dart';
import '../theme/app_theme.dart';
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
/// R-toolbar round: hideable sections grow a fold chevron at the bracket
/// top, and tapping the bracket opens the section flyout (fold / add layer
/// here / solo / section-wide eye). Unfolding a hidden section lives on the
/// legend corner and the Layer ▾ menu — a folded section has no bracket.
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
                    border: Border.all(color: colorScheme.outline, width: 1),
                  ),
                  child: Column(
                    children: [
                      // The chevron folds DIRECTLY (one tap); the rest of
                      // the bracket opens the section flyout.
                      if (callbacks != null &&
                          timelineSectionHideable(run.section))
                        InkWell(
                          key: ValueKey<String>(
                            'section-fold-${run.section.name}',
                          ),
                          onTap: () => callbacks.onToggleSection(run.section),
                          child: const SizedBox(
                            height: 14,
                            width: double.infinity,
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              size: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      Expanded(
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
                      ),
                    ],
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
