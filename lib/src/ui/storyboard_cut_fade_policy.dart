import 'dart:math' as math;
import 'dart:ui' show Color;

import '../models/cut.dart';
import '../models/cut_metadata.dart';
import '../models/property_track.dart';
import '../models/transform_track.dart';

/// Cut fades as OPACITY KEYS ("opacity joins the transform system", user
/// direction): the fade handles write a canonical key shape into the
/// cut-level transform's opacity lane, and the composite consumers just
/// resolve the lane per frame — any future lane editor can key arbitrary
/// shapes on the same track.
///
/// Canonical shape (what the handles read back):
/// - fade-in over N frames: key 0 = 0.0, key N = 1.0 (both linear);
/// - fade-out over M frames: key (last − M) = 1.0, key last = 0.0 — the
///   fade reaches full black ON the cut's final frame.

/// Fade lengths parsed from the opacity lane; (0, 0) when unkeyed or when
/// the lane carries a non-canonical (hand-keyed) shape the handles cannot
/// represent — the lane still plays back, only the handles stand down.
({int fadeInFrames, int fadeOutFrames}) cutFadeLengths(Cut cut) {
  final opacity = cut.transformTrack.opacity;
  if (opacity.isEmpty) {
    return (fadeInFrames: 0, fadeOutFrames: 0);
  }
  final last = math.max(0, cut.duration - 1);
  var fadeIn = 0;
  var fadeOut = 0;
  final startKey = opacity.keyAt(0);
  if (startKey != null && startKey.value == 0.0) {
    // The first 1.0 key after 0 ends the fade-in.
    for (final entry in opacity.keys.entries) {
      if (entry.key > 0 && entry.value.value == 1.0) {
        fadeIn = entry.key;
        break;
      }
    }
  }
  final endKey = opacity.keyAt(last);
  if (last > 0 && endKey != null && endKey.value == 0.0) {
    // The last 1.0 key before the end starts the fade-out.
    for (final entry in opacity.keys.entries.toList().reversed) {
      if (entry.key < last && entry.value.value == 1.0) {
        fadeOut = last - entry.key;
        break;
      }
    }
    if (fadeOut == 0) {
      // No 1.0 shoulder (fade spans the whole cut): the ramp starts at the
      // fade-in end or the cut start.
      fadeOut = last - fadeIn;
    }
  }
  return (fadeInFrames: fadeIn, fadeOutFrames: fadeOut);
}

/// What [cut]'s fade fades TO as a paint color — FO=black (default),
/// WO=white. Playback overlays this color at (1 − fadeOpacity); the MP4
/// bake draws the frame over it. ONE function so every consumer agrees.
Color cutFadeTargetColor(Cut cut) {
  return switch (cut.metadata.fadeTarget) {
    CutFadeTarget.black => const Color(0xFF000000),
    CutFadeTarget.white => const Color(0xFFFFFFFF),
  };
}

/// The cut's transform with its opacity lane rebuilt to the canonical fade
/// shape (other lanes untouched). Zero lengths clear the lane.
TransformTrack cutTransformWithFade(
  Cut cut, {
  required int fadeInFrames,
  required int fadeOutFrames,
}) {
  final last = math.max(0, cut.duration - 1);
  final fadeIn = fadeInFrames.clamp(0, last);
  // The two ramps may meet but never cross (their keys would clobber each
  // other): the fade-out shortens to whatever the fade-in leaves.
  final fadeOut = fadeOutFrames.clamp(0, last - fadeIn);
  var opacity = PropertyTrack<double>.empty();
  if (fadeIn > 0) {
    opacity = opacity.withKey(0, 0.0).withKey(fadeIn, 1.0);
  }
  if (fadeOut > 0) {
    opacity = opacity.withKey(last - fadeOut, 1.0).withKey(last, 0.0);
  }
  return cut.transformTrack.copyWith(opacity: opacity);
}
