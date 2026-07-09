import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/camera_pose.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/cut.dart';
import '../../models/playback_quality.dart';
import '../storyboard_cut_fade_policy.dart';
import 'canvas_playback_controller.dart';
import 'cut_frame_composite_cache.dart';
import 'playback_frame_painter.dart';
import 'playback_prerender_scheduler.dart';

/// The canvas panel's playback content: cached composite frames advancing
/// with the controller's ticker, rendered INSIDE the panel viewport so the
/// panel chrome (zoom buttons, panbars) keeps working during playback.
///
/// Tapping anywhere cancels playback. Cache misses keep the last displayed
/// frame on screen (the stale-frame policy the tile cache also uses) while a
/// thin strip reports warming progress. With the camera view enabled the
/// frame is projected through the cut's camera pose instead of shown in
/// canvas space.
class CanvasPlaybackView extends StatefulWidget {
  const CanvasPlaybackView({
    super.key,
    required this.controller,
    required this.compositeCache,
    required this.qualityOf,
    required this.prerenderProgress,
    required this.cameraViewEnabled,
    required this.cameraFrameSize,
    required this.cameraPoseOf,
    this.viewport,
  });

  final CanvasPlaybackController controller;
  final CutFrameCompositeCache compositeCache;
  final PlaybackQuality Function() qualityOf;
  final ValueListenable<PrerenderProgress> prerenderProgress;
  final bool cameraViewEnabled;
  final CanvasSize cameraFrameSize;
  final CameraPose Function(Cut cut, int frameIndex) cameraPoseOf;

  /// The panel's live pan/zoom (canvas mode); identity when null.
  final CanvasViewport? viewport;

  @override
  State<CanvasPlaybackView> createState() => _CanvasPlaybackViewState();
}

// TickerProviderStateMixin (multi), NOT the single variant: the controller
// disposes and recreates its ticker on every pause/resume/seek, and a single
// ticker provider asserts after the first creation (pause → play was dead).
class _CanvasPlaybackViewState extends State<CanvasPlaybackView>
    with TickerProviderStateMixin {
  /// Our own clone of the last displayed composite: the cache may evict and
  /// dispose its image at any time, a clone shares the pixels but has an
  /// independent lifetime.
  ui.Image? _heldFrame;

  /// The cache image the clone came from (identity only, may be disposed);
  /// cloning happens only when this changes, not on every tick.
  ui.Image? _heldSource;
  CanvasSize? _heldCanvasSize;

  @override
  void initState() {
    super.initState();
    widget.controller.attachTicker(this);
    widget.controller.addListener(_onPlaybackChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPlaybackChanged);
    widget.controller.detachTicker();
    _heldFrame?.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.position;
    if (position != null) {
      final composite = widget.compositeCache.validCompositeOrNull(
        cut: position.cut,
        frameIndex: position.localFrameIndex,
        quality: widget.qualityOf(),
      );
      if (composite != null && !identical(composite, _heldSource)) {
        _heldFrame?.dispose();
        _heldSource = composite;
        _heldFrame = composite.clone();
        _heldCanvasSize = position.cut.canvasSize;
      }
    }

    final cut = position?.cut;
    final canvasSize =
        cut?.canvasSize ?? _heldCanvasSize ?? widget.cameraFrameSize;

    return GestureDetector(
      key: const ValueKey<String>('canvas-playback-view'),
      behavior: HitTestBehavior.opaque,
      // One tap anywhere on the canvas cancels playback.
      onTap: widget.controller.stop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: PlaybackFramePainter(
              image: _heldCanvasSize == canvasSize ? _heldFrame : null,
              canvasSize: canvasSize,
              viewport: widget.viewport,
              cameraPose:
                  widget.cameraViewEnabled && cut != null && position != null
                  ? widget.cameraPoseOf(cut, position.localFrameIndex)
                  : null,
              cameraFrameSize: widget.cameraViewEnabled
                  ? widget.cameraFrameSize
                  : null,
              // The cut fade: applied at display time, never baked into
              // the composite cache (it would shard entries per frame).
              fadeOpacity: cut != null && position != null
                  ? cut.fadeOpacityAt(position.localFrameIndex)
                  : 1,
              fadeColor: cut != null
                  ? cutFadeTargetColor(cut)
                  : const Color(0xFF000000),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<PrerenderProgress>(
              valueListenable: widget.prerenderProgress,
              builder: (context, progress, _) {
                if (progress.total == 0 || progress.isComplete) {
                  return const SizedBox.shrink();
                }
                return Column(
                  key: const ValueKey<String>('canvas-playback-progress'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'caching ${progress.cached}/${progress.total}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    LinearProgressIndicator(
                      value: progress.cached / progress.total,
                      minHeight: 2,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
