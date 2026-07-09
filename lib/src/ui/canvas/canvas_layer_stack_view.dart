import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/playback_quality.dart';
import '../../models/transform_track.dart';
import '../playback/layer_frame_image_cache.dart';
import 'layer_pose_paint.dart';

/// One non-active layer to composite around the interactive canvas.
class CanvasLayerImageRequest {
  const CanvasLayerImageRequest({
    required this.frameKey,
    required this.opacity,
    this.pose,
  });

  final BrushFrameKey frameKey;
  final double opacity;

  /// The layer's transform at the shown frame; null = identity. The stack
  /// paints it exactly like the composite routes (the ACTIVE layer edits in
  /// artwork space — its own transform shows in playback/compose, not under
  /// the pen).
  final TransformPose? pose;
}

/// Paints the non-active layers of the editing canvas (below or above the
/// interactive layer) from the layer-frame image cache, under the panel
/// viewport transform.
///
/// This is what makes the OTHER layers visible while editing — the
/// interactive view renders only the active layer's surface. Visibility and
/// opacity toggles act here (hidden layers are simply not requested).
/// Paint-only: input always passes through to the canvas below.
class CanvasLayerStackView extends StatefulWidget {
  const CanvasLayerStackView({
    super.key,
    required this.layers,
    required this.imageCache,
    required this.canvasSize,
    required this.viewport,
    this.paintPaper = false,
  });

  /// Bottom → top.
  final List<CanvasLayerImageRequest> layers;

  final LayerFrameImageCache imageCache;
  final CanvasSize canvasSize;
  final CanvasViewport viewport;

  /// The below-stack paints the paper so the interactive view can skip its
  /// own opaque background.
  final bool paintPaper;

  @override
  State<CanvasLayerStackView> createState() => _CanvasLayerStackViewState();
}

class _CanvasLayerStackViewState extends State<CanvasLayerStackView> {
  /// Cache image identity → our clone. Clones survive cache eviction (the
  /// cache may dispose its image at any time; a clone shares pixels with an
  /// independent lifetime).
  final Map<BrushFrameKey, ({ui.Image source, ui.Image clone})> _images = {};
  bool _preparing = false;
  bool _rerunRequested = false;

  @override
  void initState() {
    super.initState();
    _ensureImages();
  }

  @override
  void didUpdateWidget(covariant CanvasLayerStackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureImages();
  }

  @override
  void dispose() {
    for (final entry in _images.values) {
      entry.clone.dispose();
    }
    _images.clear();
    super.dispose();
  }

  Future<void> _ensureImages() async {
    if (_preparing) {
      // A rebuild changed the request set mid-flight; run once more after
      // the current pass so the stack converges on the latest layers.
      _rerunRequested = true;
      return;
    }
    _preparing = true;
    try {
      do {
        _rerunRequested = false;
        var changed = false;
        final wanted = <BrushFrameKey>{};
        for (final layer in List.of(widget.layers)) {
          wanted.add(layer.frameKey);
          final image = await widget.imageCache.prepare(
            key: layer.frameKey,
            canvasSize: widget.canvasSize,
            quality: PlaybackQuality.full,
          );
          if (!mounted) {
            return;
          }
          final held = _images[layer.frameKey];
          if (image == null) {
            if (held != null) {
              held.clone.dispose();
              _images.remove(layer.frameKey);
              changed = true;
            }
            continue;
          }
          if (held == null || !identical(held.source, image)) {
            held?.clone.dispose();
            _images[layer.frameKey] = (source: image, clone: image.clone());
            changed = true;
          }
        }
        for (final key in _images.keys.toList()) {
          if (!wanted.contains(key)) {
            _images.remove(key)!.clone.dispose();
            changed = true;
          }
        }
        if (changed && mounted) {
          setState(() {});
        }
      } while (_rerunRequested && mounted);
    } finally {
      _preparing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _LayerStackPainter(
          images: [
            for (final layer in widget.layers)
              if (_images[layer.frameKey] != null)
                (
                  image: _images[layer.frameKey]!.clone,
                  opacity: layer.opacity,
                  pose: layer.pose,
                ),
          ],
          canvasSize: widget.canvasSize,
          viewport: widget.viewport,
          paintPaper: widget.paintPaper,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LayerStackPainter extends CustomPainter {
  const _LayerStackPainter({
    required this.images,
    required this.canvasSize,
    required this.viewport,
    required this.paintPaper,
  });

  final List<({ui.Image image, double opacity, TransformPose? pose})> images;
  final CanvasSize canvasSize;
  final CanvasViewport viewport;
  final bool paintPaper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(viewport.panX, viewport.panY);
    canvas.scale(viewport.zoom, viewport.zoom);

    final canvasRect = Rect.fromLTWH(
      0,
      0,
      canvasSize.width.toDouble(),
      canvasSize.height.toDouble(),
    );
    if (paintPaper) {
      canvas.drawRect(canvasRect, Paint()..color = const Color(0xFFEDEDED));
    }
    for (final layer in images) {
      // Layer transforms apply at composite time — the stack shows the
      // same picture playback composes (three-route parity).
      final layerPose = layer.pose;
      if (layerPose != null) {
        canvas.save();
        applyLayerPoseTransform(canvas, layerPose, canvasSize);
      }
      canvas.drawImageRect(
        layer.image,
        Rect.fromLTWH(
          0,
          0,
          layer.image.width.toDouble(),
          layer.image.height.toDouble(),
        ),
        canvasRect,
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Color.fromRGBO(0, 0, 0, layer.opacity.clamp(0.0, 1.0)),
      );
      if (layerPose != null) {
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LayerStackPainter oldDelegate) {
    if (oldDelegate.canvasSize != canvasSize ||
        oldDelegate.viewport != viewport ||
        oldDelegate.paintPaper != paintPaper ||
        oldDelegate.images.length != images.length) {
      return true;
    }
    for (var index = 0; index < images.length; index += 1) {
      if (!identical(oldDelegate.images[index].image, images[index].image) ||
          oldDelegate.images[index].opacity != images[index].opacity ||
          oldDelegate.images[index].pose != images[index].pose) {
        return true;
      }
    }
    return false;
  }
}
