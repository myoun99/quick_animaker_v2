/// Compact binary encoding for the .qap container's cel payloads: one
/// entry per baked cel — key, canvas geometry, then raw straight-alpha
/// RGBA tile bytes. Little-endian throughout. (The v1 command-drawing
/// codec lived here until R20-E3 — deleted with the v1 reader; no
/// production v1 file was ever written.)
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../models/tile_coord.dart';
import '../../models/cut_id.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/project_id.dart';
import '../../models/track_id.dart';

/// One cel's BAKED raster — the persistence TRUTH from .qap format v2 on
/// (R19 bake-only): what you saved is exactly what reopens, byte for
/// byte, with no re-materialization ever.
///
/// R19-Z: this is a PLAIN-BYTES snapshot ((coordX, coordY, rgba) records),
/// not a [BitmapSurface] — native-backed tiles are Finalizable and cannot
/// cross the save/open isolate boundary, so the boundary ships bytes and
/// each side converts with [QapCelEntry.fromSurface]/[toSurface].
class QapCelEntry {
  const QapCelEntry({
    required this.key,
    required this.canvasSize,
    required this.tileSize,
    required this.tiles,
  });

  factory QapCelEntry.fromSurface(BrushFrameKey key, BitmapSurface surface) {
    return QapCelEntry(
      key: key,
      canvasSize: surface.canvasSize,
      tileSize: surface.tileSize,
      tiles: [
        for (final tile in surface.tiles.values)
          (x: tile.coord.x, y: tile.coord.y, pixels: tile.pixels),
      ],
    );
  }

  final BrushFrameKey key;
  final CanvasSize canvasSize;
  final int tileSize;
  final List<({int x, int y, Uint8List pixels})> tiles;

  BitmapSurface toSurface() {
    return BitmapSurface(
      canvasSize: canvasSize,
      tileSize: tileSize,
      tiles: {
        for (final tile in tiles)
          TileCoord(x: tile.x, y: tile.y): BitmapTile(
            coord: TileCoord(x: tile.x, y: tile.y),
            size: tileSize,
            pixels: tile.pixels,
          ),
      },
    );
  }
}

const int qapCelBinaryVersion = 1;

/// Encodes a baked cel: key, canvas geometry, then each tile's coord and
/// RAW straight-alpha RGBA bytes (the ZIP container's deflate compresses
/// line art extremely well — no inner compression layer).
Uint8List encodeCelEntry(QapCelEntry entry) {
  final writer = _ByteWriter()
    ..u8(qapCelBinaryVersion)
    ..string(entry.key.projectId.value)
    ..string(entry.key.trackId.value)
    ..string(entry.key.cutId.value)
    ..string(entry.key.layerId.value)
    ..string(entry.key.frameId.value)
    ..u32(entry.canvasSize.width)
    ..u32(entry.canvasSize.height)
    ..u16(entry.tileSize)
    ..u32(entry.tiles.length);
  for (final tile in entry.tiles) {
    writer
      ..u32(tile.x)
      ..u32(tile.y)
      ..bytes(tile.pixels);
  }
  return writer.takeBytes();
}

QapCelEntry decodeCelEntry(Uint8List bytes) {
  final reader = _ByteReader(bytes);
  final version = reader.u8();
  if (version > qapCelBinaryVersion) {
    throw const FormatException('Unsupported cel entry version.');
  }
  final key = BrushFrameKey(
    projectId: ProjectId(reader.string()),
    trackId: TrackId(reader.string()),
    cutId: CutId(reader.string()),
    layerId: LayerId(reader.string()),
    frameId: FrameId(reader.string()),
  );
  final width = reader.u32();
  final height = reader.u32();
  final tileSize = reader.u16();
  final tileCount = reader.u32();
  final tileByteLength = tileSize * tileSize * BitmapTile.bytesPerPixel;
  return QapCelEntry(
    key: key,
    canvasSize: CanvasSize(width: width, height: height),
    tileSize: tileSize,
    tiles: [
      for (var i = 0; i < tileCount; i += 1)
        (
          x: reader.u32(),
          y: reader.u32(),
          pixels: reader.bytes(tileByteLength),
        ),
    ],
  );
}

class _ByteWriter {
  final BytesBuilder _builder = BytesBuilder(copy: true);
  final ByteData _scratch = ByteData(8);

  void u8(int value) => _builder.addByte(value);

  void u16(int value) {
    _scratch.setUint16(0, value, Endian.little);
    _builder.add(_scratch.buffer.asUint8List(0, 2));
  }

  void u32(int value) {
    _scratch.setUint32(0, value, Endian.little);
    _builder.add(_scratch.buffer.asUint8List(0, 4));
  }

  void f32(double value) {
    _scratch.setFloat32(0, value, Endian.little);
    _builder.add(_scratch.buffer.asUint8List(0, 4));
  }

  void string(String value) {
    final encoded = utf8.encode(value);
    u16(encoded.length);
    _builder.add(encoded);
  }

  void bytes(List<int> value) => _builder.add(value);

  Uint8List takeBytes() => _builder.takeBytes();
}

class _ByteReader {
  _ByteReader(Uint8List bytes)
    : _data = ByteData.sublistView(bytes),
      _bytes = bytes;

  final ByteData _data;
  final Uint8List _bytes;
  int _offset = 0;

  int u8() => _data.getUint8(_offset++);

  int u16() {
    final value = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int u32() {
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  double f32() {
    final value = _data.getFloat32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  String string() {
    final length = u16();
    final value = utf8.decode(
      Uint8List.sublistView(_bytes, _offset, _offset + length),
    );
    _offset += length;
    return value;
  }

  Uint8List bytes(int length) {
    final value = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return value;
  }
}
