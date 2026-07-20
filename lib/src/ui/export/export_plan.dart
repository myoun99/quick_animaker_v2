import 'dart:math' as math;

import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/frame.dart';
import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/project.dart';
import '../../models/project_frame_rate.dart';
import '../../models/se_audio_spans.dart';
import '../../models/track.dart';
import 'video_export_service.dart' show ExportAudioClip;

/// Which frames the export window covers: the active cut, every cut of the
/// active cut's track in storyboard order, or a subrange of the active cut.
enum ExportRange { activeCut, allCuts, frameRange }

/// Output picture size: the project camera frame (rendered through each
/// cut's camera) or the cut's raw canvas (no camera, 1:1 pixels).
enum ExportSizeMode { camera, canvas }

/// Export container: a PNG file per frame, one H.264 MP4 encoded through
/// an external ffmpeg (see VideoExportService), or XDTS digital timesheets
/// (one .xdts per cut — sheet data, no rendering).
enum ExportFormat { pngSequence, mp4Video, xdtsTimesheet }

/// One composited output frame: [cut]'s local [frameIndex]. A negative
/// [frameIndex] is a frame of [cut]'s LEADING GAP (empty space before the
/// cut, played and exported as black): -1 is the gap frame right before
/// local 0, -leadingGapFrames the gap's first.
class ExportFrameTask {
  const ExportFrameTask({required this.cut, required this.frameIndex});

  final Cut cut;
  final int frameIndex;

  /// Renders as a black frame instead of compositing [cut].
  bool get isGap => frameIndex < 0;
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

  /// Relative to the export directory; may contain `/` subfolders.
  final String fileName;
}

/// How cel files are named and foldered (CSP-style cel export options).
///
/// The name is `[project_][cut_][layer]frame[suffix].png`: project/cut
/// prefixes join with '_', the layer name sits directly against the frame
/// name (layer 'A' + frame '1' = 'A1'). The frame name is [Frame.name],
/// falling back to the cel's 1-based position when unnamed.
class ExportCelNaming {
  const ExportCelNaming({
    this.includeProjectName = false,
    this.includeCutName = false,
    this.includeLayerName = true,
    this.frameDigits = 0,
    this.suffix = '',
    this.cutFolder = false,
    this.layerFolder = false,
  });

  final bool includeProjectName;
  final bool includeCutName;
  final bool includeLayerName;

  /// 0 = off; otherwise the first digit run in the frame name is left-padded
  /// with zeros to this width ('1' → '0001' at 4). Names without any digits
  /// are left alone.
  final int frameDigits;

  /// Appended right before '.png' (TVPaint's 後ろ文字付け).
  final String suffix;

  /// Per-cut / per-layer subfolders under the export directory.
  final bool cutFolder;
  final bool layerFolder;
}

/// Pads the first digit run in [name] to [digits] ('1' → '0001', 'a12b' →
/// 'a0012b' at 4). Runs already at least [digits] wide and names without
/// digits are unchanged.
String padFrameNumber(String name, int digits) {
  if (digits <= 0) {
    return name;
  }
  final match = RegExp(r'\d+').firstMatch(name);
  if (match == null) {
    return name;
  }
  final run = match.group(0)!;
  if (run.length >= digits) {
    return name;
  }
  return name.replaceRange(match.start, match.end, run.padLeft(digits, '0'));
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
///
/// [includeGaps] adds each cut's leading gap as black-frame tasks
/// (negative frame indexes) so the output matches all-cuts playback
/// frame for frame — video wants this, a PNG sequence skips the gaps.
/// Single-cut ranges never include a gap (single-cut playback doesn't
/// play one either).
List<ExportFrameTask> buildExportFramePlan({
  required Project project,
  required CutId activeCutId,
  required ExportRange range,
  int? rangeStartFrame,
  int? rangeEndFrame,
  bool includeGaps = false,
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
    if (includeGaps && range == ExportRange.allCuts) {
      for (var gap = -cut.leadingGapFrames; gap < 0; gap += 1) {
        plan.add(ExportFrameTask(cut: cut, frameIndex: gap));
      }
    }
    for (var frameIndex = start; frameIndex <= end; frameIndex += 1) {
      plan.add(ExportFrameTask(cut: cut, frameIndex: frameIndex));
    }
  }
  return plan;
}

/// Lays every SE layer's audio clips onto the exported video's timeline.
///
/// [plan] lists the exported frames in output order (contiguous per cut),
/// exactly what [VideoExportService] encodes — so a clip's offset is just
/// its position within its cut's block. Clips starting before the exported
/// range seek into the source instead of delaying; clips starting at or
/// past their cut's exported end are silent and dropped. Durations cap at
/// the cut's exported block, matching canvas playback (SE audio never
/// bleeds into the next cut); shorter sources simply end early.
List<ExportAudioClip> buildExportAudioPlan({
  required List<ExportFrameTask> plan,
  required ProjectFrameRate frameRate,
  Project? project,
}) {
  final clips = <ExportAudioClip>[];

  void emit({
    required int spanExportStart,
    required int audibleStart,
    required int audibleEnd,
    required SeAudioSpan span,
  }) {
    if (audibleEnd <= audibleStart) {
      return;
    }
    final audibleFrames = audibleEnd - audibleStart;
    // Fade windows in the TRIMMED clip's own time: the fade-in anchors to
    // the span (block) start — a range starting mid-fade keeps only the
    // remainder — and the fade-out anchors to the audible end, both capped
    // at the audible length (same anchors playback ramps).
    final fadeInFrames =
        (spanExportStart + span.clip.fadeInFrames - audibleStart).clamp(
          0,
          audibleFrames,
        );
    final fadeOutFrames = span.clip.fadeOutFrames.clamp(0, audibleFrames);
    clips.add(
      ExportAudioClip(
        filePath: span.clip.filePath,
        // The clip's offset trim seeks past the skipped file head on top
        // of any range clipping.
        seekSeconds: frameRate.frameStartSeconds(
          audibleStart - spanExportStart + span.clip.offsetFrames,
        ),
        delaySeconds: frameRate.frameStartSeconds(audibleStart),
        durationSeconds: frameRate.frameStartSeconds(audibleFrames),
        gain: span.clip.gain,
        fadeInSeconds: frameRate.frameStartSeconds(fadeInFrames),
        fadeOutSeconds: frameRate.frameStartSeconds(fadeOutFrames),
      ),
    );
  }

  // Track starts for the TRACK-owned SE rows (global axis, cut-crossing).
  final trackStartByCutId = <CutId, int>{};
  final trackByCutId = <CutId, Track>{};
  if (project != null) {
    for (final track in project.tracks) {
      var start = 0;
      for (final cut in track.cuts) {
        start += cut.leadingGapFrames;
        trackStartByCutId[cut.id] = start;
        trackByCutId[cut.id] = track;
        start += cut.duration;
      }
    }
  }

  var blockStart = 0;
  while (blockStart < plan.length) {
    final cut = plan[blockStart].cut;
    var blockEnd = blockStart;
    while (blockEnd < plan.length && plan[blockEnd].cut.id == cut.id) {
      blockEnd += 1;
    }
    final firstFrameIndex = plan[blockStart].frameIndex;

    // Legacy path: cut-owned SE layers (test fixtures; production cuts no
    // longer carry SE rows). Ends clamp at the cut's exported block.
    for (final layer in cut.layers) {
      if (layer.kind != LayerKind.se || layer.muted) {
        continue;
      }
      for (final span in seAudioSpans(layer)) {
        final offsetFrames = blockStart + (span.startFrame - firstFrameIndex);
        if (offsetFrames >= blockEnd) {
          continue;
        }
        emit(
          spanExportStart: offsetFrames,
          audibleStart: math.max(blockStart, offsetFrames),
          audibleEnd: math.min(blockEnd, offsetFrames + span.lengthFrames),
          span: span,
        );
      }
    }

    // Track-owned SE rows: spans sit on the track's global axis and may
    // cross cut boundaries. Each span is laid once — at the block where it
    // starts (or a run-start block it spills into) — and runs to its true
    // end, clamped where the exported sequence stops being contiguous with
    // the track (a frame-subrange boundary, a skipped cut).
    final track = trackByCutId[cut.id];
    final cutTrackStart = trackStartByCutId[cut.id];
    if (track != null && cutTrackStart != null) {
      final windowTrackStart = cutTrackStart + firstFrameIndex;

      // Contiguous = the next block's first exported frame sits exactly
      // where the previous cut ended on the TRACK axis: back-to-back cuts,
      // or a leading gap the plan exports as black frames (the next task's
      // frameIndex is then the negative gap index, offsetting its cut's
      // track start back to the gap's first frame). A gap the plan SKIPS
      // breaks the run — the exported timeline collapsed it.
      bool blocksContiguous(int endIndex) {
        if (endIndex >= plan.length) {
          return false;
        }
        final prevTask = plan[endIndex - 1];
        final nextTask = plan[endIndex];
        final nextTrackStart = trackStartByCutId[nextTask.cut.id];
        return nextTrackStart != null &&
            identical(trackByCutId[nextTask.cut.id], track) &&
            prevTask.frameIndex == prevTask.cut.duration - 1 &&
            nextTrackStart + nextTask.frameIndex ==
                (trackStartByCutId[prevTask.cut.id] ?? 0) +
                    prevTask.cut.duration;
      }

      var runEnd = blockEnd;
      while (blocksContiguous(runEnd)) {
        final nextCutId = plan[runEnd].cut.id;
        while (runEnd < plan.length && plan[runEnd].cut.id == nextCutId) {
          runEnd += 1;
        }
      }
      final isRunStart =
          blockStart == 0 ||
          !(plan[blockStart - 1].frameIndex ==
                  plan[blockStart - 1].cut.duration - 1 &&
              identical(trackByCutId[plan[blockStart - 1].cut.id], track) &&
              (trackStartByCutId[plan[blockStart - 1].cut.id] ?? -1) +
                      plan[blockStart - 1].cut.duration ==
                  cutTrackStart + firstFrameIndex);

      for (final layer in track.seLayers) {
        if (layer.muted) {
          continue;
        }
        for (final span in seAudioSpans(layer)) {
          final exportPos = blockStart + (span.startFrame - windowTrackStart);
          final startsHere = exportPos >= blockStart && exportPos < blockEnd;
          final spillsIn =
              isRunStart &&
              exportPos < blockStart &&
              exportPos + span.lengthFrames > blockStart;
          if (!startsHere && !spillsIn) {
            continue;
          }
          emit(
            spanExportStart: exportPos,
            audibleStart: math.max(blockStart, exportPos),
            audibleEnd: math.min(runEnd, exportPos + span.lengthFrames),
            span: span,
          );
        }
      }
    }
    blockStart = blockEnd;
  }
  return clips;
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
  ExportCelNaming naming = const ExportCelNaming(),
  bool onTimesheetOnly = false,
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
      // Cel-export scope: the timesheet toggle on layer labels marks which
      // layers belong to the sheet output.
      if (onTimesheetOnly && !layer.onTimesheet) {
        continue;
      }
      for (var index = 0; index < layer.frames.length; index += 1) {
        final frame = layer.frames[index];
        final base = _celFileBase(
          projectName: project.name,
          cut: cut,
          layer: layer,
          frame: frame,
          celPosition: index + 1,
          naming: naming,
        );
        final folder = [
          if (naming.cutFolder) sanitizeExportFileComponent(cut.name),
          if (naming.layerFolder) sanitizeExportFileComponent(layer.name),
        ].join('/');
        final prefix = folder.isEmpty ? '' : '$folder/';
        var fileName = '$prefix$base.png';
        var bump = 2;
        while (!usedNames.add(fileName)) {
          fileName = '$prefix${base}_$bump.png';
          bump += 1;
        }
        plan.add(
          ExportCelTask(
            cut: cut,
            layer: layer,
            frame: frame,
            fileName: fileName,
          ),
        );
      }
    }
  }
  return plan;
}

String _celFileBase({
  required String projectName,
  required Cut cut,
  required Layer layer,
  required Frame frame,
  required int celPosition,
  required ExportCelNaming naming,
}) {
  final rawFrameName = (frame.name ?? '').trim();
  final frameName = padFrameNumber(
    rawFrameName.isEmpty ? '$celPosition' : rawFrameName,
    naming.frameDigits,
  );

  final prefixes = [
    if (naming.includeProjectName) sanitizeExportFileComponent(projectName),
    if (naming.includeCutName) sanitizeExportFileComponent(cut.name),
  ];
  final buffer = StringBuffer();
  if (prefixes.isNotEmpty) {
    buffer
      ..writeAll(prefixes, '_')
      ..write('_');
  }
  if (naming.includeLayerName) {
    buffer.write(sanitizeExportFileComponent(layer.name));
  }
  buffer.write(sanitizeExportFileComponent(frameName));
  final suffix = naming.suffix.trim();
  if (suffix.isNotEmpty) {
    buffer.write(sanitizeExportFileComponent(suffix));
  }
  return buffer.toString();
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
