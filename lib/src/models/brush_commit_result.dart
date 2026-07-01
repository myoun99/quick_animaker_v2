import 'bitmap_surface.dart';
import 'cache_invalidation_plan.dart';
import 'dirty_tile_set.dart';

class BrushCommitResult {
  BrushCommitResult({
    required this.beforeSurface,
    required this.afterSurface,
    required this.dirtyTiles,
    required this.cacheInvalidationPlan,
  }) {
    _validate(
      beforeSurface: beforeSurface,
      afterSurface: afterSurface,
      dirtyTiles: dirtyTiles,
      cacheInvalidationPlan: cacheInvalidationPlan,
    );
  }

  factory BrushCommitResult.noOp({required BitmapSurface surface}) {
    return BrushCommitResult(
      beforeSurface: surface,
      afterSurface: surface,
      dirtyTiles: DirtyTileSet.empty(),
      cacheInvalidationPlan: CacheInvalidationPlan.empty(),
    );
  }

  factory BrushCommitResult.changed({
    required BitmapSurface beforeSurface,
    required BitmapSurface afterSurface,
    required DirtyTileSet dirtyTiles,
    required CacheInvalidationPlan cacheInvalidationPlan,
  }) {
    return BrushCommitResult(
      beforeSurface: beforeSurface,
      afterSurface: afterSurface,
      dirtyTiles: dirtyTiles,
      cacheInvalidationPlan: cacheInvalidationPlan,
    );
  }

  final BitmapSurface beforeSurface;
  final BitmapSurface afterSurface;
  final DirtyTileSet dirtyTiles;
  final CacheInvalidationPlan cacheInvalidationPlan;

  bool get hasChanges => dirtyTiles.isNotEmpty;

  bool get isNoOp => !hasChanges;

  int get changedTileCount => dirtyTiles.length;

  BrushCommitResult copyWith({
    BitmapSurface? beforeSurface,
    BitmapSurface? afterSurface,
    DirtyTileSet? dirtyTiles,
    CacheInvalidationPlan? cacheInvalidationPlan,
  }) {
    return BrushCommitResult(
      beforeSurface: beforeSurface ?? this.beforeSurface,
      afterSurface: afterSurface ?? this.afterSurface,
      dirtyTiles: dirtyTiles ?? this.dirtyTiles,
      cacheInvalidationPlan:
          cacheInvalidationPlan ?? this.cacheInvalidationPlan,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushCommitResult &&
          other.beforeSurface == beforeSurface &&
          other.afterSurface == afterSurface &&
          other.dirtyTiles == dirtyTiles &&
          other.cacheInvalidationPlan == cacheInvalidationPlan;

  @override
  int get hashCode => Object.hash(
    beforeSurface,
    afterSurface,
    dirtyTiles,
    cacheInvalidationPlan,
  );

  @override
  String toString() =>
      'BrushCommitResult(dirtyTiles: $dirtyTiles, '
      'cacheInvalidationPlan: $cacheInvalidationPlan)';
}

void _validate({
  required BitmapSurface beforeSurface,
  required BitmapSurface afterSurface,
  required DirtyTileSet dirtyTiles,
  required CacheInvalidationPlan cacheInvalidationPlan,
}) {
  if (beforeSurface.canvasSize != afterSurface.canvasSize ||
      beforeSurface.tileSize != afterSurface.tileSize) {
    throw ArgumentError(
      'BrushCommitResult beforeSurface and afterSurface must describe the same bitmap surface bounds.',
    );
  }
  if (dirtyTiles.isEmpty && cacheInvalidationPlan.isNotEmpty) {
    throw ArgumentError(
      'BrushCommitResult with no dirty tiles must have an empty cacheInvalidationPlan.',
    );
  }
  if (dirtyTiles.isNotEmpty && cacheInvalidationPlan.isEmpty) {
    throw ArgumentError(
      'BrushCommitResult with dirty tiles must have a non-empty cacheInvalidationPlan.',
    );
  }
}
