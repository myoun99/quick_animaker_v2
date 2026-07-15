import 'package:flutter/material.dart';

import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_mark.dart';
import '../theme/app_theme.dart';

/// Layer-label chip controls shared by both timeline orientations
/// (horizontal rows and XSheet column headers): the timesheet-output toggle
/// and the TVPaint-style color mark. Keys take an orientation prefix
/// ('timeline' | 'xsheet') so tests address each surface.

/// Slot widths — non-eligible rows reserve the same space so kind icons and
/// names stay column-aligned across rows, and the rail's legend header
/// (R-toolbar round) lines its column icons up over these exact slots.
/// EVERY kind reserves EVERY slot (Excel-grid rule): slimmed from the old
/// 24/26/86 so the full set still fits the 312 rail.
/// Leading slot every rail row reserves for the INLINE section tag
/// (ACTION/SE/CAM on the section's first row — UI-R5, the bracket gutter
/// retired); the legend header's sections cell sits over the same slot.
const double layerSectionLabelSlotWidth = 36;

/// The rows' leading SECTION band (UI-R6 #5): a tinted vertical zone with
/// a right hairline spanning the row's full height — stacked rows read it
/// as one continuous column, the old gutter folded INSIDE the rows.
/// [child] carries the section label on a section's first row; every other
/// row renders the empty band.
class LayerSectionBandCell extends StatelessWidget {
  const LayerSectionBandCell({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: layerSectionLabelSlotWidth,
      height: double.infinity,
      padding: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

const double layerTimesheetSlotWidth = 20;
const double layerMarkSlotWidth = 14;
const double layerLaneToggleSlotWidth = 16;
const double layerFillReferenceSlotWidth = 22;
const double layerFxSlotWidth = 22;
const double layerVisibilitySlotWidth = 22;
const double layerMuteSlotWidth = 18;
const double layerOpacitySlotWidth = 64;
const double layerControlChipGap = 4;

/// Every layer kind carries the timesheet-output toggle — one entrance for
/// every row (unified layer controls, user rule): cel/art/SE gate their
/// sheet columns and the CAMERA layer gates the printed CAM column.
bool layerKindEligibleForTimesheetToggle(LayerKind kind) => true;

/// Every layer kind shows the opacity slider (unified layer controls —
/// "레이어는 싹 다 공통화"): compositing cels use it directly, the CAMERA
/// row's slider drives the camera-view DIM opacity, and instruction rows
/// carry the same control for entrance parity.
bool layerKindShowsOpacityControl(LayerKind kind) => true;

/// Every layer kind shows the fx switch (unified layer controls): drawing
/// cels and SE rows bypass their composite-time transform/opacity (SE fx
/// move the canvas dialogue), the CAMERA row bypasses the camera work on
/// the render routes (playback/export/thumbnails — authoring overlays
/// keep the real pose), and instruction rows carry the switch as authored
/// state for entrance parity.
bool layerKindShowsFxToggle(LayerKind kind) => true;

/// The AE-style layer fx switch: bypasses the layer's FX (transform +
/// animated opacity) on EVERY composite route while off — session view
/// state, not persisted.
class LayerFxToggleButton extends StatelessWidget {
  const LayerFxToggleButton({
    super.key,
    required this.keyPrefix,
    required this.layerId,
    required this.fxEnabled,
    required this.onToggle,
  });

  final String keyPrefix;
  final LayerId layerId;
  final bool fxEnabled;
  final ValueChanged<LayerId> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Tight SizedBox: the M3 IconButton otherwise inflates its layout box
    // to the 48px minimum tap target and overflows the row (same gotcha as
    // the timesheet toggle).
    return SizedBox(
      width: layerFxSlotWidth,
      height: 26,
      child: IconButton(
        key: ValueKey<String>('$keyPrefix-layer-fx-$layerId'),
        tooltip: fxEnabled ? 'Bypass layer FX' : 'Apply layer FX',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: layerFxSlotWidth,
          height: 26,
        ),
        icon: Text(
          'fx',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w700,
            color: fxEnabled
                ? AppColors.accent
                : colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
        onPressed: () => onToggle(layerId),
      ),
    );
  }
}

/// The row kind icon (shared by the rail rows and the legend's kind-solo
/// flyout, R4 #8).
IconData layerKindIcon(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation => Icons.brush_outlined,
    LayerKind.storyboard => Icons.auto_stories_outlined,
    LayerKind.art => Icons.landscape_outlined,
    LayerKind.se => Icons.music_note_outlined,
    LayerKind.instruction => Icons.theaters_outlined,
    LayerKind.camera => Icons.videocam_outlined,
  };
}

/// The kind's display name for the legend's kind-solo flyout.
String layerKindDisplayName(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation => 'Animation',
    LayerKind.storyboard => 'Storyboard',
    LayerKind.art => 'Art',
    LayerKind.se => 'SE',
    LayerKind.instruction => 'Instruction',
    LayerKind.camera => 'Camera',
  };
}

/// Chip color of [mark]; null for [LayerMark.none].
Color? layerMarkColor(LayerMark mark) {
  return switch (mark) {
    LayerMark.none => null,
    LayerMark.red => const Color(0xFFE05A4E),
    LayerMark.orange => const Color(0xFFE08D3C),
    LayerMark.yellow => const Color(0xFFE3C64B),
    LayerMark.green => const Color(0xFF7CB65B),
    LayerMark.teal => const Color(0xFF3FBFC9),
    LayerMark.blue => const Color(0xFF5B8DD9),
    LayerMark.purple => const Color(0xFF9B6BD3),
    LayerMark.pink => const Color(0xFFD972A8),
  };
}

String layerMarkDisplayName(LayerMark mark) {
  final name = mark.jsonValue;
  return name[0].toUpperCase() + name.substring(1);
}

class LayerTimesheetToggleButton extends StatelessWidget {
  const LayerTimesheetToggleButton({
    super.key,
    required this.keyPrefix,
    required this.layerId,
    required this.onTimesheet,
    required this.onToggle,
  });

  final String keyPrefix;
  final LayerId layerId;
  final bool onTimesheet;
  final ValueChanged<LayerId> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Tight SizedBox: the M3 IconButton otherwise inflates its layout box to
    // the 48px minimum tap target, overflowing the XSheet header column.
    return SizedBox(
      width: layerTimesheetSlotWidth,
      height: layerTimesheetSlotWidth,
      child: IconButton(
        key: ValueKey<String>('$keyPrefix-layer-timesheet-$layerId'),
        tooltip: onTimesheet ? 'Remove from timesheet' : 'Add to timesheet',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: layerTimesheetSlotWidth,
          height: layerTimesheetSlotWidth,
        ),
        icon: Icon(
          onTimesheet ? Icons.table_chart : Icons.table_chart_outlined,
          size: 16,
          color: onTimesheet
              ? AppColors.accent
              : colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        onPressed: () => onToggle(layerId),
      ),
    );
  }
}

class LayerMarkChip extends StatelessWidget {
  const LayerMarkChip({
    super.key,
    required this.keyPrefix,
    required this.layerId,
    required this.mark,
    required this.onMarkSelected,
  });

  final String keyPrefix;
  final LayerId layerId;
  final LayerMark mark;
  final void Function(LayerId layerId, LayerMark mark) onMarkSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LayerMark>(
      key: ValueKey<String>('$keyPrefix-layer-mark-$layerId'),
      tooltip: 'Layer mark',
      popUpAnimationStyle: instantMenuAnimation,
      padding: EdgeInsets.zero,
      onSelected: (selected) => onMarkSelected(layerId, selected),
      itemBuilder: (context) => [
        for (final option in LayerMark.values)
          PopupMenuItem<LayerMark>(
            key: ValueKey<String>('layer-mark-option-${option.jsonValue}'),
            value: option,
            height: 36,
            child: Row(
              children: [
                _MarkSwatch(mark: option),
                const SizedBox(width: 10),
                Text(layerMarkDisplayName(option)),
              ],
            ),
          ),
      ],
      child: Semantics(
        label: 'Layer mark',
        button: true,
        child: _MarkSwatch(mark: mark),
      ),
    );
  }
}

class _MarkSwatch extends StatelessWidget {
  const _MarkSwatch({required this.mark});

  final LayerMark mark;

  @override
  Widget build(BuildContext context) {
    final color = layerMarkColor(mark);
    return Container(
      width: layerMarkSlotWidth,
      height: layerMarkSlotWidth,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: color == null
            ? Border.all(color: AppColors.hairlineStrong)
            : null,
      ),
    );
  }
}
