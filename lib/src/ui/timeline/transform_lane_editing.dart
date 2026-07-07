// Per-lane key edits on a TransformTrack, keyed by the lane ids that
// transformPropertyLanes emits. Every function returns the edited track
// (or null when the edit is a no-op/invalid) — callers commit it as ONE
// undo step.

import '../../models/property_track.dart';
import '../../models/transform_track.dart';

/// Adds a key at [frameIndex] with the property's RESOLVED value there
/// (AE behavior: keying a property freezes its current value), or removes
/// the existing key — the keyframe-navigator diamond toggle.
TransformTrack? transformTrackWithLaneKeyToggled(
  TransformTrack track, {
  required String laneId,
  required int frameIndex,
  required TransformPose resolvedPose,
}) {
  if (frameIndex < 0) {
    return null;
  }
  switch (laneId) {
    case 'position':
      return track.copyWith(
        position: track.position.keyAt(frameIndex) != null
            ? track.position.withoutKey(frameIndex)
            : track.position.withKey(frameIndex, resolvedPose.center),
      );
    case 'scale':
      return track.copyWith(
        scale: track.scale.keyAt(frameIndex) != null
            ? track.scale.withoutKey(frameIndex)
            : track.scale.withKey(frameIndex, resolvedPose.zoom),
      );
    case 'rotation':
      return track.copyWith(
        rotation: track.rotation.keyAt(frameIndex) != null
            ? track.rotation.withoutKey(frameIndex)
            : track.rotation.withKey(frameIndex, resolvedPose.rotationDegrees),
      );
  }
  return null;
}

/// Moves a lane's key to another frame, keeping its value and
/// interpolation (an existing key at the target is overwritten — AE drop
/// semantics).
TransformTrack? transformTrackWithLaneKeyMoved(
  TransformTrack track, {
  required String laneId,
  required int fromFrame,
  required int toFrame,
}) {
  if (toFrame < 0 || toFrame == fromFrame) {
    return null;
  }
  switch (laneId) {
    case 'position':
      return _moved(track.position, fromFrame, toFrame, (next) {
        return track.copyWith(position: next);
      });
    case 'scale':
      return _moved(track.scale, fromFrame, toFrame, (next) {
        return track.copyWith(scale: next);
      });
    case 'rotation':
      return _moved(track.rotation, fromFrame, toFrame, (next) {
        return track.copyWith(rotation: next);
      });
  }
  return null;
}

/// Removes a lane's key at [frameIndex].
TransformTrack? transformTrackWithLaneKeyRemoved(
  TransformTrack track, {
  required String laneId,
  required int frameIndex,
}) {
  switch (laneId) {
    case 'position':
      if (track.position.keyAt(frameIndex) == null) return null;
      return track.copyWith(position: track.position.withoutKey(frameIndex));
    case 'scale':
      if (track.scale.keyAt(frameIndex) == null) return null;
      return track.copyWith(scale: track.scale.withoutKey(frameIndex));
    case 'rotation':
      if (track.rotation.keyAt(frameIndex) == null) return null;
      return track.copyWith(rotation: track.rotation.withoutKey(frameIndex));
  }
  return null;
}

/// Flips a key between linear and HOLD interpolation (AE's Toggle Hold
/// Keyframe).
TransformTrack? transformTrackWithLaneHoldToggled(
  TransformTrack track, {
  required String laneId,
  required int frameIndex,
}) {
  switch (laneId) {
    case 'position':
      final next = _holdToggled(track.position, frameIndex);
      return next == null ? null : track.copyWith(position: next);
    case 'scale':
      final next = _holdToggled(track.scale, frameIndex);
      return next == null ? null : track.copyWith(scale: next);
    case 'rotation':
      final next = _holdToggled(track.rotation, frameIndex);
      return next == null ? null : track.copyWith(rotation: next);
  }
  return null;
}

/// The lane's keyed frames — the keyframe navigator's ◀/▶ jump targets.
Set<int> transformLaneKeyFrames(TransformTrack track, String laneId) {
  return switch (laneId) {
    'position' => track.position.keys.keys.toSet(),
    'scale' => track.scale.keys.keys.toSet(),
    'rotation' => track.rotation.keys.keys.toSet(),
    _ => const {},
  };
}

TransformTrack? _moved<T>(
  PropertyTrack<T> lane,
  int fromFrame,
  int toFrame,
  TransformTrack Function(PropertyTrack<T> next) rebuild,
) {
  final key = lane.keyAt(fromFrame);
  if (key == null) {
    return null;
  }
  return rebuild(
    lane
        .withoutKey(fromFrame)
        .withKey(toFrame, key.value, interpolation: key.interpolation),
  );
}

PropertyTrack<T>? _holdToggled<T>(PropertyTrack<T> lane, int frameIndex) {
  final key = lane.keyAt(frameIndex);
  if (key == null) {
    return null;
  }
  return lane.withKey(
    frameIndex,
    key.value,
    interpolation: key.interpolation == PropertyKeyInterpolation.hold
        ? PropertyKeyInterpolation.linear
        : PropertyKeyInterpolation.hold,
  );
}
