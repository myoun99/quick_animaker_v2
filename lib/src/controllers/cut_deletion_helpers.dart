import '../models/cut_id.dart';
import '../models/project.dart';
import 'cut_list_helpers.dart';

enum CutDeletionFallbackKind { useExistingCut, createDefaultCut }

class CutDeletionFallbackDecision {
  const CutDeletionFallbackDecision.useExistingCut(this.cutId)
      : kind = CutDeletionFallbackKind.useExistingCut;

  const CutDeletionFallbackDecision.createDefaultCut()
      : kind = CutDeletionFallbackKind.createDefaultCut,
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

  return const CutDeletionFallbackDecision.createDefaultCut();
}
