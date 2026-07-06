import 'dart:math' as math;

import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/frame.dart';
import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/project.dart';
import '../../models/track.dart';

/// Which frames the export window covers: the active cut, every cut of the
/// active cut's track in storyboard order, or a subrange of the active cut.
enum ExportRange { activeCut, allCuts, frameRange }

/// Output picture size: the project camera frame (rendered through each
/// cut's camera) or the cut's raw canvas (no camera, 1:1 pixels).
enum ExportSizeMode { camera, canvas }

/// Export container. PNG sequence is the only implemented format; video is
/// designed to slot in here later.
enum ExportFormat { pngSequence }

/// One composited output frame: [cut]'s local [frameIndex].
class ExportFrameTask {
  const ExportFrameTask({required this.cut, required this.frameIndex});

  final Cut cut;
  final int frameIndex;
}

/// One instance (cel) output: a unique authored [frame] of [layer], exported
/// as drawn — no compositing.
class ExportCelTask {
  const ExportCelTask({
    required this.cut,
    required this.layer,
    required this.frame,
    required this.fileName,
  });

  final Cut cut;
  final Layer layer;
  final Frame frame;
  final String fileName;
}

/// The cuts the chosen range covers, in play order. [ExportRange.frameRange]
/// is a subrange of the active cut, so it resolves to the active cut alone;
/// [ExportRange.allCuts] follows the playback all-cuts scope (every cut of
/// the track containing the active cut, first track as fallback).
List<Cut> resolveExportCuts({
  required Project project,
  required CutId activeCutId,
  required ExportRange range,
}) {
  Track? activeTrack;
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      if (cut.id == activeCutId) {
        activeTrack = track;
        break;
      }
    }
  }
  activeTrack ??= project.tracks.isEmpty ? null : project.tracks.first;
  if (activeTrack == null) {
    return const [];
  }

  if (range == ExportRange.allCuts) {
    return activeTrack.cuts;
  }
  for (final cut in activeTrack.cuts) {
    if (cut.id == activeCutId) {
      return [cut];
    }
  }
  return const [];
}

/// Ordered composite frames for the chosen range. Every cut plays at least
/// one frame (same floor playback uses). For [ExportRange.frameRange] the
/// 0-based inclusive [rangeStartFrame]/[rangeEndFrame] are clamped to the
/// active cut; a reversed range is empty.
List<ExportFrameTask> buildExportFramePlan({
  required Project project,
  required CutId activeCutId,
  required ExportRange range,
  int? rangeStartFrame,
  int? rangeEndFrame,
}) {
  final cuts = resolveExportCuts(
    project: project,
    activeCutId: activeCutId,
    range: range,
  );

  final plan = <ExportFrameTask>[];
  for (final cut in cuts) {
    final duration = math.max(1, cut.duration);
    var start = 0;
    var end = duration - 1;
    if (range == ExportRange.frameRange) {
      start = (rangeStartFrame ?? 0).clamp(0, duration - 1);
      end = (rangeEndFrame ?? duration - 1).clamp(0, duration - 1);
    }
    for (var frameIndex = start; frameIndex <= end; frameIndex += 1) {
      plan.add(ExportFrameTask(cut: cut, frameIndex: frameIndex));
    }
  }
  return plan;
}

/// Instance-only plan: each unique authored frame (cel) of every visible
/// drawing layer, once, in authored order — regardless of how often (or
/// whether) the timeline exposes it. Camera and hidden layers are skipped.
/// A frame-subrange does not apply to cels, so [ExportRange.frameRange]
/// covers the active cut whole.
List<ExportCelTask> buildExportCelPlan({
  required Project project,
  required CutId activeCutId,
  required ExportRange range,
}) {
  final cuts = resolveExportCuts(
    project: project,
    activeCutId: activeCutId,
    range: range,
  );

  final plan = <ExportCelTask>[];
  final usedNames = <String>{};
  for (final cut in cuts) {
    for (final layer in cut.layers) {
      if (layer.kind == LayerKind.camera || !layer.isVisible) {
        continue;
      }
      for (var index = 0; index < layer.frames.length; index += 1) {
        final base =
            '${sanitizeExportFileComponent(cut.name)}_'
            '${sanitizeExportFileComponent(layer.name)}_'
            '${(index + 1).toString().padLeft(4, '0')}';
        var fileName = '$base.png';
        var bump = 2;
        while (!usedNames.add(fileName)) {
          fileName = '${base}_$bump.png';
          bump += 1;
        }
        plan.add(
          ExportCelTask(
            cut: cut,
            layer: layer,
            frame: layer.frames[index],
            fileName: fileName,
          ),
        );
      }
    }
  }
  return plan;
}

/// Makes a cut/layer name safe as a file-name component: characters Windows
/// forbids become '_', trailing dots/spaces are trimmed, and an empty result
/// falls back to 'untitled'.
String sanitizeExportFileComponent(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  return sanitized.isEmpty ? 'untitled' : sanitized;
}
