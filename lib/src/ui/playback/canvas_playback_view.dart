import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/camera_pose.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/playback_quality.dart';
import 'canvas_playback_controller.dart';
import 'cut_frame_composite_cache.dart';
import 'playback_frame_painter.dart';
import 'playback_prerender_scheduler.dart';

/// The canvas panel's playback mode: cached composite frames drawn like a
/// program monitor (fit + letterbox), advancing with the controller's ticker.
///
/// Cache misses keep the last successfully displayed frame on screen (the
/// stale-frame policy the tile cache also uses) while a thin strip reports
/// warming progress. With the camera view enabled the frame is projected
/// through the cut's camera pose instead of shown in canvas space.
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
  });

  final CanvasPlaybackController controller;
  final CutFrameCompositeCache compositeCache;
  final PlaybackQuality Function() qualityOf;
  final ValueListenable<PrerenderProgress> prerenderProgress;
  final bool cameraViewEnabled;
  final CanvasSize cameraFrameSize;
  final CameraPose Function(Cut cut, int frameIndex) cameraPoseOf;

  @override
  State<CanvasPlaybackView> createState() => _CanvasPlaybackViewState();
}

class _CanvasPlaybackViewState extends State<CanvasPlaybackView>
    with SingleTickerProviderStateMixin {
  /// Our own clone of the last displayed composite: the cache may evict and
  /// dispose its image at any time, a clone shares the pixels but has an
  /// independent lifetime.
  ui.Image? _heldFrame;
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
      if (composite != null) {
        _heldFrame?.dispose();
        _heldFrame = composite.clone();
        _heldCanvasSize = position.cut.canvasSize;
      }
    }

    final cut = position?.cut;
    final canvasSize =
        cut?.canvasSize ?? _heldCanvasSize ?? widget.cameraFrameSize;

    return Stack(
      key: const ValueKey<String>('canvas-playback-view'),
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: PlaybackFramePainter(
            image: _heldCanvasSize == canvasSize ? _heldFrame : null,
            canvasSize: canvasSize,
            cameraPose: widget.cameraViewEnabled && cut != null && position != null
                ? widget.cameraPoseOf(cut, position.localFrameIndex)
                : null,
            cameraFrameSize: widget.cameraViewEnabled
                ? widget.cameraFrameSize
                : null,
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
    );
  }
}
