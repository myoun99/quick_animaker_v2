import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_coverage.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import '../audio/waveform_painter.dart';
import '../theme/app_theme.dart';
import 'dialogue_fit_text.dart';
import 'timeline_cell_style.dart';
import 'timeline_frame_coordinate_policy.dart';

/// SE rows reuse the drawing rows' white paper frame blocks (the cells
/// themselves paint the paper); this overlay adds the sheet's SE writing on
/// top: the speaker name in an accent box at the block start (only when
/// set) and the dialogue glyphs distributed evenly across the block, with
/// the audio waveform sandwiched between paper and text.

/// Whether rows of [kind] use the sheet-style SE rendering: cell glyphs and
/// X marks stay suppressed — the entry's writing comes from the row-level
/// span overlay instead.
bool layerKindUsesSeSheetCells(LayerKind kind) => kind == LayerKind.se;

/// Which layer kinds open the cell editor dialog on double tap: SE rows
/// edit their name/dialogue, instruction rows their FI/FO/PAN … events.
bool layerKindOpensCellEditorOnDoubleTap(LayerKind kind) {
  return kind == LayerKind.se || kind == LayerKind.instruction;
}

/// The name-box + fitted-dialogue overlays for every SE block intersecting
/// the visible window; mirrors [timelineRowBlockEdgeGrips]' windowing math.
List<Widget> timelineRowSeLabelOverlays({
  required Layer layer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required Axis axis,
  String keyPrefix = 'timeline',
}) {
  final overlays = <Widget>[];
  final blocks = drawingBlocks(layer.timeline);
  for (final block in blocks) {
    if (block.endIndexExclusive <= frameStartIndex ||
        block.startIndex >= frameEndIndexExclusive) {
      continue;
    }

    final blockStartOffset = frameVisibleX(
      frameIndex: block.startIndex,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final blockEndOffset = frameVisibleX(
      frameIndex: block.endIndexExclusive,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final mainExtent = blockEndOffset - blockStartOffset;
    String? dialogue;
    String? seName;
    for (final frame in layer.frames) {
      if (frame.id == block.frameId) {
        dialogue = frame.name;
        seName = frame.seName;
        break;
      }
    }

    final content = IgnorePointer(
      key: ValueKey<String>(
        '$keyPrefix-se-label-${layer.id}-${block.startIndex}',
      ),
      child: SeSpanVisual(
        axis: axis,
        dialogue: dialogue ?? '',
        seName: seName,
      ),
    );

    overlays.add(switch (axis) {
      Axis.horizontal => Positioned(
        left: blockStartOffset,
        top: 0,
        width: mainExtent,
        height: crossAxisExtent,
        child: content,
      ),
      Axis.vertical => Positioned(
        top: blockStartOffset,
        left: 0,
        height: mainExtent,
        width: crossAxisExtent,
        child: content,
      ),
    });
  }
  return overlays;
}

/// Waveform strips for an SE row's audio clips, painted ABOVE the paper
/// cells and BELOW the writing overlays (list them between the two in the
/// Stack). Clip length comes from the extracted peaks; clips whose peaks
/// are still extracting (or failed) draw nothing until the store notifies.
///
/// With [clipToBlocks] the waveform only shows INSIDE the row's drawing
/// blocks (one clipped window per clip × block intersection, envelope
/// buckets staying globally aligned); portions outside any block draw
/// nothing — a block without audio shows the fitted dialogue alone.
/// Right-click/long-press opens the removal menu.
List<Widget> timelineRowAudioOverlays({
  required Layer layer,
  required int frameStartIndex,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required Axis axis,
  required int fps,
  required AudioPeaks? Function(String filePath) audioPeaksFor,
  void Function(int clipIndex)? onRemoveClip,
  required Color color,
  List<TimelineDrawingBlock>? clipToBlocks,
  String keyPrefix = 'timeline',
}) {
  final overlays = <Widget>[];
  for (var index = 0; index < layer.audioClips.length; index += 1) {
    final clip = layer.audioClips[index];
    final peaks = audioPeaksFor(clip.filePath);
    if (peaks == null) {
      continue;
    }
    final clipEndExclusive = clip.startFrame + peaks.durationFrames(fps);

    final strip = _AudioClipStrip(
      peaks: peaks,
      fps: fps,
      pixelsPerFrame: frameCellExtent,
      axis: axis,
      color: color,
      onRemove: onRemoveClip == null ? null : () => onRemoveClip(index),
    );

    if (clipToBlocks == null) {
      final startOffset = frameVisibleX(
        frameIndex: clip.startFrame,
        frameStartIndex: frameStartIndex,
        frameCellWidth: frameCellExtent,
        leadingFrameSpacerWidth: leadingFrameSpacerWidth,
      );
      final mainExtent = (clipEndExclusive - clip.startFrame) * frameCellExtent;
      overlays.add(
        _positionedAudioWindow(
          key: ValueKey<String>('$keyPrefix-audio-clip-${layer.id}-$index'),
          axis: axis,
          startOffset: startOffset,
          mainExtent: mainExtent,
          crossAxisExtent: crossAxisExtent,
          leadingShift: 0,
          strip: strip,
        ),
      );
      continue;
    }

    for (final block in clipToBlocks) {
      final windowStart = clip.startFrame > block.startIndex
          ? clip.startFrame
          : block.startIndex;
      final windowEndExclusive = clipEndExclusive < block.endIndexExclusive
          ? clipEndExclusive
          : block.endIndexExclusive;
      if (windowEndExclusive <= windowStart) {
        continue;
      }
      final startOffset = frameVisibleX(
        frameIndex: windowStart,
        frameStartIndex: frameStartIndex,
        frameCellWidth: frameCellExtent,
        leadingFrameSpacerWidth: leadingFrameSpacerWidth,
      );
      overlays.add(
        _positionedAudioWindow(
          key: ValueKey<String>(
            '$keyPrefix-audio-clip-${layer.id}-$index-b${block.startIndex}',
          ),
          axis: axis,
          startOffset: startOffset,
          mainExtent: (windowEndExclusive - windowStart) * frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          leadingShift: (windowStart - clip.startFrame) * frameCellExtent,
          strip: strip,
        ),
      );
    }
  }
  return overlays;
}

/// One positioned waveform window: the full-length strip shifted back by
/// [leadingShift] inside a ClipRect, so a mid-clip window still shows the
/// globally aligned envelope.
Widget _positionedAudioWindow({
  required Key key,
  required Axis axis,
  required double startOffset,
  required double mainExtent,
  required double crossAxisExtent,
  required double leadingShift,
  required Widget strip,
}) {
  final windowed = leadingShift == 0 && axis == Axis.horizontal
      ? strip
      : ClipRect(
          child: OverflowBox(
            alignment: axis == Axis.horizontal
                ? Alignment.centerLeft
                : Alignment.topCenter,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: axis == Axis.horizontal
                  ? Offset(-leadingShift, 0)
                  : Offset(0, -leadingShift),
              child: SizedBox(
                width: axis == Axis.horizontal
                    ? mainExtent + leadingShift
                    : crossAxisExtent,
                height: axis == Axis.horizontal
                    ? crossAxisExtent
                    : mainExtent + leadingShift,
                child: strip,
              ),
            ),
          ),
        );
  return switch (axis) {
    Axis.horizontal => Positioned(
      key: key,
      left: startOffset,
      top: 0,
      width: mainExtent,
      height: crossAxisExtent,
      child: windowed,
    ),
    Axis.vertical => Positioned(
      key: key,
      top: startOffset,
      left: 0,
      height: mainExtent,
      width: crossAxisExtent,
      child: windowed,
    ),
  };
}

class _AudioClipStrip extends StatelessWidget {
  const _AudioClipStrip({
    required this.peaks,
    required this.fps,
    required this.pixelsPerFrame,
    required this.axis,
    required this.color,
    this.onRemove,
  });

  final AudioPeaks peaks;
  final int fps;
  final double pixelsPerFrame;
  final Axis axis;
  final Color color;
  final VoidCallback? onRemove;

  Future<void> _showRemoveMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & (overlay as RenderBox).size,
      ),
      items: const [
        PopupMenuItem<String>(
          key: ValueKey<String>('audio-clip-menu-remove'),
          value: 'remove',
          child: Text('Remove Audio'),
        ),
      ],
    );
    if (selected == 'remove') {
      onRemove?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final waveform = CustomPaint(
      painter: WaveformPainter(
        peaks: peaks,
        fps: fps,
        pixelsPerFrame: pixelsPerFrame,
        color: color,
        axis: axis,
      ),
    );
    if (onRemove == null) {
      return IgnorePointer(child: waveform);
    }
    // Only secondary-tap/long-press register — plain taps and double taps
    // keep falling through to the cells underneath.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) =>
          _showRemoveMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showRemoveMenu(context, details.globalPosition),
      child: waveform,
    );
  }
}

/// Main-axis extent of the SE name box (the accent strip at a block's
/// start, horizontal orientation).
const double seNameBoxExtent = 16;

/// The sheet's SE-entry writing — speaker name box (accent background,
/// only when the entry carries a name) + dialogue fitted across the span —
/// shared by the timeline rows, the X-sheet columns and the storyboard's
/// synced SE track. Paper comes from the cells underneath (or from
/// [SePaperSpan] where there are none); text is always ink on paper.
class SeSpanVisual extends StatelessWidget {
  const SeSpanVisual({
    super.key,
    required this.axis,
    required this.dialogue,
    this.seName,
  });

  final Axis axis;
  final String dialogue;
  final String? seName;

  @override
  Widget build(BuildContext context) {
    final seName = this.seName ?? '';
    return Flex(
      direction: axis,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (seName.isNotEmpty) _SeNameBox(axis: axis, name: seName),
        Expanded(
          child: DialogueFitText(
            text: dialogue,
            axis: axis,
            color: timelineDrawingInkColor,
          ),
        ),
      ],
    );
  }
}

class _SeNameBox extends StatelessWidget {
  const _SeNameBox({required this.axis, required this.name});

  final Axis axis;
  final String name;

  @override
  Widget build(BuildContext context) {
    // Upright glyph stack (paper-style vertical writing), never rotated.
    final glyphStack = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final glyph in name.characters)
          Text(
            glyph,
            style: const TextStyle(
              color: timelineDrawingInkColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
      ],
    );
    final box = Semantics(
      label: 'SE name $name',
      // Own node even where an ancestor would merge labels (the dialog
      // preview) — tests and screen readers address the box directly.
      container: true,
      child: Container(
        color: AppColors.accent.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: ClipRect(child: ExcludeSemantics(child: glyphStack)),
      ),
    );
    return axis == Axis.horizontal
        ? SizedBox(width: seNameBoxExtent, child: box)
        : ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 72),
            child: box,
          );
  }
}

/// The paper frame block for hosts without paper cells underneath (the
/// storyboard's SE track): near-white fill, hairline outline, rounded ends
/// and a cell divider every [frameCellExtent] — visually the drawing rows'
/// block, painted as one span.
class SePaperSpan extends StatelessWidget {
  const SePaperSpan({
    super.key,
    required this.axis,
    required this.frameCellExtent,
  });

  final Axis axis;
  final double frameCellExtent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SePaperPainter(axis: axis, frameCellExtent: frameCellExtent),
      child: const SizedBox.expand(),
    );
  }
}

class _SePaperPainter extends CustomPainter {
  _SePaperPainter({required this.axis, required this.frameCellExtent});

  final Axis axis;
  final double frameCellExtent;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, Paint()..color = timelineDrawingHeldColor);

    canvas.save();
    canvas.clipRRect(rrect);
    final dividerPaint = Paint()
      ..color = timelineDrawingInkColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    final mainExtent = axis == Axis.horizontal ? size.width : size.height;
    if (frameCellExtent > 0) {
      for (var x = frameCellExtent; x < mainExtent - 0.5; x += frameCellExtent) {
        final (from, to) = axis == Axis.horizontal
            ? (Offset(x, 0), Offset(x, size.height))
            : (Offset(0, x), Offset(size.width, x));
        canvas.drawLine(from, to, dividerPaint);
      }
    }
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = timelineDrawingStartBorderColor,
    );
  }

  @override
  bool shouldRepaint(_SePaperPainter oldDelegate) {
    return axis != oldDelegate.axis ||
        frameCellExtent != oldDelegate.frameCellExtent;
  }
}
