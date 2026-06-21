import 'bitmap_surface.dart';
import 'bitmap_tile.dart';
import 'dirty_tile_set.dart';
import 'tile_coord.dart';
import 'tile_delta.dart';

class TileDeltaCommand {
  TileDeltaCommand({required Iterable<TileDelta> deltas})
    : _deltasByCoord = Map<TileCoord, TileDelta>.unmodifiable(
        _validatedDeltasByCoord(deltas),
      );

  final Map<TileCoord, TileDelta> _deltasByCoord;

  List<TileDelta> get deltas => List.unmodifiable(_sortedDeltas);

  DirtyTileSet get dirtyTiles => DirtyTileSet(_deltasByCoord.keys);

  int get length => _deltasByCoord.length;

  bool containsCoord(TileCoord coord) => _deltasByCoord.containsKey(coord);

  TileDelta? deltaFor(TileCoord coord) => _deltasByCoord[coord];

  BitmapSurface applyBefore(BitmapSurface surface) {
    validateAgainstSurface(surface);
    return _apply(surface, (delta) => delta.before);
  }

  BitmapSurface applyAfter(BitmapSurface surface) {
    validateAgainstSurface(surface);
    return _apply(surface, (delta) => delta.after);
  }

  void validateAgainstSurface(BitmapSurface surface) {
    for (final delta in _deltasByCoord.values) {
      if (!surface.containsTileCoord(delta.coord)) {
        throw ArgumentError.value(
          delta.coord,
          'delta.coord',
          'TileDeltaCommand delta coord must be inside surface tile bounds.',
        );
      }
      _validateTileAgainstSurface(delta.before, surface, 'before');
      _validateTileAgainstSurface(delta.after, surface, 'after');
    }
  }

  Map<String, dynamic> toJson() => {
    'deltas': deltas.map((delta) => delta.toJson()).toList(),
  };

  factory TileDeltaCommand.fromJson(Map<String, dynamic> json) {
    return TileDeltaCommand(
      deltas: (json['deltas'] as List? ?? const []).map(
        (deltaJson) => TileDelta.fromJson(deltaJson as Map<String, dynamic>),
      ),
    );
  }

  List<TileDelta> get _sortedDeltas {
    return _deltasByCoord.values.toList()
      ..sort((a, b) {
        final yComparison = a.coord.y.compareTo(b.coord.y);
        if (yComparison != 0) return yComparison;
        return a.coord.x.compareTo(b.coord.x);
      });
  }

  BitmapSurface _apply(
    BitmapSurface surface,
    BitmapTile? Function(TileDelta delta) tileForDelta,
  ) {
    var next = surface;
    for (final delta in _sortedDeltas) {
      final tile = tileForDelta(delta);
      next = tile == null ? next.removeTile(delta.coord) : next.putTile(tile);
    }
    return next;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileDeltaCommand &&
          _mapEquals(other._deltasByCoord, _deltasByCoord);

  @override
  int get hashCode => Object.hashAllUnordered(
    _deltasByCoord.values.map((delta) => Object.hash(delta.coord, delta)),
  );

  @override
  String toString() => 'TileDeltaCommand(length: $length, deltas: $deltas)';
}

Map<TileCoord, TileDelta> _validatedDeltasByCoord(Iterable<TileDelta> deltas) {
  final byCoord = <TileCoord, TileDelta>{};
  for (final delta in deltas) {
    if (byCoord.containsKey(delta.coord)) {
      throw ArgumentError.value(
        delta.coord,
        'deltas',
        'TileDeltaCommand deltas must not contain duplicate coords.',
      );
    }
    byCoord[delta.coord] = delta;
  }
  if (byCoord.isEmpty) {
    throw ArgumentError('TileDeltaCommand deltas must not be empty.');
  }
  return byCoord;
}

void _validateTileAgainstSurface(
  BitmapTile? tile,
  BitmapSurface surface,
  String fieldName,
) {
  if (tile == null) return;
  if (tile.size != surface.tileSize) {
    throw ArgumentError.value(
      tile.size,
      fieldName,
      'TileDeltaCommand $fieldName tile size must match surface tileSize.',
    );
  }
}

bool _mapEquals(Map<TileCoord, TileDelta> a, Map<TileCoord, TileDelta> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
