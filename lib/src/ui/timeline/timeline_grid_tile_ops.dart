import 'dart:typed_data';
import 'dart:ui' show Color;

/// The grid-tile op stream (UI-R18 O7 / R18-T T1): the timeline frame
/// grids describe a tile's contents as a flat int32 word list — flat
/// rect fills, hairlines and A8-atlas glyph blits, which is the WHOLE
/// post-O1 cell visual language — and the native `qa_grid_raster_tile`
/// rasterizes it off the UI thread. [timelineGridRasterTileReference]
/// is the Dart source of truth for the semantics (the engine's
/// load-fallback discipline): byte parity between the two is pinned by
/// tests, so the native path can never silently diverge.
///
/// Colors pack as memory-order RGBA words (r | g<<8 | b<<16 | a<<24),
/// STRAIGHT alpha; rasterization is byte-rounded integer source-over
/// (the fill-compose arithmetic). The background fill forces a=255, so
/// finished tiles are opaque and upload as rgba8888 directly.
abstract final class TimelineGridTileOp {
  static const int fillRect = 1;
  static const int hline = 2;
  static const int vline = 3;
  static const int glyph = 4;
}

/// Packs a straight-alpha color into the op stream's RGBA word.
int timelineGridPackRgba(Color color) {
  final argb = color.toARGB32();
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return r | (g << 8) | (b << 16) | (a << 24);
}

/// Grow-only builder for one tile's op stream.
class TimelineGridTileOpWriter {
  final List<int> _words = <int>[];

  int get wordCount => _words.length;

  void fillRect(int x, int y, int width, int height, int rgba) {
    _words
      ..add(TimelineGridTileOp.fillRect)
      ..add(x)
      ..add(y)
      ..add(width)
      ..add(height)
      ..add(rgba);
  }

  /// A horizontal line [length] long, [thickness] tall.
  void hline(int x, int y, int length, int thickness, int rgba) {
    _words
      ..add(TimelineGridTileOp.hline)
      ..add(x)
      ..add(y)
      ..add(length)
      ..add(thickness)
      ..add(rgba);
  }

  /// A vertical line [length] tall, [thickness] wide.
  void vline(int x, int y, int length, int thickness, int rgba) {
    _words
      ..add(TimelineGridTileOp.vline)
      ..add(x)
      ..add(y)
      ..add(length)
      ..add(thickness)
      ..add(rgba);
  }

  /// Blits a [width]x[height] window of the A8 atlas at (atlasX, atlasY)
  /// to (destX, destY), tinted by [rgba] (atlas coverage scales its
  /// alpha).
  void glyph(
    int destX,
    int destY,
    int atlasX,
    int atlasY,
    int width,
    int height,
    int rgba,
  ) {
    _words
      ..add(TimelineGridTileOp.glyph)
      ..add(destX)
      ..add(destY)
      ..add(atlasX)
      ..add(atlasY)
      ..add(width)
      ..add(height)
      ..add(rgba);
  }

  Int32List build() => Int32List.fromList(_words);
}

void _blendSpan(
  Uint8List pixels,
  int offset,
  int count,
  int r,
  int g,
  int b,
  int a,
) {
  if (a >= 255) {
    for (var i = 0; i < count; i += 1) {
      final base = offset + i * 4;
      pixels[base] = r;
      pixels[base + 1] = g;
      pixels[base + 2] = b;
      pixels[base + 3] = 255;
    }
    return;
  }
  final inv = 255 - a;
  for (var i = 0; i < count; i += 1) {
    final base = offset + i * 4;
    pixels[base] = (r * a + pixels[base] * inv + 127) ~/ 255;
    pixels[base + 1] = (g * a + pixels[base + 1] * inv + 127) ~/ 255;
    pixels[base + 2] = (b * a + pixels[base + 2] * inv + 127) ~/ 255;
    pixels[base + 3] = 255 - ((255 - pixels[base + 3]) * inv + 127) ~/ 255;
  }
}

void _blendRect(
  Uint8List pixels,
  int tileWidth,
  int tileHeight,
  int x,
  int y,
  int w,
  int h,
  int rgba,
) {
  final a = (rgba >> 24) & 0xFF;
  if (a == 0 || w <= 0 || h <= 0) {
    return;
  }
  final left = x < 0 ? 0 : x;
  final top = y < 0 ? 0 : y;
  var right = x + w;
  var bottom = y + h;
  if (right > tileWidth) {
    right = tileWidth;
  }
  if (bottom > tileHeight) {
    bottom = tileHeight;
  }
  if (left >= right || top >= bottom) {
    return;
  }
  final r = rgba & 0xFF;
  final g = (rgba >> 8) & 0xFF;
  final b = (rgba >> 16) & 0xFF;
  for (var row = top; row < bottom; row += 1) {
    _blendSpan(pixels, (row * tileWidth + left) * 4, right - left, r, g, b, a);
  }
}

/// The Dart REFERENCE of `qa_grid_raster_tile` — the source of truth for
/// the semantics, byte-identical to the native rasterizer (pinned by the
/// parity suite). Returns 0 on success, negative on a malformed stream
/// (the native error contract).
int timelineGridRasterTileReference({
  required Uint8List pixels,
  required int tileWidth,
  required int tileHeight,
  required int backgroundRgba,
  Int32List? ops,
  Uint8List? atlas,
  int atlasWidth = 0,
  int atlasHeight = 0,
}) {
  if (tileWidth <= 0 || tileHeight <= 0) {
    return -1;
  }
  final bgR = backgroundRgba & 0xFF;
  final bgG = (backgroundRgba >> 8) & 0xFF;
  final bgB = (backgroundRgba >> 16) & 0xFF;
  for (var i = 0; i < tileWidth * tileHeight; i += 1) {
    final base = i * 4;
    pixels[base] = bgR;
    pixels[base + 1] = bgG;
    pixels[base + 2] = bgB;
    pixels[base + 3] = 255;
  }
  if (ops == null || ops.isEmpty) {
    return 0;
  }

  var cursor = 0;
  while (cursor < ops.length) {
    switch (ops[cursor]) {
      case TimelineGridTileOp.fillRect:
      case TimelineGridTileOp.hline:
        if (cursor + 6 > ops.length) {
          return -2;
        }
        _blendRect(
          pixels,
          tileWidth,
          tileHeight,
          ops[cursor + 1],
          ops[cursor + 2],
          ops[cursor + 3],
          ops[cursor + 4],
          ops[cursor + 5],
        );
        cursor += 6;
      case TimelineGridTileOp.vline:
        if (cursor + 6 > ops.length) {
          return -2;
        }
        // length runs down, thickness across.
        _blendRect(
          pixels,
          tileWidth,
          tileHeight,
          ops[cursor + 1],
          ops[cursor + 2],
          ops[cursor + 4],
          ops[cursor + 3],
          ops[cursor + 5],
        );
        cursor += 6;
      case TimelineGridTileOp.glyph:
        if (cursor + 8 > ops.length) {
          return -2;
        }
        if (atlas == null) {
          return -3;
        }
        final destX = ops[cursor + 1];
        final destY = ops[cursor + 2];
        final atlasX = ops[cursor + 3];
        final atlasY = ops[cursor + 4];
        final w = ops[cursor + 5];
        final h = ops[cursor + 6];
        final rgba = ops[cursor + 7];
        final colorA = (rgba >> 24) & 0xFF;
        final r = rgba & 0xFF;
        final g = (rgba >> 8) & 0xFF;
        final b = (rgba >> 16) & 0xFF;
        for (var row = 0; row < h; row += 1) {
          final ty = destY + row;
          final ay = atlasY + row;
          if (ty < 0 || ty >= tileHeight || ay < 0 || ay >= atlasHeight) {
            continue;
          }
          for (var col = 0; col < w; col += 1) {
            final tx = destX + col;
            final ax = atlasX + col;
            if (tx < 0 || tx >= tileWidth || ax < 0 || ax >= atlasWidth) {
              continue;
            }
            final coverage = atlas[ay * atlasWidth + ax];
            if (coverage == 0 || colorA == 0) {
              continue;
            }
            final a = (colorA * coverage + 127) ~/ 255;
            _blendSpan(pixels, (ty * tileWidth + tx) * 4, 1, r, g, b, a);
          }
        }
        cursor += 8;
      default:
        return -4;
    }
  }
  return 0;
}
