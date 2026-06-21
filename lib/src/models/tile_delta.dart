import 'bitmap_tile.dart';
import 'tile_coord.dart';

class TileDelta {
  TileDelta({required this.coord, required this.before, required this.after}) {
    _validate(coord: coord, before: before, after: after);
  }

  factory TileDelta.created(BitmapTile after) {
    return TileDelta(coord: after.coord, before: null, after: after);
  }

  factory TileDelta.removed(BitmapTile before) {
    return TileDelta(coord: before.coord, before: before, after: null);
  }

  factory TileDelta.replaced({
    required BitmapTile before,
    required BitmapTile after,
  }) {
    return TileDelta(coord: before.coord, before: before, after: after);
  }

  final TileCoord coord;
  final BitmapTile? before;
  final BitmapTile? after;

  bool get isCreation => before == null && after != null;

  bool get isRemoval => before != null && after == null;

  bool get isReplacement => before != null && after != null;

  int get tileSize => before?.size ?? after!.size;

  TileDelta copyWith({
    TileCoord? coord,
    Object? before = _copyWithSentinel,
    Object? after = _copyWithSentinel,
  }) {
    return TileDelta(
      coord: coord ?? this.coord,
      before: identical(before, _copyWithSentinel)
          ? this.before
          : before as BitmapTile?,
      after: identical(after, _copyWithSentinel)
          ? this.after
          : after as BitmapTile?,
    );
  }

  Map<String, dynamic> toJson() => {
    'coord': coord.toJson(),
    'before': before?.toJson(),
    'after': after?.toJson(),
  };

  factory TileDelta.fromJson(Map<String, dynamic> json) {
    return TileDelta(
      coord: TileCoord.fromJson(json['coord'] as Map<String, dynamic>),
      before: json['before'] == null
          ? null
          : BitmapTile.fromJson(json['before'] as Map<String, dynamic>),
      after: json['after'] == null
          ? null
          : BitmapTile.fromJson(json['after'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileDelta &&
          other.coord == coord &&
          other.before == before &&
          other.after == after;

  @override
  int get hashCode => Object.hash(coord, before, after);

  @override
  String toString() =>
      'TileDelta(coord: $coord, before: $before, after: $after)';
}

void _validate({
  required TileCoord coord,
  required BitmapTile? before,
  required BitmapTile? after,
}) {
  if (before == null && after == null) {
    throw ArgumentError('TileDelta before and after must not both be null.');
  }
  if (before != null && before.coord != coord) {
    throw ArgumentError.value(
      before.coord,
      'before.coord',
      'TileDelta before coord must match coord.',
    );
  }
  if (after != null && after.coord != coord) {
    throw ArgumentError.value(
      after.coord,
      'after.coord',
      'TileDelta after coord must match coord.',
    );
  }
  if (before != null && after != null && before.size != after.size) {
    throw ArgumentError.value(
      after.size,
      'after.size',
      'TileDelta before and after tile sizes must match.',
    );
  }
  if (before != null && after != null && before == after) {
    throw ArgumentError('TileDelta before and after must differ.');
  }
}

const Object _copyWithSentinel = Object();
