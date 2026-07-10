import '../../models/cut_id.dart';
import '../../models/transform_track.dart';
import '../command.dart';
import '../project_repository.dart';

/// One undoable cut edge-drag step (storyboard grips): applies a set of
/// cut durations AND leading gaps at once — an end trim can consume the
/// following cut's gap, a start slide edits only the gap. Execute is
/// idempotent.
///
/// The transform maps carry the fade-durability rewrite (W4): a trim
/// re-anchors the CANONICAL fade envelope to the new duration (the
/// fade-out keeps riding the cut's end), captured before/after so undo
/// restores the exact original keys. Hand-keyed opacity lanes never
/// appear here — the caller only rewrites canonical shapes.
class UpdateCutDurationsCommand implements Command {
  UpdateCutDurationsCommand({
    required this.repository,
    required this.before,
    required this.after,
    this.beforeGaps = const {},
    this.afterGaps = const {},
    this.beforeTransforms = const {},
    this.afterTransforms = const {},
  }) : assert(before.keys.length == after.keys.length),
       assert(beforeGaps.keys.length == afterGaps.keys.length),
       assert(beforeTransforms.keys.length == afterTransforms.keys.length);

  final ProjectRepository repository;
  final Map<CutId, int> before;
  final Map<CutId, int> after;
  final Map<CutId, int> beforeGaps;
  final Map<CutId, int> afterGaps;
  final Map<CutId, TransformTrack> beforeTransforms;
  final Map<CutId, TransformTrack> afterTransforms;

  @override
  String get description => 'Trim cut duration';

  void _apply(
    Map<CutId, int> durations,
    Map<CutId, int> gaps,
    Map<CutId, TransformTrack> transforms,
  ) {
    for (final entry in durations.entries) {
      repository.updateCutDuration(cutId: entry.key, duration: entry.value);
    }
    for (final entry in gaps.entries) {
      repository.updateCutLeadingGap(
        cutId: entry.key,
        leadingGapFrames: entry.value,
      );
    }
    for (final entry in transforms.entries) {
      repository.updateCutTransform(
        cutId: entry.key,
        transformTrack: entry.value,
      );
    }
  }

  @override
  void execute() => _apply(after, afterGaps, afterTransforms);

  @override
  void undo() => _apply(before, beforeGaps, beforeTransforms);
}
