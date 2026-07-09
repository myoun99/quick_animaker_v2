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
/// names stay column-aligned across rows.
const double layerTimesheetSlotWidth = 24;
const double layerMarkSlotWidth = 14;

/// Every layer kind carries the timesheet-output toggle — one entrance for
/// every row (unified layer controls, user rule): cel/art/SE gate their
/// sheet columns and the CAMERA layer gates the printed CAM column.
bool layerKindEligibleForTimesheetToggle(LayerKind kind) => true;

/// Every layer kind shows the opacity slider (unified layer controls —
/// "레이어는 싹 다 공통화"): compositing cels use it directly, the CAMERA
/// row's slider drives the camera-view DIM opacity, and instruction rows
/// carry the same control for entrance parity.
bool layerKindShowsOpacityControl(LayerKind kind) => true;

/// Which layer kinds show the fx switch: kinds whose transform/FX apply at
/// composite time. Grows with the kinds that gain transform lanes (SE and
/// instruction join with the all-kind transform work).
bool layerKindShowsFxToggle(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation || LayerKind.art || LayerKind.storyboard => true,
    LayerKind.se || LayerKind.instruction || LayerKind.camera => false,
  };
}

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
      width: 26,
      height: 26,
      child: IconButton(
        key: ValueKey<String>('$keyPrefix-layer-fx-$layerId'),
        tooltip: fxEnabled ? 'Bypass layer FX' : 'Apply layer FX',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
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
