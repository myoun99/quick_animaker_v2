import '../../models/property_track.dart';
import '../../models/transform_track.dart';
import 'property_lane_model.dart';

/// The AE Transform-group lanes of a [TransformTrack], in AE order. The
/// whole group shows when twirled down (like AE) even where a property has
/// no keys yet; anchor point and opacity join once layer transforms use
/// them — the camera's group is the pose trio.
List<PropertyLaneRow> transformPropertyLanes(
  TransformTrack track, {
  bool includeAnchorAndOpacity = false,
}) {
  return [
    if (includeAnchorAndOpacity)
      _lane('anchor-point', 'Anchor Point', track.anchorPoint),
    _lane('position', 'Position', track.position),
    _lane('scale', 'Scale', track.scale),
    _lane('rotation', 'Rotation', track.rotation),
    if (includeAnchorAndOpacity) _lane('opacity', 'Opacity', track.opacity),
  ];
}

PropertyLaneRow _lane<T>(String id, String label, PropertyTrack<T> track) {
  return PropertyLaneRow(
    laneId: id,
    label: label,
    keyedFrames: track.keys.keys.toSet(),
    holdOutFrames: {
      for (final entry in track.keys.entries)
        if (entry.value.interpolation == PropertyKeyInterpolation.hold)
          entry.key,
    },
  );
}
