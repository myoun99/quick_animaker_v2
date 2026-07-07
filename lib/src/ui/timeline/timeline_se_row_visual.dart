import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/timeline_coverage.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import '../audio/waveform_painter.dart';
import 'timeline_frame_coordinate_policy.dart';

/// SE rows read like the paper sheet's SE column instead of cel blocks:
/// the entry's name/dialogue at its start, a duration line running to the
/// end of the covered run and a closing tick — no paper fill and no X
/// cells. One overlay per drawing block, shared by both orientations
/// (Axis policy), so long dialogue flows across held cells like on paper.

/// Whether rows of [kind] use the sheet-style SE rendering (label overlay +
/// duration line in place of paper blocks).
bool layerKindUsesSeSheetCells(LayerKind kind) => kind == LayerKind.se;

/// Which layer kinds open the cell editor dialog on double tap: SE rows
/// edit their name/dialogue, instruction rows their FI/FO/PAN … events.
bool layerKindOpensCellEditorOnDoubleTap(LayerKind kind) {
  return kind == LayerKind.se || kind == LayerKind.instruction;
}

/// The label + duration-line overlays for every SE block intersecting the
/// visible window; mirrors [timelineRowBlockEdgeGrips]' windowing math.
List<Widget> timelineRowSeLabelOverlays({
  required Layer layer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required Axis axis,
  required String? Function(Layer layer, int frameIndex)? frameNameForLayer,
  required Color textColor,
  required Color lineColor,
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
    final label = frameNameForLayer?.call(layer, block.startIndex) ?? '';

    final content = IgnorePointer(
      key: ValueKey<String>(
        '$keyPrefix-se-label-${layer.id}-${block.startIndex}',
      ),
      child: SeSpanVisual(
        axis: axis,
        label: label,
        textColor: textColor,
        lineColor: lineColor,
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

/// The sheet's SE-entry visual — label, duration line, closing tick —
/// shared by the timeline rows and the storyboard's synced SE track.
/// Waveform strips for an SE row's audio clips, painted BELOW the label
/// spans (list them earlier in the Stack). Clip length comes from the
/// extracted peaks; clips whose peaks are still extracting (or failed)
/// draw nothing until the store notifies. Right-click/long-press opens the
/// removal menu.
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
  String keyPrefix = 'timeline',
}) {
  final overlays = <Widget>[];
  for (var index = 0; index < layer.audioClips.length; index += 1) {
    final clip = layer.audioClips[index];
    final peaks = audioPeaksFor(clip.filePath);
    if (peaks == null) {
      continue;
    }
    final startOffset = frameVisibleX(
      frameIndex: clip.startFrame,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final mainExtent = peaks.durationFrames(fps) * frameCellExtent;

    final strip = _AudioClipStrip(
      key: ValueKey<String>('$keyPrefix-audio-clip-${layer.id}-$index'),
      peaks: peaks,
      fps: fps,
      pixelsPerFrame: frameCellExtent,
      axis: axis,
      color: color,
      onRemove: onRemoveClip == null ? null : () => onRemoveClip(index),
    );

    overlays.add(switch (axis) {
      Axis.horizontal => Positioned(
        left: startOffset,
        top: 0,
        width: mainExtent,
        height: crossAxisExtent,
        child: strip,
      ),
      Axis.vertical => Positioned(
        top: startOffset,
        left: 0,
        height: mainExtent,
        width: crossAxisExtent,
        child: strip,
      ),
    });
  }
  return overlays;
}

class _AudioClipStrip extends StatelessWidget {
  const _AudioClipStrip({
    super.key,
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

class SeSpanVisual extends StatelessWidget {
  const SeSpanVisual({
    super.key,
    required this.axis,
    required this.label,
    required this.textColor,
    required this.lineColor,
  });

  final Axis axis;
  final String label;
  final Color textColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Center(
        child: Container(
          width: axis == Axis.horizontal ? null : 1.6,
          height: axis == Axis.horizontal ? 1.6 : null,
          color: lineColor,
        ),
      ),
    );
    final endTick = Container(
      width: axis == Axis.horizontal ? 2 : 9,
      height: axis == Axis.horizontal ? 9 : 2,
      margin: axis == Axis.horizontal
          ? const EdgeInsets.only(right: 3)
          : const EdgeInsets.only(bottom: 3),
      color: lineColor,
    );

    return Flex(
      direction: axis,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (label.isNotEmpty)
          Flexible(
            child: Padding(
              padding: axis == Axis.horizontal
                  ? const EdgeInsets.symmetric(horizontal: 5)
                  : const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              child: ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        line,
        endTick,
      ],
    );
  }
}
