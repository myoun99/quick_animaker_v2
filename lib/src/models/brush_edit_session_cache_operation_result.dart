import 'brush_edit_history_entry.dart';
import 'brush_edit_session_operation_kind.dart';
import 'brush_edit_session_state.dart';
import 'cache_invalidation_execution_result.dart';

const Object _copyWithSentinel = Object();

class BrushEditSessionCacheOperationResult {
  BrushEditSessionCacheOperationResult({
    required this.kind,
    required this.sessionState,
    required this.affectedEntry,
    required this.cacheInvalidationResult,
  });

  final BrushEditSessionOperationKind kind;
  final BrushEditSessionState sessionState;
  final BrushEditHistoryEntry? affectedEntry;
  final CacheInvalidationExecutionResult cacheInvalidationResult;

  bool get didAffectHistory => affectedEntry != null;

  bool get didInvalidateCache => cacheInvalidationResult.didInvalidate;

  BrushEditSessionCacheOperationResult copyWith({
    BrushEditSessionOperationKind? kind,
    BrushEditSessionState? sessionState,
    Object? affectedEntry = _copyWithSentinel,
    CacheInvalidationExecutionResult? cacheInvalidationResult,
  }) {
    return BrushEditSessionCacheOperationResult(
      kind: kind ?? this.kind,
      sessionState: sessionState ?? this.sessionState,
      affectedEntry: identical(affectedEntry, _copyWithSentinel)
          ? this.affectedEntry
          : affectedEntry as BrushEditHistoryEntry?,
      cacheInvalidationResult:
          cacheInvalidationResult ?? this.cacheInvalidationResult,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditSessionCacheOperationResult &&
          other.kind == kind &&
          other.sessionState == sessionState &&
          other.affectedEntry == affectedEntry &&
          other.cacheInvalidationResult == cacheInvalidationResult;

  @override
  int get hashCode =>
      Object.hash(kind, sessionState, affectedEntry, cacheInvalidationResult);

  @override
  String toString() =>
      'BrushEditSessionCacheOperationResult(kind: $kind, '
      'sessionState: $sessionState, affectedEntry: $affectedEntry, '
      'cacheInvalidationResult: $cacheInvalidationResult)';
}
