import 'dart:collection';

import '../core/collection_equality.dart';
import 'camera_pose.dart';
import 'canvas_point.dart';

/// The shared transform pose shape: a point in canvas coordinates plus
/// uniform scale and rotation. The camera has used this shape since C0
/// (center/zoom/rotation); layer transforms keyframe the same shape, so the
/// dedicated name arrives with the property-lanes work as a mechanical
/// rename.
typedef TransformPose = CameraPose;

/// A keyframed transform: [TransformPose]s on non-negative integer frame
/// keys, shared by the cut camera and (with the property-lanes work) layer
/// transforms.
///
/// Resolution semantics (see [resolveAt]): exact keyframes win; frames
/// before the first keyframe hold the first pose and frames after the last
/// hold the last; frames between two keyframes interpolate linearly
/// component-wise. An empty track means "no transform work" — consumers
/// supply their own default pose.
class TransformTrack {
  TransformTrack({Map<int, TransformPose>? keyframes})
    : keyframes = _immutableKeyframes(keyframes ?? const {});

  factory TransformTrack.empty() => TransformTrack();

  final SplayTreeMap<int, TransformPose> keyframes;

  bool get isEmpty => keyframes.isEmpty;
  bool get isNotEmpty => keyframes.isNotEmpty;

  TransformPose? keyframeAt(int frameIndex) => keyframes[frameIndex];

  TransformTrack withKeyframe(int frameIndex, TransformPose pose) {
    return TransformTrack(keyframes: {...keyframes, frameIndex: pose});
  }

  TransformTrack withoutKeyframe(int frameIndex) {
    final next = Map<int, TransformPose>.of(keyframes)..remove(frameIndex);
    return TransformTrack(keyframes: next);
  }

  /// Resolves the pose at [frameIndex]; [orElse] supplies the empty-track
  /// default (e.g. the camera's canvas-centered pose, a layer's identity).
  TransformPose resolveAt({
    required int frameIndex,
    required TransformPose Function() orElse,
  }) {
    if (isEmpty) {
      return orElse();
    }

    final exact = keyframes[frameIndex];
    if (exact != null) {
      return exact;
    }

    final previousIndex = keyframes.lastKeyBefore(frameIndex);
    final nextIndex = keyframes.firstKeyAfter(frameIndex);
    if (previousIndex == null) {
      return keyframes[nextIndex!]!;
    }
    if (nextIndex == null) {
      return keyframes[previousIndex]!;
    }

    return lerpTransformPose(
      keyframes[previousIndex]!,
      keyframes[nextIndex]!,
      (frameIndex - previousIndex) / (nextIndex - previousIndex),
    );
  }

  Map<String, dynamic> toJson() => {
    'keyframes': keyframes.entries
        .map((entry) => {'index': entry.key, 'pose': entry.value.toJson()})
        .toList(),
  };

  factory TransformTrack.fromJson(Map<String, dynamic> json) {
    final keyframes = <int, TransformPose>{};
    for (final item in json['keyframes'] as List? ?? const []) {
      final entry = item as Map<String, dynamic>;
      final index = entry['index'] as int;
      if (keyframes.containsKey(index)) {
        throw FormatException('Duplicate transform keyframe index: $index');
      }
      keyframes[index] = TransformPose.fromJson(
        entry['pose'] as Map<String, dynamic>,
      );
    }
    return TransformTrack(keyframes: keyframes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransformTrack && mapEquals(other.keyframes, keyframes);

  @override
  int get hashCode => Object.hashAll(
    keyframes.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );

  @override
  String toString() => 'TransformTrack(keyframes: $keyframes)';
}

/// Component-wise linear interpolation; rotation lerps as-is (no
/// wrap-around), so keyframing 0 → 360 produces a full turn.
TransformPose lerpTransformPose(TransformPose a, TransformPose b, double t) {
  return TransformPose(
    center: CanvasPoint(
      x: _lerp(a.center.x, b.center.x, t),
      y: _lerp(a.center.y, b.center.y, t),
    ),
    zoom: _lerp(a.zoom, b.zoom, t),
    rotationDegrees: _lerp(a.rotationDegrees, b.rotationDegrees, t),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

SplayTreeMap<int, TransformPose> _immutableKeyframes(
  Map<int, TransformPose> keyframes,
) {
  final result = SplayTreeMap<int, TransformPose>();
  for (final entry in keyframes.entries) {
    if (entry.key < 0) {
      throw ArgumentError.value(
        entry.key,
        'keyframes',
        'Transform keyframe indexes must be non-negative.',
      );
    }
    result[entry.key] = entry.value;
  }
  return result;
}
