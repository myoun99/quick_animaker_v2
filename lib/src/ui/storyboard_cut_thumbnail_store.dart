import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/brush_frame_cache_invalidation.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/layer.dart';
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
/// visibility/opacity/frames/EXPOSURES, camera track, layer transforms and
/// the cut fade — everything the camera-view render consumes) plus a
/// per-cut edit generation bumped by the hub's brush-frame events (stroke
/// commit / undo / redo). Camera work, transform-lane edits and exposure
/// moves used to be signature-blind (R4-⑩): a cut whose thumbnail first
/// rendered empty stayed a white block forever unless a stroke landed.
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
          .catchError((Object error, StackTrace stack) {
            _rendering.remove(cut.id);
            // Remember the failed signature: silently swallowing AND
            // forgetting re-kicked the same failing render on every
            // rebuild (a hot loop behind a permanently empty block). The
            // next CONTENT change retries; the failure itself is surfaced.
            _renderedSignatures[cut.id] = signature;
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stack,
                library: 'storyboard thumbnails',
                context: ErrorDescription(
                  'rendering the storyboard thumbnail for cut '
                  '${cut.id.value}',
                ),
              ),
            );
          }),
    );
  }

  /// Coalesces invalidation-driven notifies: a stroke commits MANY hub
  /// events, one microtask notify covers them all.
  bool _invalidationNotifyScheduled = false;

  void _onBrushFrameInvalidated(BrushFrameCacheInvalidation invalidation) {
    final cutId = invalidation.frameKey.cutId;
    _editGenerations[cutId] = (_editGenerations[cutId] ?? 0) + 1;
    // Rendering stays lazy (the next thumbnailFor call sees the bumped
    // signature) but the notify must fire HERE: brush strokes never notify
    // the session, so without it nothing rebuilt a visible storyboard and
    // freshly drawn artwork never reached its thumbnail (the R5-⑩
    // "thumbnails never show up" device report).
    if (_invalidationNotifyScheduled || _disposed) {
      return;
    }
    _invalidationNotifyScheduled = true;
    scheduleMicrotask(() {
      _invalidationNotifyScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  String _signatureFor(Cut cut) {
    final buffer = StringBuffer()
      ..write(cut.canvasSize.width)
      ..write('x')
      ..write(cut.canvasSize.height)
      ..write('#')
      ..write(_editGenerations[cut.id] ?? 0)
      ..write('#')
      ..write(cut.duration)
      // Re-render when the pinned thumbnail frame changes.
      ..write('#')
      ..write(cut.metadata.thumbnailFrameIndex ?? -1)
      // The thumbnail renders THROUGH the camera: camera work must
      // re-render it (was signature-blind — R4-⑩).
      ..write('#cam')
      ..write(cut.camera.track.hashCode)
      // The cut fade bakes into video frames only, but the fade keys live
      // on the cut transform track — cheap to include, keeps the door
      // open for fade-aware thumbs.
      ..write('#fade')
      ..write(cut.transformTrack.hashCode);
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
        ..write(layer.frames.isEmpty ? '' : layer.frames.first.id.value)
        // Layer transforms apply at composite time — lane edits must
        // re-render (was signature-blind — R4-⑩).
        ..write(':')
        ..write(layer.transformTrack.hashCode)
        // Which frame is EXPOSED at the thumbnail index is timeline data;
        // exposure-only edits used to leave a stale thumb (documented gap,
        // now closed). Deterministic fold over the entries — Map itself
        // hashes by identity.
        ..write(':')
        ..write(_timelineDigest(layer));
    }
    return buffer.toString();
  }

  int _timelineDigest(Layer layer) {
    var digest = 0;
    for (final entry in layer.timeline.entries) {
      digest = Object.hash(digest, entry.key, entry.value);
    }
    return digest;
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
