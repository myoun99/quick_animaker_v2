import 'bitmap_surface.dart';
import 'brush_commit_result.dart';

class BrushSurfaceEdit {
  BrushSurfaceEdit({
    required this.beforeSurface,
    required this.afterSurface,
    required this.commitResult,
  }) {
    if (commitResult.isNoOp && beforeSurface != afterSurface) {
      throw ArgumentError(
        'BrushSurfaceEdit no-op edits must have equal before and after surfaces.',
      );
    }
  }

  final BitmapSurface beforeSurface;
  final BitmapSurface afterSurface;
  final BrushCommitResult commitResult;

  bool get hasChanges => commitResult.hasChanges;

  bool get isNoOp => commitResult.isNoOp;

  BitmapSurface get effectiveSurface => afterSurface;

  BrushSurfaceEdit copyWith({
    BitmapSurface? beforeSurface,
    BitmapSurface? afterSurface,
    BrushCommitResult? commitResult,
  }) {
    return BrushSurfaceEdit(
      beforeSurface: beforeSurface ?? this.beforeSurface,
      afterSurface: afterSurface ?? this.afterSurface,
      commitResult: commitResult ?? this.commitResult,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushSurfaceEdit &&
          other.beforeSurface == beforeSurface &&
          other.afterSurface == afterSurface &&
          other.commitResult == commitResult;

  @override
  int get hashCode => Object.hash(beforeSurface, afterSurface, commitResult);

  @override
  String toString() =>
      'BrushSurfaceEdit(beforeSurface: $beforeSurface, '
      'afterSurface: $afterSurface, commitResult: $commitResult)';
}
