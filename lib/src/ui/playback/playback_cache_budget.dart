import '../../models/playback_quality.dart';

/// Playback render-cache policy constants (single source of truth).
///
/// Half is the default playback quality, like the Premiere/AE monitors:
/// full-resolution frames of a 2340×1654 canvas cost ~15.5 MB each, so a
/// whole cut at Full can approach the budget by itself.
const PlaybackQuality defaultPlaybackQuality = PlaybackQuality.half;

/// Combined GPU-image byte budget across the layer-frame and cut-composite
/// caches. Enforcement (LRU + farthest-from-playhead eviction) lands in R8.
const int playbackCacheBudgetBytes = 600 * 1024 * 1024;

/// Estimated GPU bytes of an RGBA image of the given dimensions.
int estimatedImageBytes(int width, int height) => width * height * 4;
