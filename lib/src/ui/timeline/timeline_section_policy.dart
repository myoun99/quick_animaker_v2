import '../../models/layer.dart';
import '../../models/layer_kind.dart';

/// Timesheet-style timeline sections, in raw (model) order: drawing cels
/// first, sound effects, camera last.
///
/// The horizontal timeline reverses raw order, so on screen the sections
/// stack bottom-up as 그림 → SE → 카메라 (camera rows on top); the X-sheet
/// keeps raw order and reads left-to-right like a paper timesheet (ACTION
/// cel columns, then CAMERA on the right).
///
enum TimelineSection { drawing, se, camera }

TimelineSection timelineSectionForLayerKind(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation || LayerKind.storyboard => TimelineSection.drawing,
    LayerKind.se => TimelineSection.se,
    LayerKind.camera => TimelineSection.camera,
  };
}

/// Stable-sorts layers into section order (raw orientation), preserving the
/// relative order within each section. Defensive: the model usually already
/// keeps camera last, but display must not depend on that.
List<Layer> sectionedLayerOrder(List<Layer> layers) {
  final buckets = <TimelineSection, List<Layer>>{
    for (final section in TimelineSection.values) section: <Layer>[],
  };
  for (final layer in layers) {
    buckets[timelineSectionForLayerKind(layer.kind)]!.add(layer);
  }
  return List<Layer>.unmodifiable([
    for (final section in TimelineSection.values) ...buckets[section]!,
  ]);
}

/// Whether the layer at [index] opens a new section relative to the layer
/// before it in DISPLAY order. The first row/column never draws a divider.
bool timelineSectionStartsAt(List<Layer> displayLayers, int index) {
  if (index <= 0 || index >= displayLayers.length) {
    return false;
  }
  return timelineSectionForLayerKind(displayLayers[index].kind) !=
      timelineSectionForLayerKind(displayLayers[index - 1].kind);
}
