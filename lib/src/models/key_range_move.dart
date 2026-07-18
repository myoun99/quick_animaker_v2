/// Pure planning for KEY-RANGE moves (UI-R20 #2 second half, P3b-2): the
/// camera row's keyframes and the instruction rows' event spans shift with
/// a range selection exactly like drawing blocks slide — rigid group, one
/// delta, all-or-nothing (an illegal landing voids the whole plan).
library;

import 'camera_instruction.dart';
import 'camera_pose.dart';

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
