import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../models/cut_id.dart';
import 'timeline_cut_end_handle.dart';
import 'timeline_drag_preview.dart';
import 'timeline_frame_header_row.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_ruler_cut_end_boundary.dart';

class TimelineFrameRuler extends StatelessWidget {
  const TimelineFrameRuler({
    super.key = const ValueKey<String>('timeline-frame-ruler'),
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
    required this.onSelectFrame,
    this.framesPerSecond = 24,
    this.showSeconds = false,
    this.windowBucket,
    this.viewportMainExtent = 0,
    this.dragPreview,
    this.previewCutId,
  });

  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;
  final int framesPerSecond;
  final bool showSeconds;
  /// PRO-TIMELINE scrolling (UI-R15→R16): the strip windows itself off
  /// the quantized bucket — pass the full bounds, repaint per crossing.
  final ValueListenable<int>? windowBucket;
  final double viewportMainExtent;

  /// End-line live follow (UI-R18 #14): while a trim drag targets
  /// [previewCutId], the ruler's boundary line rides the previewed
  /// duration so it never splits from the body's line. Null = static.
  final ValueListenable<TimelineDragPreview?>? dragPreview;
  final CutId? previewCutId;

  @override
  Widget build(BuildContext context) {
    final dragPreview = this.dragPreview;
    return Stack(
      children: [
        TimelineFrameHeaderRow(
          frameStartIndex: frameStartIndex,
          frameEndIndexExclusive: frameEndIndexExclusive,
          currentFrameIndex: currentFrameIndex,
          playbackFrameCount: playbackFrameCount,
          leadingFrameSpacerWidth: leadingFrameSpacerWidth,
          trailingFrameSpacerWidth: trailingFrameSpacerWidth,
          metrics: metrics,
          onSelectFrame: onSelectFrame,
          framesPerSecond: framesPerSecond,
          showSeconds: showSeconds,
          windowBucket: windowBucket,
          viewportMainExtent: viewportMainExtent,
        ),
        if (dragPreview != null && previewCutId != null)
          ValueListenableBuilder<TimelineDragPreview?>(
            valueListenable: dragPreview,
            builder: (context, preview, _) => TimelineRulerCutEndBoundary(
              left: timelineCutEndBoundaryX(
                playbackFrameCount: timelineCutEndPreviewFrameCount(
                  preview: preview,
                  cutId: previewCutId,
                  playbackFrameCount: playbackFrameCount,
                ),
                metrics: metrics,
              ),
            ),
          )
        else
          TimelineRulerCutEndBoundary(
            left: timelineCutEndBoundaryX(
              playbackFrameCount: playbackFrameCount,
              metrics: metrics,
            ),
          ),
      ],
    );
  }
}
