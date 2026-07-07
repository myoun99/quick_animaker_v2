import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/brush_frame_cache_invalidation.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../services/playback/editor_cache_invalidation_hub.dart';

/// Renders and caches the small first-frame composite each storyboard cut
/// block shows.
///
/// [thumbnailFor] is a synchronous build-time resolver: it returns whatever
/// is cached (possibly stale, possibly null) and kicks one async render at
/// thumbnail resolution when the cut's signature changed. Renders finish →
/// [notifyListeners] → the panel rebuilds with the fresh image.
///
/// Invalidation: a structural signature (canvas size, duration, per-layer
/// visibility/opacity/frames) plus a per-cut edit generation bumped by the
/// hub's brush-frame events (stroke commit / undo / redo). Deliberately NOT
/// covered: exposure-only timeline edits that swap which frame is exposed at
/// index 0 without touching the frames list — rare, and the next edit
/// refreshes the thumb.
class StoryboardCutThumbnailStore extends ChangeNotifier {
  StoryboardCutThumbnailStore({
    required Future<ui.Image?> Function(Cut cut) render,
    EditorCacheInvalidationHub? invalidationHub,
  }) : _render = render,
       _hub = invalidationHub {
    _hub?.addBrushFrameListener(_onBrushFrameInvalidated);
  }

  final Future<ui.Image?> Function(Cut cut) _render;
  final EditorCacheInvalidationHub? _hub;

  final Map<CutId, ui.Image> _images = {};
  final Map<CutId, String> _renderedSignatures = {};
  final Map<CutId, int> _editGenerations = {};
  final Set<CutId> _rendering = {};
  bool _disposed = false;

  /// The cached thumbnail for [cut]; kicks an async (re)render when the
  /// cut's content signature changed, returning the stale image meanwhile.
  ui.Image? thumbnailFor(Cut cut) {
    final signature = _signatureFor(cut);
    if (_renderedSignatures[cut.id] != signature &&
        !_rendering.contains(cut.id)) {
      _rendering.add(cut.id);
      _startRender(cut, signature);
    }
    return _images[cut.id];
  }

  void _startRender(Cut cut, String signature) {
    unawaited(
      _render(cut)
          .then((image) {
            _rendering.remove(cut.id);
            if (_disposed) {
              image?.dispose();
              return;
            }
            final previous = _images.remove(cut.id);
            if (previous != null) {
              _retire(previous);
            }
            if (image != null) {
              _images[cut.id] = image;
            }
            // A signature change DURING the render re-kicks on the rebuild
            // this notify triggers.
            _renderedSignatures[cut.id] = signature;
            notifyListeners();
          })
          .catchError((Object _) {
            _rendering.remove(cut.id);
          }),
    );
  }

  void _onBrushFrameInvalidated(BrushFrameCacheInvalidation invalidation) {
    final cutId = invalidation.frameKey.cutId;
    _editGenerations[cutId] = (_editGenerations[cutId] ?? 0) + 1;
    // Lazy refresh: no render here — the next thumbnailFor call (the panel
    // is only built in storyboard mode) sees the bumped signature.
  }

  String _signatureFor(Cut cut) {
    final buffer = StringBuffer()
      ..write(cut.canvasSize.width)
      ..write('x')
      ..write(cut.canvasSize.height)
      ..write('#')
      ..write(_editGenerations[cut.id] ?? 0)
      ..write('#')
      ..write(cut.duration);
    for (final layer in cut.layers) {
      buffer
        ..write('|')
        ..write(layer.id.value)
        ..write(':')
        ..write(layer.isVisible)
        ..write(':')
        ..write(layer.opacity)
        ..write(':')
        ..write(layer.frames.length)
        ..write(':')
        ..write(layer.frames.isEmpty ? '' : layer.frames.first.id.value);
    }
    return buffer.toString();
  }

  /// Disposes a replaced image AFTER the next frame paints: a RawImage from
  /// the previous build may still reference it during the current one.
  void _retire(ui.Image image) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      image.dispose();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _hub?.removeBrushFrameListener(_onBrushFrameInvalidated);
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
