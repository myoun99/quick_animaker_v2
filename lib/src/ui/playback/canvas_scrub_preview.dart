import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/canvas_viewport.dart';
import '../../models/cut.dart';
import '../../models/playback_quality.dart';
import 'cut_frame_composite_cache.dart';
import 'playback_frame_painter.dart';

/// The canvas content while a ruler scrub is in flight: the frame under the
/// cursor straight from the composite cache, drawn IN CANVAS SPACE — the
/// scrub shows the editing view's picture moving through time, not the
/// playback presentation (no camera projection, no cut fade; the camera
/// FRAME overlay stays visible on top exactly like normal editing).
///
/// Cache misses keep the last displayed frame on screen (the playback
/// view's stale-frame policy); the release commit swaps back to the editing
/// canvas at the final frame.
class CanvasScrubPreview extends StatefulWidget {
  const CanvasScrubPreview({
    super.key = const ValueKey<String>('canvas-scrub-preview'),
    required this.frameCursor,
    required this.compositeCache,
    required this.cut,
    required this.qualityOf,
    this.viewport,
  });

  final ValueListenable<int> frameCursor;
  final CutFrameCompositeCache compositeCache;
  final Cut cut;
  final PlaybackQuality Function() qualityOf;

  /// The panel's live pan/zoom; identity when null.
  final CanvasViewport? viewport;

  @override
  State<CanvasScrubPreview> createState() => _CanvasScrubPreviewState();
}

class _CanvasScrubPreviewState extends State<CanvasScrubPreview> {
  /// Our own clone of the last displayed composite: the cache may evict and
  /// dispose its image at any time, a clone shares the pixels but has an
  /// independent lifetime.
  ui.Image? _heldFrame;

  /// The cache image the clone came from (identity only, may be disposed);
  /// cloning happens only when this changes, not on every cursor move.
  ui.Image? _heldSource;

  @override
  void initState() {
    super.initState();
    widget.frameCursor.addListener(_onCursorMoved);
  }

  @override
  void didUpdateWidget(covariant CanvasScrubPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.frameCursor, widget.frameCursor)) {
      oldWidget.frameCursor.removeListener(_onCursorMoved);
      widget.frameCursor.addListener(_onCursorMoved);
    }
  }

  @override
  void dispose() {
    widget.frameCursor.removeListener(_onCursorMoved);
    _heldFrame?.dispose();
    super.dispose();
  }

  void _onCursorMoved() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cut = widget.cut;
    // Over-end cursors (the endless runway) display the cut's last frame.
    final maxFrame = cut.duration > 0 ? cut.duration - 1 : 0;
    final frameIndex = widget.frameCursor.value.clamp(0, maxFrame);
    final composite = widget.compositeCache.validCompositeOrNull(
      cut: cut,
      frameIndex: frameIndex,
      quality: widget.qualityOf(),
    );
    if (composite != null && !identical(composite, _heldSource)) {
      _heldFrame?.dispose();
      _heldSource = composite;
      _heldFrame = composite.clone();
    }

    return SizedBox.expand(
      child: CustomPaint(
        painter: PlaybackFramePainter(
          image: _heldFrame,
          canvasSize: cut.canvasSize,
          viewport: widget.viewport,
        ),
      ),
    );
  }
}
