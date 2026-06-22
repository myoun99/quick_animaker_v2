import 'cache_invalidation_plan.dart';
import 'dirty_tile_set.dart';
import 'tile_delta_command.dart';

class BrushCommitResult {
  BrushCommitResult({
    required this.command,
    required this.cacheInvalidationPlan,
  }) {
    _validate(command: command, cacheInvalidationPlan: cacheInvalidationPlan);
  }

  factory BrushCommitResult.noOp() {
    return BrushCommitResult(
      command: null,
      cacheInvalidationPlan: CacheInvalidationPlan.empty(),
    );
  }

  factory BrushCommitResult.changed({
    required TileDeltaCommand command,
    required CacheInvalidationPlan cacheInvalidationPlan,
  }) {
    return BrushCommitResult(
      command: command,
      cacheInvalidationPlan: cacheInvalidationPlan,
    );
  }

  final TileDeltaCommand? command;
  final CacheInvalidationPlan cacheInvalidationPlan;

  bool get hasChanges => command != null;

  bool get isNoOp => !hasChanges;

  int get changedTileCount => command?.length ?? 0;

  DirtyTileSet get dirtyTiles => command?.dirtyTiles ?? DirtyTileSet.empty();

  BrushCommitResult copyWith({
    Object? command = _copyWithSentinel,
    CacheInvalidationPlan? cacheInvalidationPlan,
  }) {
    return BrushCommitResult(
      command: identical(command, _copyWithSentinel)
          ? this.command
          : command as TileDeltaCommand?,
      cacheInvalidationPlan:
          cacheInvalidationPlan ?? this.cacheInvalidationPlan,
    );
  }

  Map<String, dynamic> toJson() => {
    'command': command?.toJson(),
    'cacheInvalidationPlan': cacheInvalidationPlan.toJson(),
  };

  factory BrushCommitResult.fromJson(Map<String, dynamic> json) {
    return BrushCommitResult(
      command: json['command'] == null
          ? null
          : TileDeltaCommand.fromJson(json['command'] as Map<String, dynamic>),
      cacheInvalidationPlan: CacheInvalidationPlan.fromJson(
        json['cacheInvalidationPlan'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushCommitResult &&
          other.command == command &&
          other.cacheInvalidationPlan == cacheInvalidationPlan;

  @override
  int get hashCode => Object.hash(command, cacheInvalidationPlan);

  @override
  String toString() =>
      'BrushCommitResult(command: $command, '
      'cacheInvalidationPlan: $cacheInvalidationPlan)';
}

void _validate({
  required TileDeltaCommand? command,
  required CacheInvalidationPlan cacheInvalidationPlan,
}) {
  if (command == null && cacheInvalidationPlan.isNotEmpty) {
    throw ArgumentError(
      'BrushCommitResult with null command must have an empty '
      'cacheInvalidationPlan.',
    );
  }
  if (command != null && cacheInvalidationPlan.isEmpty) {
    throw ArgumentError(
      'BrushCommitResult with a command must have a non-empty '
      'cacheInvalidationPlan.',
    );
  }
}

const Object _copyWithSentinel = Object();
