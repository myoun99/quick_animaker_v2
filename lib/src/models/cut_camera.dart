import 'dart:collection';

import 'camera_pose.dart';
import 'transform_track.dart';

/// Per-cut camera animation: camera poses keyframed by playback frame index.
///
/// A thin cut-level wrapper over the shared [TransformTrack] mechanics (the
/// same track type layer transforms use). An empty track means the cut has
/// no camera work; consumers fall back to the default pose (canvas centered,
/// zoom 1, no rotation).
class CutCamera {
  CutCamera({Map<int, CameraPose>? keyframes})
    : track = TransformTrack(keyframes: keyframes);

  const CutCamera.fromTrack(this.track);

  factory CutCamera.empty() => CutCamera();

  final TransformTrack track;

  SplayTreeMap<int, CameraPose> get keyframes => track.keyframes;

  bool get isEmpty => track.isEmpty;
  bool get isNotEmpty => track.isNotEmpty;

  CameraPose? keyframeAt(int frameIndex) => track.keyframeAt(frameIndex);

  CutCamera withKeyframe(int frameIndex, CameraPose pose) {
    return CutCamera.fromTrack(track.withKeyframe(frameIndex, pose));
  }

  CutCamera withoutKeyframe(int frameIndex) {
    return CutCamera.fromTrack(track.withoutKeyframe(frameIndex));
  }

  Map<String, dynamic> toJson() => track.toJson();

  factory CutCamera.fromJson(Map<String, dynamic> json) {
    return CutCamera.fromTrack(TransformTrack.fromJson(json));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CutCamera && other.track == track;

  @override
  int get hashCode => track.hashCode;

  @override
  String toString() => 'CutCamera(keyframes: $keyframes)';
}
