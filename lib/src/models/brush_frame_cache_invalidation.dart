import 'brush_frame_key.dart';
import 'dirty_tile_set.dart';

/// Lightweight brush-frame cache/storage invalidation event.
///
/// This identifies the brush source frame that changed so future derived
/// preview/playback/renderer caches can be rebuilt from BrushFrameStore data.
/// It intentionally carries only dirty metadata, not cache images or bitmap
/// source payloads.
class BrushFrameCacheInvalidation {
  const BrushFrameCacheInvalidation({
    required this.frameKey,
    this.dirtyTiles,
    this.wholeFrame = false,
  });

  factory BrushFrameCacheInvalidation.wholeFrame(BrushFrameKey frameKey) {
    return BrushFrameCacheInvalidation(frameKey: frameKey, wholeFrame: true);
  }

  final BrushFrameKey frameKey;
  final DirtyTileSet? dirtyTiles;
  final bool wholeFrame;

  bool get hasDirtyTiles => dirtyTiles != null && dirtyTiles!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushFrameCacheInvalidation &&
          other.frameKey == frameKey &&
          other.dirtyTiles == dirtyTiles &&
          other.wholeFrame == wholeFrame;

  @override
  int get hashCode => Object.hash(frameKey, dirtyTiles, wholeFrame);

  @override
  String toString() =>
      'BrushFrameCacheInvalidation(frameKey: $frameKey, '
      'dirtyTiles: $dirtyTiles, wholeFrame: $wholeFrame)';
}
