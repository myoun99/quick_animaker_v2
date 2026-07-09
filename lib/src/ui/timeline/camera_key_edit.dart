import '../../models/property_track.dart';
import '../../models/transform_track.dart';
import 'transform_lane_editing.dart';
import 'transform_lane_policy.dart';

/// One lane row of the camera key dialog: whether the lane is keyed at the
/// frame, its value in AE display units and whether the key holds. Pure
/// data — the dialog edits copies, [transformTrackWithKeyDialogApplied]
/// folds the delta into ONE track edit (one undo).
class CameraKeyLaneState {
  const CameraKeyLaneState({
    required this.laneId,
    required this.label,
    required this.keyed,
    required this.valueText,
    required this.hold,
  });

  final String laneId;
  final String label;
  final bool keyed;

  /// AE display units, same accepted grammar as the lane value editor
  /// (position `x, y`; scale `150%`; rotation `45°`).
  final String valueText;
  final bool hold;

  CameraKeyLaneState copyWith({bool? keyed, String? valueText, bool? hold}) {
    return CameraKeyLaneState(
      laneId: laneId,
      label: label,
      keyed: keyed ?? this.keyed,
      valueText: valueText ?? this.valueText,
      hold: hold ?? this.hold,
    );
  }
}

PropertyKey<Object?>? _laneKeyAt(
  TransformTrack track,
  String laneId,
  int frameIndex,
) {
  return switch (laneId) {
    'position' => track.position.keyAt(frameIndex),
    'scale' => track.scale.keyAt(frameIndex),
    'rotation' => track.rotation.keyAt(frameIndex),
    _ => null,
  };
}

/// The dialog's initial lane states at [frameIndex]: keyed flags and hold
/// come from the track, value texts from the RESOLVED pose there (equal to
/// the key's value when keyed) in AE display units.
List<CameraKeyLaneState> cameraKeyLaneStatesAt(
  TransformTrack track, {
  required int frameIndex,
  required TransformPose resolvedPose,
}) {
  const lanes = [
    ('position', 'Position'),
    ('scale', 'Scale'),
    ('rotation', 'Rotation'),
  ];
  return [
    for (final (laneId, label) in lanes)
      () {
        final key = _laneKeyAt(track, laneId, frameIndex);
        return CameraKeyLaneState(
          laneId: laneId,
          label: label,
          keyed: key != null,
          valueText: formatTransformLaneValue(laneId, resolvedPose),
          hold: key?.interpolation == PropertyKeyInterpolation.hold,
        );
      }(),
  ];
}

/// Folds the dialog's edited lane states back onto the track: unchecking
/// removes the lane's key, checking (or changing the value while keyed)
/// keys the typed value via the shared lane-value grammar, and the hold
/// flag flips the key's interpolation. Returns the edited track, or null
/// when nothing effectively changed — callers commit non-null results as
/// ONE undo step.
TransformTrack? transformTrackWithKeyDialogApplied(
  TransformTrack track, {
  required int frameIndex,
  required List<CameraKeyLaneState> before,
  required List<CameraKeyLaneState> after,
}) {
  assert(before.length == after.length);
  var current = track;
  var changed = false;

  for (var i = 0; i < after.length; i += 1) {
    final b = before[i];
    final a = after[i];
    assert(b.laneId == a.laneId);

    if (!a.keyed) {
      if (b.keyed) {
        final removed = transformTrackWithLaneKeyRemoved(
          current,
          laneId: a.laneId,
          frameIndex: frameIndex,
        );
        if (removed != null) {
          current = removed;
          changed = true;
        }
      }
      continue;
    }

    if (!b.keyed || a.valueText.trim() != b.valueText.trim()) {
      final valued = transformTrackWithLaneValueEdited(
        current,
        laneId: a.laneId,
        frameIndex: frameIndex,
        input: a.valueText,
      );
      if (valued != null) {
        current = valued;
        changed = true;
      } else if (!b.keyed) {
        // Unparseable text on a lane that was not keyed: no key to flag.
        continue;
      }
    }

    final key = _laneKeyAt(current, a.laneId, frameIndex);
    if (key != null &&
        (key.interpolation == PropertyKeyInterpolation.hold) != a.hold) {
      final toggled = transformTrackWithLaneHoldToggled(
        current,
        laneId: a.laneId,
        frameIndex: frameIndex,
      );
      if (toggled != null) {
        current = toggled;
        changed = true;
      }
    }
  }

  return changed ? current : null;
}
