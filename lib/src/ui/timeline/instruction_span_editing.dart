import 'dart:collection';

import '../../models/camera_instruction.dart';

/// Pure edits on an instruction row's span map. Each returns the edited
/// map, or null when the edit changes nothing / is not possible — callers
/// commit non-null results as ONE undo step (UpdateLayerInstructionsCommand).

/// The span covering [frameIndex], as (startIndex, event); null on empty
/// cells.
MapEntry<int, InstructionEvent>? instructionSpanCovering(
  SplayTreeMap<int, InstructionEvent> instructions,
  int frameIndex,
) {
  final startIndex = instructions.lastKeyBefore(frameIndex + 1);
  if (startIndex == null) {
    return null;
  }
  final event = instructions[startIndex]!;
  if (frameIndex >= startIndex + event.length) {
    return null;
  }
  return MapEntry(startIndex, event);
}

/// Shifts one edge of the span starting at [spanStartIndex] by [delta]
/// frames. The END edge resizes the span (min length 1, clamped at the
/// next span's start). The START edge moves the start while the end stays
/// fixed (clamped at the previous span's end and frame 0). Unlike cel
/// blocks there is no ripple — instruction spans are independent notes.
SplayTreeMap<int, InstructionEvent>? instructionMapWithEdgeShifted(
  SplayTreeMap<int, InstructionEvent> instructions, {
  required int spanStartIndex,
  required bool startEdge,
  required int delta,
}) {
  final event = instructions[spanStartIndex];
  if (event == null || delta == 0) {
    return null;
  }

  final next = SplayTreeMap<int, InstructionEvent>.of(instructions);
  if (startEdge) {
    final previousStart = instructions.lastKeyBefore(spanStartIndex);
    final minStart = previousStart == null
        ? 0
        : previousStart + instructions[previousStart]!.length;
    final endExclusive = spanStartIndex + event.length;
    final newStart = (spanStartIndex + delta)
        .clamp(minStart, endExclusive - 1)
        .toInt();
    if (newStart == spanStartIndex) {
      return null;
    }
    next.remove(spanStartIndex);
    next[newStart] = event.copyWith(length: endExclusive - newStart);
  } else {
    final nextStart = instructions.firstKeyAfter(spanStartIndex);
    final maxLength = nextStart == null ? 1 << 20 : nextStart - spanStartIndex;
    final newLength = (event.length + delta).clamp(1, maxLength).toInt();
    if (newLength == event.length) {
      return null;
    }
    next[spanStartIndex] = event.copyWith(length: newLength);
  }
  return next;
}

/// Places [event] at [startIndex] on an empty cell, clamping its length at
/// the next span; null when the cell is already covered.
SplayTreeMap<int, InstructionEvent>? instructionMapWithEventAdded(
  SplayTreeMap<int, InstructionEvent> instructions, {
  required int startIndex,
  required InstructionEvent event,
}) {
  if (startIndex < 0 ||
      instructionSpanCovering(instructions, startIndex) != null) {
    return null;
  }
  final nextStart = instructions.firstKeyAfter(startIndex);
  final maxLength = nextStart == null ? event.length : nextStart - startIndex;
  final next = SplayTreeMap<int, InstructionEvent>.of(instructions);
  next[startIndex] = event.copyWith(
    length: event.length.clamp(1, maxLength < 1 ? 1 : maxLength),
  );
  return next;
}

/// Replaces the event of the span starting at [spanStartIndex] (start and
/// length untouched); null when absent or unchanged.
SplayTreeMap<int, InstructionEvent>? instructionMapWithEventReplaced(
  SplayTreeMap<int, InstructionEvent> instructions, {
  required int spanStartIndex,
  required InstructionEvent event,
}) {
  final existing = instructions[spanStartIndex];
  if (existing == null) {
    return null;
  }
  final replacement = event.copyWith(length: existing.length);
  if (replacement == existing) {
    return null;
  }
  final next = SplayTreeMap<int, InstructionEvent>.of(instructions);
  next[spanStartIndex] = replacement;
  return next;
}

/// Removes the span starting at [spanStartIndex]; null when absent.
SplayTreeMap<int, InstructionEvent>? instructionMapWithEventRemoved(
  SplayTreeMap<int, InstructionEvent> instructions, {
  required int spanStartIndex,
}) {
  if (!instructions.containsKey(spanStartIndex)) {
    return null;
  }
  return SplayTreeMap<int, InstructionEvent>.of(instructions)
    ..remove(spanStartIndex);
}
