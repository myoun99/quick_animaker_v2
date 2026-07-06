import '../../models/playback_quality.dart';
import 'cut_frame_composite_cache.dart';
import 'layer_frame_image_cache.dart';

/// Playback render-cache policy constants (single source of truth).
///
/// Half is the default playback quality, like the Premiere/AE monitors:
/// full-resolution frames of a 2340×1654 canvas cost ~15.5 MB each, so a
/// whole cut at Full can approach the budget by itself.
const PlaybackQuality defaultPlaybackQuality = PlaybackQuality.half;

/// Combined GPU-image byte budget across the layer-frame and cut-composite
/// caches.
const int playbackCacheBudgetBytes = 600 * 1024 * 1024;

/// Estimated GPU bytes of an RGBA image of the given dimensions.
int estimatedImageBytes(int width, int height) => width * height * 4;

/// Keeps the two playback caches inside one combined byte budget.
///
/// Composites are the playback hot path, so they claim the budget first
/// (never evicting the protected playing range); the layer-frame images
/// shrink into whatever remains — they are cheap to rebuild from the
/// display-cache surfaces when needed again.
class PlaybackCacheBudgetEnforcer {
  const PlaybackCacheBudgetEnforcer({
    required this.layerImages,
    required this.composites,
    this.maxBytes = playbackCacheBudgetBytes,
  });

  final LayerFrameImageCache layerImages;
  final CutFrameCompositeCache composites;
  final int maxBytes;

  void enforce({List<PlaybackProtectedRange> protect = const []}) {
    composites.enforceBudget(maxBytes: maxBytes, protect: protect);
    final remaining = maxBytes - composites.estimatedBytes;
    layerImages.evictLeastRecentlyUsed(
      targetBytes: remaining < 0 ? 0 : remaining,
    );
  }
}
