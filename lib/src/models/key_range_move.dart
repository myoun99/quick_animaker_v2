/// Pure planning for KEY-RANGE moves (UI-R20 #2 second half, P3b-2): the
/// camera row's keyframes and the instruction rows' event spans shift with
/// a range selection exactly like drawing blocks slide — rigid group, one
/// delta, all-or-nothing (an illegal landing voids the whole plan).
library;

import 'camera_instruction.dart';
import 'camera_pose.dart';
import 'property_track.dart';
import 'transform_track.dart';

/// The camera keyframes with every key in [rangeStartIndex,
/// [rangeEndIndexExclusive]) shifted by [frameDelta]; null when any
/// shifted key would land below frame 0 or on an UNSHIFTED key (the
/// block discipline: nothing merges silently).
Map<int, CameraPose>? shiftCameraKeysInRange({
  required Map<int, CameraPose> keyframes,
  required int rangeStartIndex,
  required int rangeEndIndexExclusive,
  required int frameDelta,
}) {
  bool inRange(int frame) =>
      frame >= rangeStartIndex && frame < rangeEndIndexExclusive;
  final moved = <int>{
    for (final frame in keyframes.keys)
      if (inRange(frame)) frame,
  };
  if (moved.isEmpty || frameDelta == 0) {
    return null;
  }
  final shifted = <int, CameraPose>{};
  for (final entry in keyframes.entries) {
    if (!moved.contains(entry.key)) {
      shifted[entry.key] = entry.value;
    }
  }
  for (final frame in moved) {
    final landing = frame + frameDelta;
    if (landing < 0 || shifted.containsKey(landing)) {
      return null;
    }
    shifted[landing] = keyframes[frame]!;
  }
  return shifted;
}

/// Every frame carrying a key on ANY lane of [track] — the transform
/// group header's summary display (UI-R20 #13, the camera row pattern).
Set<int> transformKeyFrameUnion(TransformTrack track) => {
  ...track.anchorPoint.keys.keys,
  ...track.position.keys.keys,
  ...track.scale.keys.keys,
  ...track.rotation.keys.keys,
  ...track.opacity.keys.keys,
};

/// Whether any lane of [track] holds a key inside the range.
bool transformTrackHasKeysInRange(
  TransformTrack track,
  int rangeStartIndex,
  int rangeEndIndexExclusive,
) => transformKeyFrameUnion(
  track,
).any((frame) => frame >= rangeStartIndex && frame < rangeEndIndexExclusive);

/// The transform track with every keyed frame in range shifted by
/// [frameDelta] on EVERY lane; null when any landing dips below 0 or
/// collides with an unshifted key on the same lane (all-or-nothing, the
/// block discipline).
TransformTrack? shiftTransformKeysInRange({
  required TransformTrack track,
  required int rangeStartIndex,
  required int rangeEndIndexExclusive,
  required int frameDelta,
}) {
  if (frameDelta == 0) {
    return null;
  }
  bool inRange(int frame) =>
      frame >= rangeStartIndex && frame < rangeEndIndexExclusive;
  PropertyTrack<T>? shiftLane<T>(PropertyTrack<T> lane) {
    final moved = <int>{
      for (final frame in lane.keys.keys)
        if (inRange(frame)) frame,
    };
    if (moved.isEmpty) {
      return lane;
    }
    final next = <int, PropertyKey<T>>{};
    for (final entry in lane.keys.entries) {
      if (!moved.contains(entry.key)) {
        next[entry.key] = entry.value;
      }
    }
    for (final frame in moved) {
      final landing = frame + frameDelta;
      if (landing < 0 || next.containsKey(landing)) {
        return null;
      }
      next[landing] = lane.keys[frame]!;
    }
    return PropertyTrack(keys: next);
  }

  final anchorPoint = shiftLane(track.anchorPoint);
  final position = shiftLane(track.position);
  final scale = shiftLane(track.scale);
  final rotation = shiftLane(track.rotation);
  final opacity = shiftLane(track.opacity);
  if (anchorPoint == null ||
      position == null ||
      scale == null ||
      rotation == null ||
      opacity == null) {
    return null;
  }
  return TransformTrack.properties(
    anchorPoint: anchorPoint,
    position: position,
    scale: scale,
    rotation: rotation,
    opacity: opacity,
  );
}

/// The instruction map with every event STARTING in the range shifted by
/// [frameDelta]; null when any landing dips below 0 or overlaps an
/// unmoved event's span.
Map<int, InstructionEvent>? shiftInstructionEventsInRange({
  required Map<int, InstructionEvent> events,
  required int rangeStartIndex,
  required int rangeEndIndexExclusive,
  required int frameDelta,
}) {
  bool inRange(int frame) =>
      frame >= rangeStartIndex && frame < rangeEndIndexExclusive;
  final moved = <int>{
    for (final start in events.keys)
      if (inRange(start)) start,
  };
  if (moved.isEmpty || frameDelta == 0) {
    return null;
  }
  final shifted = <int, InstructionEvent>{};
  for (final entry in events.entries) {
    if (!moved.contains(entry.key)) {
      shifted[entry.key] = entry.value;
    }
  }
  for (final start in moved) {
    final event = events[start]!;
    final landing = start + frameDelta;
    if (landing < 0) {
      return null;
    }
    final landingEnd = landing + event.length;
    for (final other in shifted.entries) {
      final otherEnd = other.key + other.value.length;
      if (landing < otherEnd && other.key < landingEnd) {
        return null;
      }
    }
    shifted[landing] = event;
  }
  return shifted;
}
