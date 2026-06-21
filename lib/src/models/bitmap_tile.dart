import 'dart:typed_data';

import 'tile_coord.dart';

class BitmapTile {
  BitmapTile({
    required this.coord,
    required this.size,
    required Uint8List pixels,
  }) : _pixels = Uint8List.fromList(pixels) {
    _validateSize(size);
    _validatePixelLength(_pixels.length, size);
  }

  factory BitmapTile.blank({required TileCoord coord, required int size}) {
    _validateSize(size);
    return BitmapTile(
      coord: coord,
      size: size,
      pixels: Uint8List(size * size * bytesPerPixel),
    );
  }

  static const int bytesPerPixel = 4;

  final TileCoord coord;
  final int size;
  final Uint8List _pixels;

  Uint8List get pixels => Uint8List.fromList(_pixels);

  bool get isFullyTransparent {
    for (final byte in _pixels) {
      if (byte != 0) return false;
    }
    return true;
  }

  int byteOffsetForPixel({required int x, required int y}) {
    if (x < 0) {
      throw ArgumentError.value(
        x,
        'x',
        'BitmapTile pixel x must be greater than or equal to 0.',
      );
    }
    if (y < 0) {
      throw ArgumentError.value(
        y,
        'y',
        'BitmapTile pixel y must be greater than or equal to 0.',
      );
    }
    if (x >= size) {
      throw ArgumentError.value(x, 'x', 'BitmapTile pixel x must be < size.');
    }
    if (y >= size) {
      throw ArgumentError.value(y, 'y', 'BitmapTile pixel y must be < size.');
    }
    return (y * size + x) * bytesPerPixel;
  }

  BitmapTile copyWith({TileCoord? coord, int? size, Uint8List? pixels}) {
    return BitmapTile(
      coord: coord ?? this.coord,
      size: size ?? this.size,
      pixels: pixels ?? _pixels,
    );
  }

  Map<String, dynamic> toJson() => {
    'coord': coord.toJson(),
    'size': size,
    'pixels': _pixels.toList(),
  };

  factory BitmapTile.fromJson(Map<String, dynamic> json) {
    return BitmapTile(
      coord: TileCoord.fromJson(json['coord'] as Map<String, dynamic>),
      size: json['size'] as int,
      pixels: Uint8List.fromList((json['pixels'] as List).cast<int>()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BitmapTile &&
          other.coord == coord &&
          other.size == size &&
          _listEquals(other._pixels, _pixels);

  @override
  int get hashCode => Object.hash(coord, size, Object.hashAll(_pixels));

  @override
  String toString() =>
      'BitmapTile(coord: $coord, size: $size, pixelLength: ${_pixels.length})';
}

void _validateSize(int size) {
  if (size <= 0) {
    throw ArgumentError.value(
      size,
      'size',
      'BitmapTile.size must be greater than 0.',
    );
  }
}

void _validatePixelLength(int length, int size) {
  final expected = size * size * BitmapTile.bytesPerPixel;
  if (length != expected) {
    throw ArgumentError.value(
      length,
      'pixels',
      'BitmapTile.pixels length must equal size * size * 4 ($expected).',
    );
  }
}

bool _listEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
