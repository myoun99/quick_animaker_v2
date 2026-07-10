import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../models/cut_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/project.dart';

/// The scoped edit-drag preview channel.
///
/// Edge-grip drags (exposure commas, storyboard cut trims) publish their
/// per-step preview HERE — a value-only notifier, never a session notify —
/// so only the widgets that render the dragged thing rebuild per step. The
/// repository stays untouched until the release commits ONE undoable
/// command (the audio-slide R5-⑧ precedent, generalized). This is also the
/// substrate a future cross-layer block drag rides: its ghost/drop preview
/// is one more [TimelineDragPreview] variant.
sealed class TimelineDragPreview {
  const TimelineDragPreview();
}

/// An exposure/instruction edge drag in flight: [previewLayer] is the
/// drag-start snapshot with the cumulative delta applied (idempotent — the
/// session recomputes it per step).
class ExposureEdgeDragPreview extends TimelineDragPreview {
  const ExposureEdgeDragPreview({required this.previewLayer});

  final Layer previewLayer;

  LayerId get layerId => previewLayer.id;

  @override
  bool operator ==(Object other) =>
      other is ExposureEdgeDragPreview && other.previewLayer == previewLayer;

  @override
  int get hashCode => previewLayer.hashCode;
}

/// A storyboard cut-trim drag in flight: the involved cuts' previewed
/// durations (one cut for an end trim, the boundary pair for a roll).
class CutTrimDragPreview extends TimelineDragPreview {
  const CutTrimDragPreview({required this.previewDurations});

  final Map<CutId, int> previewDurations;

  @override
  bool operator ==(Object other) =>
      other is CutTrimDragPreview &&
      mapEquals(other.previewDurations, previewDurations);

  @override
  int get hashCode => Object.hashAllUnordered(
    previewDurations.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// The preview layer for [layerId], or null when [preview] does not target
/// it.
Layer? timelineDragPreviewLayerFor(
  TimelineDragPreview? preview,
  LayerId layerId,
) {
  if (preview is ExposureEdgeDragPreview && preview.layerId == layerId) {
    return preview.previewLayer;
  }
  return null;
}

/// A project snapshot with an in-flight drag preview substituted in —
/// the storyboard panel renders THIS during a drag so its blocks follow
/// the pointer while the repository stays untouched.
Project projectWithTimelineDragPreview(
  Project project,
  TimelineDragPreview? preview,
) {
  switch (preview) {
    case null:
      return project;
    case CutTrimDragPreview(:final previewDurations):
      return project.copyWith(
        tracks: [
          for (final track in project.tracks)
            track.copyWith(
              cuts: [
                for (final cut in track.cuts)
                  previewDurations.containsKey(cut.id)
                      ? cut.copyWith(duration: previewDurations[cut.id])
                      : cut,
              ],
            ),
        ],
      );
    case ExposureEdgeDragPreview(:final previewLayer):
      return project.copyWith(
        tracks: [
          for (final track in project.tracks)
            track.copyWith(
              cuts: [
                for (final cut in track.cuts)
                  cut.layers.any((layer) => layer.id == previewLayer.id)
                      ? cut.copyWith(
                          layers: [
                            for (final layer in cut.layers)
                              layer.id == previewLayer.id
                                  ? previewLayer
                                  : layer,
                          ],
                        )
                      : cut,
              ],
            ),
        ],
      );
  }
}

/// Wraps one grid row (or X-sheet column) so an edge drag rebuilds ONLY
/// the dragged layer's row: the gate listens to the preview channel and
/// re-runs [rowBuilder] with the preview layer substituted while its layer
/// is the drag target — every other row's gate stays silent. Full visual
/// fidelity (block visuals, SE writing, grips) comes for free because the
/// row builds from the substituted layer.
class TimelineDragPreviewRowGate extends StatefulWidget {
  const TimelineDragPreviewRowGate({
    super.key,
    required this.dragPreview,
    required this.layer,
    required this.rowBuilder,
  });

  /// The session's preview channel; null renders the base row untouched
  /// (grids hosted without a session, e.g. focused widget tests).
  final ValueListenable<TimelineDragPreview?>? dragPreview;

  /// The row's repository layer (the base when no drag targets it).
  final Layer layer;

  final Widget Function(BuildContext context, Layer layer) rowBuilder;

  @override
  State<TimelineDragPreviewRowGate> createState() =>
      _TimelineDragPreviewRowGateState();
}

class _TimelineDragPreviewRowGateState
    extends State<TimelineDragPreviewRowGate> {
  Layer? _previewLayer;

  @override
  void initState() {
    super.initState();
    widget.dragPreview?.addListener(_handlePreviewChanged);
    _previewLayer = _resolvePreviewLayer();
  }

  @override
  void didUpdateWidget(covariant TimelineDragPreviewRowGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dragPreview, widget.dragPreview)) {
      oldWidget.dragPreview?.removeListener(_handlePreviewChanged);
      widget.dragPreview?.addListener(_handlePreviewChanged);
    }
    // A parent rebuild mid-drag (or an element re-match after the row
    // window scrolled) must re-derive against the new layer identity.
    _previewLayer = _resolvePreviewLayer();
  }

  @override
  void dispose() {
    widget.dragPreview?.removeListener(_handlePreviewChanged);
    super.dispose();
  }

  Layer? _resolvePreviewLayer() =>
      timelineDragPreviewLayerFor(widget.dragPreview?.value, widget.layer.id);

  void _handlePreviewChanged() {
    final next = _resolvePreviewLayer();
    if (identical(next, _previewLayer)) {
      return;
    }
    if (next == null && _previewLayer == null) {
      return;
    }
    setState(() => _previewLayer = next);
  }

  @override
  Widget build(BuildContext context) {
    return widget.rowBuilder(context, _previewLayer ?? widget.layer);
  }
}
