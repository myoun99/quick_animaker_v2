import '../models/cut_id.dart';
import '../models/project.dart';
import 'cut_list_helpers.dart';

/// R28 #14: [emptyTrack] replaced the old `createDefaultCut`. Deleting the
/// only cut leaves NO cut selected instead of conjuring a replacement —
/// "컷도 1개도 없는 상황 허용". The no-active-cut state is one the editor
/// already renders (a storyboard gap parks there), so nothing new had to
/// learn about it.
enum CutDeletionFallbackKind { useExistingCut, emptyTrack }

class CutDeletionFallbackDecision {
  const CutDeletionFallbackDecision.useExistingCut(this.cutId)
    : kind = CutDeletionFallbackKind.useExistingCut;

  const CutDeletionFallbackDecision.emptyTrack()
    : kind = CutDeletionFallbackKind.emptyTrack,
      cutId = null;

  final CutDeletionFallbackKind kind;
  final CutId? cutId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CutDeletionFallbackDecision &&
          other.kind == kind &&
          other.cutId == cutId;

  @override
  int get hashCode => Object.hash(kind, cutId);

  @override
  String toString() =>
      'CutDeletionFallbackDecision(kind: $kind, cutId: $cutId)';
}

CutDeletionFallbackDecision cutDeletionFallbackFor(
  Project project, {
  required CutId deletingCutId,
}) {
  final cutIds = cutListEntriesFor(
    project,
  ).map((entry) => entry.cutId).toList(growable: false);
  final deletingCutIndex = cutIds.indexOf(deletingCutId);

  if (deletingCutIndex == -1) {
    throw StateError('Project does not contain cut ${deletingCutId.value}.');
  }

  if (deletingCutIndex > 0) {
    return CutDeletionFallbackDecision.useExistingCut(
      cutIds[deletingCutIndex - 1],
    );
  }

  if (cutIds.length > 1) {
    return CutDeletionFallbackDecision.useExistingCut(cutIds[1]);
  }

  return const CutDeletionFallbackDecision.emptyTrack();
}
