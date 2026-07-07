import '../../models/property_track.dart';
import '../../models/transform_track.dart';
import 'property_lane_model.dart';

/// The AE Transform-group lanes of a [TransformTrack], in AE order. The
/// whole group shows when twirled down (like AE) even where a property has
/// no keys yet; anchor point and opacity join once layer transforms use
/// them — the camera's group is the pose trio.
///
/// [poseAt] resolves the pose for the value column (AE display units:
/// Position in canvas px, Scale as zoom·100 %, Rotation in clockwise
/// degrees); null hides the values.
List<PropertyLaneRow> transformPropertyLanes(
  TransformTrack track, {
  bool includeAnchorAndOpacity = false,
  TransformPose Function(int frameIndex)? poseAt,
}) {
  return [
    if (includeAnchorAndOpacity)
      _lane('anchor-point', 'Anchor Point', track.anchorPoint),
    _lane(
      'position',
      'Position',
      track.position,
      valueLabel: poseAt == null
          ? null
          : (frame) => formatTransformLaneValue('position', poseAt(frame)),
    ),
    _lane(
      'scale',
      'Scale',
      track.scale,
      valueLabel: poseAt == null
          ? null
          : (frame) => formatTransformLaneValue('scale', poseAt(frame)),
    ),
    _lane(
      'rotation',
      'Rotation',
      track.rotation,
      valueLabel: poseAt == null
          ? null
          : (frame) => formatTransformLaneValue('rotation', poseAt(frame)),
    ),
    if (includeAnchorAndOpacity) _lane('opacity', 'Opacity', track.opacity),
  ];
}

/// AE-style value formatting for a transform lane.
String formatTransformLaneValue(String laneId, TransformPose pose) {
  return switch (laneId) {
    'position' => '${_number(pose.center.x)}, ${_number(pose.center.y)}',
    'scale' => '${_number(pose.zoom * 100)}%',
    'rotation' => '${_number(pose.rotationDegrees)}°',
    _ => '',
  };
}

String _number(double value) {
  final rounded = double.parse(value.toStringAsFixed(1));
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
}

PropertyLaneRow _lane<T>(
  String id,
  String label,
  PropertyTrack<T> track, {
  String Function(int frameIndex)? valueLabel,
}) {
  return PropertyLaneRow(
    laneId: id,
    label: label,
    keyedFrames: track.keys.keys.toSet(),
    holdOutFrames: {
      for (final entry in track.keys.entries)
        if (entry.value.interpolation == PropertyKeyInterpolation.hold)
          entry.key,
    },
    valueLabel: valueLabel,
  );
}
