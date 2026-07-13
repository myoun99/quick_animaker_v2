/// Compact binary encoding for the .qap container's drawing payloads
/// (P3): one entry per drawn frame — the frame's LIVE paint commands with
/// their source dabs. Dab records are fixed-width with unit-interval
/// properties quantized to bytes ("최대한 무조건 가볍게", user direction);
/// tip masks are deduplicated into ONE shared table entry per archive and
/// referenced by index. Little-endian throughout.
///
/// The quantization is canonical: encoding an already-decoded entry
/// reproduces identical bytes (round-trip tests pin this), and every
/// decoded value is valid BrushDab input by construction.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../../models/canvas_size.dart';
import '../../models/tile_coord.dart';
import '../../models/brush_paint_command.dart';
import '../../models/brush_paint_command_id.dart';
import '../../models/brush_stamp_image.dart';
import '../../models/brush_tip_mask.dart';
import '../../models/brush_tip_shape.dart';
import '../../models/canvas_point.dart';
import '../../models/cut_id.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/project_id.dart';
import '../../models/track_id.dart';

/// One drawn frame's save payload.
class QapDrawingEntry {
  const QapDrawingEntry({required this.key, required this.commands});

  final BrushFrameKey key;
  final List<BrushPaintCommand> commands;
}

/// v2: RGBA stamp dabs (R14-④ bitmap lift) — flag bit 16 + an inline
/// stamp payload per dab (stamps are unique per lift; a dedup table would
/// buy nothing). v1 archives decode unchanged (the flag never appears).
const int qapDrawingBinaryVersion = 2;
const int qapTipTableBinaryVersion = 1;

/// Collects every distinct tip mask (by id) referenced from [entries] —
/// the archive's shared mask table, in first-seen order.
List<BrushTipMask> collectTipMasks(Iterable<QapDrawingEntry> entries) {
  final masks = <String, BrushTipMask>{};
  void add(BrushTipMask? mask) {
    if (mask != null) {
      masks.putIfAbsent(mask.id, () => mask);
    }
  }

  for (final entry in entries) {
    for (final command in entry.commands) {
      for (final dab in command.sourceDabs) {
        add(dab.tipMask);
        add(dab.dualMask);
        add(dab.textureMask);
      }
    }
  }
  return masks.values.toList(growable: false);
}

Uint8List encodeTipMaskTable(List<BrushTipMask> masks) {
  final writer = _ByteWriter()
    ..u8(qapTipTableBinaryVersion)
    ..u16(masks.length);
  for (final mask in masks) {
    writer
      ..string(mask.id)
      ..u16(mask.size)
      ..bytes(mask.alpha);
  }
  return writer.takeBytes();
}

List<BrushTipMask> decodeTipMaskTable(Uint8List bytes) {
  final reader = _ByteReader(bytes);
  final version = reader.u8();
  if (version > qapTipTableBinaryVersion) {
    throw const FormatException('Unsupported tip table version.');
  }
  final count = reader.u16();
  return [
    for (var i = 0; i < count; i += 1)
      () {
        final id = reader.string();
        final size = reader.u16();
        return BrushTipMask(
          id: id,
          size: size,
          alpha: reader.bytes(size * size),
        );
      }(),
  ];
}

const int _flagErase = 1;
const int _flagTipMask = 2;
const int _flagDualMask = 4;
const int _flagTextureMask = 8;
const int _flagStamp = 16;

Uint8List encodeDrawingEntry(
  QapDrawingEntry entry,
  Map<String, int> maskIndexById,
) {
  final writer = _ByteWriter()
    ..u8(qapDrawingBinaryVersion)
    ..string(entry.key.projectId.value)
    ..string(entry.key.trackId.value)
    ..string(entry.key.cutId.value)
    ..string(entry.key.layerId.value)
    ..string(entry.key.frameId.value)
    ..u16(entry.commands.length);
  for (final command in entry.commands) {
    writer
      ..string(command.id.value)
      ..u32(command.sequenceNumber)
      ..u8(command.kind.index)
      ..u32(command.sourceDabs.length);
    for (final dab in command.sourceDabs) {
      var flags = 0;
      if (dab.erase) {
        flags |= _flagErase;
      }
      if (dab.tipMask != null) {
        flags |= _flagTipMask;
      }
      if (dab.dualMask != null) {
        flags |= _flagDualMask;
      }
      if (dab.textureMask != null) {
        flags |= _flagTextureMask;
      }
      if (dab.stamp != null) {
        flags |= _flagStamp;
      }
      writer
        ..f32(dab.center.x)
        ..f32(dab.center.y)
        ..u32(dab.color)
        ..f32(dab.size)
        ..u8(_unitToByte(dab.opacity))
        ..u8(_unitToByte(dab.flow))
        ..u8(_unitToByte(dab.hardness))
        ..u8(_unitToByte(dab.pressure))
        ..u8(dab.tipShape.index)
        ..u32(dab.sequence)
        ..u8(_roundnessToByte(dab.roundness))
        ..f32(dab.angleDegrees)
        ..u8(flags);
      if (dab.tipMask != null) {
        writer.u16(maskIndexById[dab.tipMask!.id]!);
      }
      if (dab.dualMask != null) {
        writer
          ..u16(maskIndexById[dab.dualMask!.id]!)
          ..f32(dab.dualMaskScale)
          ..u16(_unitToU16(dab.dualOffsetU))
          ..u16(_unitToU16(dab.dualOffsetV));
      }
      if (dab.textureMask != null) {
        writer
          ..u16(maskIndexById[dab.textureMask!.id]!)
          ..f32(dab.textureScale)
          ..u8(_unitToByte(dab.textureDensity));
      }
      final stamp = dab.stamp;
      if (stamp != null) {
        writer
          ..string(stamp.id)
          ..u16(stamp.width)
          ..u16(stamp.height)
          ..bytes(stamp.rgba);
      }
    }
  }
  return writer.takeBytes();
}

QapDrawingEntry decodeDrawingEntry(Uint8List bytes, List<BrushTipMask> masks) {
  final reader = _ByteReader(bytes);
  final version = reader.u8();
  if (version > qapDrawingBinaryVersion) {
    throw const FormatException('Unsupported drawing entry version.');
  }
  final key = BrushFrameKey(
    projectId: ProjectId(reader.string()),
    trackId: TrackId(reader.string()),
    cutId: CutId(reader.string()),
    layerId: LayerId(reader.string()),
    frameId: FrameId(reader.string()),
  );
  final commandCount = reader.u16();
  final commands = <BrushPaintCommand>[];
  for (var c = 0; c < commandCount; c += 1) {
    final id = BrushPaintCommandId(reader.string());
    final sequenceNumber = reader.u32();
    final kind = BrushPaintCommandKind.values[reader.u8()];
    final dabCount = reader.u32();
    final dabs = <BrushDab>[];
    for (var d = 0; d < dabCount; d += 1) {
      final x = reader.f32();
      final y = reader.f32();
      final color = reader.u32();
      final size = reader.f32();
      final opacity = _byteToUnit(reader.u8());
      final flow = _byteToUnit(reader.u8());
      final hardness = _byteToUnit(reader.u8());
      final pressure = _byteToUnit(reader.u8());
      final tipShape = BrushTipShape.values[reader.u8()];
      final sequence = reader.u32();
      final roundness = _byteToRoundness(reader.u8());
      final angleDegrees = reader.f32();
      final flags = reader.u8();
      BrushTipMask? tipMask;
      BrushTipMask? dualMask;
      var dualMaskScale = 1.0;
      var dualOffsetU = 0.0;
      var dualOffsetV = 0.0;
      BrushTipMask? textureMask;
      var textureScale = 1.0;
      var textureDensity = 1.0;
      if (flags & _flagTipMask != 0) {
        tipMask = masks[reader.u16()];
      }
      if (flags & _flagDualMask != 0) {
        dualMask = masks[reader.u16()];
        dualMaskScale = reader.f32();
        dualOffsetU = _u16ToUnit(reader.u16());
        dualOffsetV = _u16ToUnit(reader.u16());
      }
      if (flags & _flagTextureMask != 0) {
        textureMask = masks[reader.u16()];
        textureScale = reader.f32();
        textureDensity = _byteToUnit(reader.u8());
      }
      BrushStampImage? stamp;
      if (flags & _flagStamp != 0) {
        final stampId = reader.string();
        final stampWidth = reader.u16();
        final stampHeight = reader.u16();
        stamp = BrushStampImage(
          id: stampId,
          width: stampWidth,
          height: stampHeight,
          rgba: reader.bytes(stampWidth * stampHeight * 4),
        );
      }
      dabs.add(
        BrushDab(
          center: CanvasPoint(x: x, y: y),
          color: color,
          size: size,
          opacity: opacity,
          flow: flow,
          hardness: hardness,
          tipShape: tipShape,
          pressure: pressure,
          sequence: sequence,
          roundness: roundness,
          angleDegrees: angleDegrees,
          tipMask: tipMask,
          dualMask: dualMask,
          dualMaskScale: dualMaskScale,
          dualOffsetU: dualOffsetU,
          dualOffsetV: dualOffsetV,
          textureMask: textureMask,
          textureScale: textureScale,
          textureDensity: textureDensity,
          erase: flags & _flagErase != 0,
          stamp: stamp,
        ),
      );
    }
    commands.add(
      BrushPaintCommand(
        id: id,
        sequenceNumber: sequenceNumber,
        kind: kind,
        sourceDabs: dabs,
      ),
    );
  }
  return QapDrawingEntry(key: key, commands: commands);
}

int _unitToByte(double value) => (value.clamp(0.0, 1.0) * 255).round();

double _byteToUnit(int byte) => byte / 255;

/// Roundness lives in (0, 1] — the byte floor of 1 keeps decoded values
/// valid constructor input.
int _roundnessToByte(double value) =>
    (value.clamp(0.0, 1.0) * 255).round().clamp(1, 255);

double _byteToRoundness(int byte) => byte.clamp(1, 255) / 255;

int _unitToU16(double value) => (value.clamp(0.0, 1.0) * 65535).round();

double _u16ToUnit(int value) => value / 65535;

/// One cel's BAKED raster — the persistence TRUTH from .qap format v2 on
/// (R19 bake-only): what you saved is exactly what reopens, byte for
/// byte, with no re-materialization ever.
class QapCelEntry {
  const QapCelEntry({required this.key, required this.surface});

  final BrushFrameKey key;
  final BitmapSurface surface;
}

const int qapCelBinaryVersion = 1;

/// Encodes a baked cel: key, canvas geometry, then each tile's coord and
/// RAW straight-alpha RGBA bytes (the ZIP container's deflate compresses
/// line art extremely well — no inner compression layer).
Uint8List encodeCelEntry(QapCelEntry entry) {
  final surface = entry.surface;
  final writer = _ByteWriter()
    ..u8(qapCelBinaryVersion)
    ..string(entry.key.projectId.value)
    ..string(entry.key.trackId.value)
    ..string(entry.key.cutId.value)
    ..string(entry.key.layerId.value)
    ..string(entry.key.frameId.value)
    ..u32(surface.canvasSize.width)
    ..u32(surface.canvasSize.height)
    ..u16(surface.tileSize)
    ..u32(surface.tiles.length);
  for (final tile in surface.tiles.values) {
    writer
      ..u32(tile.coord.x)
      ..u32(tile.coord.y)
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
  final tiles = <TileCoord, BitmapTile>{};
  for (var i = 0; i < tileCount; i += 1) {
    final coord = TileCoord(x: reader.u32(), y: reader.u32());
    tiles[coord] = BitmapTile(
      coord: coord,
      size: tileSize,
      pixels: reader.bytes(tileByteLength),
    );
  }
  return QapCelEntry(
    key: key,
    surface: BitmapSurface(
      canvasSize: CanvasSize(width: width, height: height),
      tileSize: tileSize,
      tiles: tiles,
    ),
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
