import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_repeat.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_se_row_visual.dart' show layerKindUsesSeSheetCells;

/// One DRAWING row's frame cells as a single painter (UI-R9 #12b, the
/// hybrid painterization): the dense, mostly-static cell strip — paper
/// blocks, borders, glyphs, ghost dim, band tints — is pure canvas work,
/// so the per-cell widget pipeline (Element + RenderObject + InkWell +
/// Material ink + Semantics per cell) disappears for the rows that carry
/// hundreds of cells. Sparse interactive chrome (edge grips, run handles,
/// the range gesture layer, the cursor layer) stays widgets ON TOP.
///
/// The visual contract mirrors [TimelineFrameCell] exactly — that widget
/// remains the renderer for the sparse row kinds (SE / instruction /
/// camera).
class TimelineRowCellModel {
  const TimelineRowCellModel({
    required this.frameIndex,
    required this.exposureState,
    required this.segment,
    required this.ghost,
    required this.dimmed,
    required this.glyph,
    required this.semanticsLabel,
  });

  final int frameIndex;
  final TimelineCellExposureState exposureState;
  final TimelineExposureBlockVisualSegment segment;
  final bool ghost;
  final bool dimmed;

  /// The text drawn in the cell ('' when none / too narrow).
  final String glyph;
  final String? semanticsLabel;
}

/// Glyph TextPainters are cached per (text, color, weight, base style):
/// frame numbers and markers repeat heavily across rows and repaints.
final Map<Object, TextPainter> _glyphPainterCache = <Object, TextPainter>{};
const int _glyphPainterCacheCap = 512;

TextPainter _glyphPainter(String text, TextStyle style) {
  final key = (text, style.color, style.fontWeight, style.fontSize);
  final cached = _glyphPainterCache.remove(key);
  if (cached != null) {
    _glyphPainterCache[key] = cached; // LRU touch.
    return cached;
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  if (_glyphPainterCache.length >= _glyphPainterCacheCap) {
    _glyphPainterCache.remove(_glyphPainterCache.keys.first);
  }
  _glyphPainterCache[key] = painter;
  return painter;
}

class TimelineRowCellsPainter extends CustomPainter {
  TimelineRowCellsPainter({
    required this.layer,
    required this.active,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.colorScheme,
    required this.baseTextStyle,
    this.axis = Axis.horizontal,
    this.framesPerSecond = 24,
  });

  final Layer layer;
  final bool active;
  final int playbackFrameCount;

  /// The 24f strong line's period (UI-R10 #26).
  final int framesPerSecond;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double frameCellExtent;
  final double crossAxisExtent;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ColorScheme colorScheme;

  /// The ambient text style the widget cells inherited (DefaultTextStyle);
  /// glyphs merge color/weight onto it so painted text matches exactly.
  final TextStyle baseTextStyle;
  final Axis axis;

  TimelineCellExposureState _stateAt(int frameIndex) =>
      exposureStateForLayer(layer, frameIndex);

  /// The cell's rect in the ROW's local coordinates — the probe geometry
  /// tests and the row's hit-testing share (single source of truth).
  Rect cellRectFor(int frameIndex) {
    final main =
        leadingFrameSpacerWidth +
        (frameIndex - frameStartIndex) * frameCellExtent;
    return axis == Axis.horizontal
        ? Rect.fromLTWH(main, 0, frameCellExtent, crossAxisExtent)
        : Rect.fromLTWH(0, main, crossAxisExtent, frameCellExtent);
  }

  /// The frame index under a row-local position (the row Listener's
  /// pointer-down select); clamped non-negative.
  int frameIndexAt(Offset localPosition) {
    final main = axis == Axis.horizontal ? localPosition.dx : localPosition.dy;
    final cell = ((main - leadingFrameSpacerWidth) / frameCellExtent).floor();
    final frame = frameStartIndex + cell;
    return frame < 0 ? 0 : frame;
  }

  /// The cell state with ghost coverage READ AS EMPTY — ghosts render
  /// text-only (UI-R10 #11), so block-segment math and cell chrome treat
  /// them as uncovered cells.
  TimelineCellExposureState _chromeStateAt(int frameIndex) =>
      timelineIndexIsGhost(layer, frameIndex)
      ? TimelineCellExposureState.uncovered
      : _stateAt(frameIndex);

  /// The resolved per-cell model — THE probe surface for tests (glyphs,
  /// dim/ghost flags, exposure states live here, not in widget trees).
  TimelineRowCellModel cellModelAt(int frameIndex) {
    final exposureState = _stateAt(frameIndex);
    final ghost = timelineIndexIsGhost(layer, frameIndex);
    final outsidePlaybackRange = frameIndex >= playbackFrameCount;
    final previous = frameIndex == 0 ? null : _stateAt(frameIndex - 1);
    final emptyRunStart = timelineEmptyRunStartsAt(
      current: exposureState,
      previous: previous,
    );
    final frameName = frameNameForLayer?.call(layer, frameIndex);
    String glyph;
    if (frameCellExtent < 14) {
      glyph = '';
    } else if (ghost) {
      // Ghosts are TEXT-ONLY (UI-R10 #11): a hold ghost strings ㅡ dashes
      // through its span; a repeat ghost prints just the cel names.
      final mode = runBehaviorOwningGhostAt(layer, frameIndex)?.mode;
      glyph = mode == TimelineRunEdgeMode.hold
          ? 'ㅡ'
          : switch (exposureState) {
              TimelineCellExposureState.drawingStart =>
                frameName == null || frameName.isEmpty ? '○' : frameName,
              TimelineCellExposureState.markHeld ||
              TimelineCellExposureState.markUncovered => '●',
              _ => '',
            };
    } else {
      glyph = _marker(
        exposureState: exposureState,
        emptyRunStart: emptyRunStart,
        outsidePlaybackRange: outsidePlaybackRange,
        frameName: frameName,
      );
    }
    return TimelineRowCellModel(
      frameIndex: frameIndex,
      exposureState: exposureState,
      segment: calculateTimelineExposureBlockVisualSegment(
        previous: frameIndex == 0 ? null : _chromeStateAt(frameIndex - 1),
        current: _chromeStateAt(frameIndex),
        next: _chromeStateAt(frameIndex + 1),
      ),
      ghost: ghost,
      dimmed: outsidePlaybackRange || ghost,
      glyph: glyph,
      semanticsLabel: _semanticsLabel(
        exposureState: exposureState,
        frameName: frameName,
      ),
    );
  }

  String _marker({
    required TimelineCellExposureState exposureState,
    required bool emptyRunStart,
    required bool outsidePlaybackRange,
    String? frameName,
  }) {
    // The drawing-row half of TimelineFrameCell's marker table (SE /
    // instruction / camera rows keep the widget renderer).
    return switch (exposureState) {
      TimelineCellExposureState.uncovered =>
        outsidePlaybackRange || !emptyRunStart ? '' : 'X',
      TimelineCellExposureState.drawingStart =>
        frameName == null || frameName.isEmpty ? '○' : frameName,
      TimelineCellExposureState.held => '',
      TimelineCellExposureState.markHeld ||
      TimelineCellExposureState.markUncovered => '●',
    };
  }

  String? _semanticsLabel({
    required TimelineCellExposureState exposureState,
    String? frameName,
  }) {
    return switch (exposureState) {
      TimelineCellExposureState.uncovered => null,
      TimelineCellExposureState.drawingStart =>
        frameName == null || frameName.isEmpty
            ? 'drawing start'
            : 'drawing start $frameName',
      TimelineCellExposureState.held => 'held exposure',
      TimelineCellExposureState.markHeld ||
      TimelineCellExposureState.markUncovered => 'inbetween mark',
    };
  }

  /// The cell's RESOLVED paint style (dim blends, band tint, block
  /// radius) — what paint() draws and what tests assert against (the
  /// successor of reading the widget cell's BoxDecoration).
  ({Color background, Color border, BorderRadius? radius}) resolvedCellStyleFor(
    int frameIndex,
  ) {
    final model = cellModelAt(frameIndex);
    // Ghosts carry NO block chrome (UI-R10 #11): the cell paints as plain
    // empty paper and only the dimmed glyph marks the derived exposure.
    final styleColors = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: model.ghost
          ? TimelineCellExposureState.uncovered
          : model.exposureState,
      active: active,
      selected: false,
    );
    final washDim = model.ghost
        ? frameIndex >= playbackFrameCount
        : model.dimmed;
    // The base cell grid draws LIGHTER than the blocks (UI-R10 #26 — the
    // 6f/24f line system carries the rhythm instead of the old band
    // tint); block cells keep their full border.
    final baseBorder = model.segment.isBlock
        ? styleColors.border
        : styleColors.border.withValues(alpha: 0.45);
    return (
      background: washDim
          ? Color.alphaBlend(
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
              styleColors.background,
            )
          : styleColors.background,
      border: washDim
          ? Color.alphaBlend(
              colorScheme.outlineVariant.withValues(alpha: 0.55),
              baseBorder,
            )
          : baseBorder,
      radius: _cellRadius(model.segment),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fillPaint = Paint();

    for (
      var frameIndex = frameStartIndex;
      frameIndex < frameEndIndexExclusive;
      frameIndex += 1
    ) {
      final model = cellModelAt(frameIndex);
      final style = resolvedCellStyleFor(frameIndex);
      final background = style.background;
      final borderColor = style.border;

      final rect = cellRectFor(frameIndex);
      // Border.all paints INSIDE the box: stroke centered half a pixel in.
      final borderRect = rect.deflate(0.5);
      final radius = style.radius;
      if (radius == null) {
        canvas.drawRect(rect, fillPaint..color = background);
        canvas.drawRect(borderRect, borderPaint..color = borderColor);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: radius.topLeft,
            topRight: radius.topRight,
            bottomLeft: radius.bottomLeft,
            bottomRight: radius.bottomRight,
          ),
          fillPaint..color = background,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            borderRect,
            topLeft: radius.topLeft,
            topRight: radius.topRight,
            bottomLeft: radius.bottomLeft,
            bottomRight: radius.bottomRight,
          ),
          borderPaint..color = borderColor,
        );
      }

      if (model.glyph.isEmpty) {
        continue;
      }
      final isEmptyX =
          model.exposureState == TimelineCellExposureState.uncovered;
      final holdDash = model.ghost && model.glyph == 'ㅡ';
      final ink = holdDash
          // Hold ghost dashes read as one continuous dim string — no
          // start-cell emphasis (UI-R10 #11).
          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
          : timelineCellUsesDrawingInk(model.exposureState)
          ? (model.dimmed
                ? timelineDrawingInkColor.withValues(alpha: 0.55)
                : timelineDrawingInkColor)
          : isEmptyX
          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
          : model.dimmed
          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
          : colorScheme.onSurface;
      final glyphStyle = baseTextStyle.copyWith(
        color: ink,
        fontWeight:
            !holdDash &&
                !isEmptyX &&
                model.exposureState != TimelineCellExposureState.held
            ? FontWeight.bold
            : baseTextStyle.fontWeight,
      );
      final glyph = _glyphPainter(model.glyph, glyphStyle);
      glyph.paint(
        canvas,
        rect.center - Offset(glyph.width / 2, glyph.height / 2),
      );
    }

    // The 6f/24f line system (UI-R10 #26, KGB-sheet convention): a medium
    // line every 6 frames, a strong one on second boundaries — drawn over
    // the lightened cell grid, per row so they read continuous down the
    // grid.
    final sixPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1;
    final secondPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1.2;
    final firstBoundary = ((frameStartIndex + 5) ~/ 6) * 6;
    for (
      var frameIndex = firstBoundary;
      frameIndex <= frameEndIndexExclusive;
      frameIndex += 6
    ) {
      final rect = cellRectFor(frameIndex);
      final paint = frameIndex % framesPerSecond == 0
          ? secondPaint
          : sixPaint;
      if (axis == Axis.horizontal) {
        canvas.drawLine(
          Offset(rect.left, 0),
          Offset(rect.left, crossAxisExtent),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(0, rect.top),
          Offset(crossAxisExtent, rect.top),
          paint,
        );
      }
    }
  }

  BorderRadius? _cellRadius(TimelineExposureBlockVisualSegment segment) {
    if (!segment.isBlock) {
      return null;
    }
    const blockRadius = Radius.circular(6);
    final startRadius = segment.continuesFromPrevious
        ? Radius.zero
        : blockRadius;
    final endRadius = segment.continuesToNext ? Radius.zero : blockRadius;
    return switch (axis) {
      Axis.horizontal => BorderRadius.horizontal(
        left: startRadius,
        right: endRadius,
      ),
      Axis.vertical => BorderRadius.vertical(
        top: startRadius,
        bottom: endRadius,
      ),
    };
  }

  @override
  bool shouldRepaint(covariant TimelineRowCellsPainter oldDelegate) =>
      !identical(oldDelegate.layer, layer) ||
      oldDelegate.active != active ||
      oldDelegate.playbackFrameCount != playbackFrameCount ||
      oldDelegate.frameStartIndex != frameStartIndex ||
      oldDelegate.frameEndIndexExclusive != frameEndIndexExclusive ||
      oldDelegate.leadingFrameSpacerWidth != leadingFrameSpacerWidth ||
      oldDelegate.frameCellExtent != frameCellExtent ||
      oldDelegate.crossAxisExtent != crossAxisExtent ||
      oldDelegate.axis != axis ||
      oldDelegate.framesPerSecond != framesPerSecond ||
      !identical(oldDelegate.colorScheme, colorScheme) ||
      !identical(oldDelegate.exposureStateForLayer, exposureStateForLayer) ||
      !identical(oldDelegate.frameNameForLayer, frameNameForLayer);

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    // One semantics node per NON-EMPTY cell (labels only where content
    // exists) — the per-cell widget tree used to emit these; the painted
    // rows keep the a11y surface without the widget cost.
    final nodes = <CustomPainterSemantics>[];
    for (
      var frameIndex = frameStartIndex;
      frameIndex < frameEndIndexExclusive;
      frameIndex += 1
    ) {
      final label = cellModelAt(frameIndex).semanticsLabel;
      if (label == null) {
        continue;
      }
      nodes.add(
        CustomPainterSemantics(
          rect: cellRectFor(frameIndex),
          properties: SemanticsProperties(
            label: label,
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    }
    return nodes;
  };
}

/// Whether [kind]'s row paints its cells through [TimelineRowCellsPainter]
/// (the dense drawing rows); the sparse kinds (SE / instruction / camera)
/// keep the per-cell widget renderer with its overlays.
bool timelineRowUsesCellsPainter(LayerKind kind) =>
    layerKindHoldsDrawings(kind) &&
    !layerKindUsesSeSheetCells(kind) &&
    kind != LayerKind.camera;

/// The painted cell strip + its row-level interaction, shared by the
/// horizontal row and the X-sheet column (Axis policy):
/// - raw pointer-down selects the cell under the pointer (instant, the
///   arena never delays it — the TimelineFrameCell contract);
/// - a no-op onTap keeps a tap recognizer in the arena so scroll slop
///   over cells behaves exactly as the widget cells did;
/// - double-tap opens the cell editor.
Widget timelineRowCellsPaintArea({
  required BuildContext context,
  required String keyPrefix,
  required Layer layer,
  required bool active,
  required int playbackFrameCount,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double trailingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required Axis axis,
  int framesPerSecond = 24,
  required TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer,
  String? Function(Layer layer, int frameIndex)? frameNameForLayer,
  required ValueChanged<LayerId> onSelectLayer,
  required ValueChanged<int> onSelectFrame,
  void Function(LayerId layerId, int frameIndex)? onActivateCell,
}) {
  final painter = TimelineRowCellsPainter(
    layer: layer,
    active: active,
    playbackFrameCount: playbackFrameCount,
    frameStartIndex: frameStartIndex,
    frameEndIndexExclusive: frameEndIndexExclusive,
    leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    frameCellExtent: frameCellExtent,
    crossAxisExtent: crossAxisExtent,
    exposureStateForLayer: exposureStateForLayer,
    frameNameForLayer: frameNameForLayer,
    colorScheme: Theme.of(context).colorScheme,
    baseTextStyle: DefaultTextStyle.of(context).style,
    axis: axis,
    framesPerSecond: framesPerSecond,
  );
  final totalMainExtent =
      leadingFrameSpacerWidth +
      (frameEndIndexExclusive - frameStartIndex) * frameCellExtent +
      trailingFrameSpacerWidth;
  bool inWindow(int frameIndex) =>
      frameIndex >= frameStartIndex && frameIndex < frameEndIndexExclusive;
  void select(int frameIndex) {
    onSelectLayer(layer.id);
    onSelectFrame(frameIndex);
  }

  return Listener(
    // Selection rides the raw pointer down (never the arena — see the
    // TimelineFrameCell latency note).
    onPointerDown: (event) {
      if (event.buttons == 0 || (event.buttons & kPrimaryButton) != 0) {
        final frameIndex = painter.frameIndexAt(event.localPosition);
        if (inWindow(frameIndex)) {
          select(frameIndex);
        }
      }
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onDoubleTapDown: onActivateCell == null
          ? null
          : (details) {
              final frameIndex = painter.frameIndexAt(details.localPosition);
              if (inWindow(frameIndex)) {
                select(frameIndex);
                onActivateCell(layer.id, frameIndex);
              }
            },
      onDoubleTap: onActivateCell == null ? null : () {},
      child: RepaintBoundary(
        child: SizedBox(
          width: axis == Axis.horizontal ? totalMainExtent : crossAxisExtent,
          height: axis == Axis.horizontal ? crossAxisExtent : totalMainExtent,
          child: CustomPaint(
            key: ValueKey<String>('$keyPrefix-row-cells-${layer.id}'),
            painter: painter,
          ),
        ),
      ),
    ),
  );
}
