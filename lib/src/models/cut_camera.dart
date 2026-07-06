import 'dart:collection';

import '../core/collection_equality.dart';
import 'camera_pose.dart';

/// Per-cut camera animation: camera poses keyframed by playback frame index.
///
/// An empty keyframe map means the cut has no camera work; consumers fall back
/// to the default pose (canvas centered, zoom 1, no rotation).
class CutCamera {
  CutCamera({Map<int, CameraPose>? keyframes})
    : keyframes = _immutableKeyframes(keyframes ?? const {});

  factory CutCamera.empty() => CutCamera();

  final SplayTreeMap<int, CameraPose> keyframes;

  bool get isEmpty => keyframes.isEmpty;
  bool get isNotEmpty => keyframes.isNotEmpty;

  CameraPose? keyframeAt(int frameIndex) => keyframes[frameIndex];

  CutCamera withKeyframe(int frameIndex, CameraPose pose) {
    return CutCamera(keyframes: {...keyframes, frameIndex: pose});
  }

  CutCamera withoutKeyframe(int frameIndex) {
    final next = Map<int, CameraPose>.of(keyframes)..remove(frameIndex);
    return CutCamera(keyframes: next);
  }

  Map<String, dynamic> toJson() => {
    'keyframes': keyframes.entries
        .map((entry) => {'index': entry.key, 'pose': entry.value.toJson()})
        .toList(),
  };

  factory CutCamera.fromJson(Map<String, dynamic> json) {
    final keyframes = <int, CameraPose>{};
    for (final item in json['keyframes'] as List? ?? const []) {
      final entry = item as Map<String, dynamic>;
      final index = entry['index'] as int;
      if (keyframes.containsKey(index)) {
        throw FormatException('Duplicate camera keyframe index: $index');
      }
      keyframes[index] = CameraPose.fromJson(
        entry['pose'] as Map<String, dynamic>,
      );
    }
    return CutCamera(keyframes: keyframes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CutCamera && mapEquals(other.keyframes, keyframes);

  @override
  int get hashCode => Object.hashAll(
    keyframes.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );

  @override
  String toString() => 'CutCamera(keyframes: $keyframes)';
}

SplayTreeMap<int, CameraPose> _immutableKeyframes(
  Map<int, CameraPose> keyframes,
) {
  final result = SplayTreeMap<int, CameraPose>();
  for (final entry in keyframes.entries) {
    if (entry.key < 0) {
      throw ArgumentError.value(
        entry.key,
        'keyframes',
        'Camera keyframe indexes must be non-negative.',
      );
    }
    result[entry.key] = entry.value;
  }
  return result;
}
