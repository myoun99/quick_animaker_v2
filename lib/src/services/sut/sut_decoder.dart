import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:sqlite3/sqlite3.dart';

import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';
import '../../models/brush_settings.dart';
import '../../models/brush_tip_mask.dart';

/// Result of decoding a Clip Studio Paint `.sut`/`.sutg` brush file.
class SutImportResult {
  const SutImportResult({required this.presets, required this.warnings});

  final List<BrushPreset> presets;
  final List<String> warnings;
}

/// Thrown when the file cannot be read as a Clip Studio brush at all.
class SutDecodeException implements Exception {
  const SutDecodeException(this.message);

  final String message;

  @override
  String toString() => 'SutDecodeException: $message';
}

/// Decodes a Clip Studio Paint brush file — a SQLite database holding tool
/// nodes (`Node`), their parameters (`Variant`), and, when the brush was
/// exported with its materials, embedded tip bitmaps (`MaterialFile`).
///
/// Mapping (verified against real CSP 1.x/3.x exports): `BrushSize` px,
/// `Opacity`/`BrushFlow`/`BrushHardness`/`BrushThickness` percent,
/// `BrushInterval` percent -> spacing ratio, `BrushRotation` degrees,
/// `*Effector` blobs carry the input-source flags (bit 0x10 at byte offset
/// 8 = pen pressure). Tip bitmaps live in `MaterialFile.FileData` (a CSP
/// material archive containing PNGs; the largest PNG is the tip image,
/// smaller ones are thumbnails), joined through the UTF-16 catalog path in
/// `BrushPatternImageArray`. The Variant schema varies across CSP versions,
/// so every column read tolerates absence.
Future<SutImportResult> decodeSutBrushFile({
  required String filePath,
  required String sourceName,
}) async {
  final Database database;
  try {
    database = sqlite3.open(filePath, mode: OpenMode.readOnly);
  } on SqliteException catch (error) {
    throw SutDecodeException('Could not open the file: ${error.message}');
  }
  try {
    return await _decode(database, sourceName: sourceName);
  } on SqliteException catch (error) {
    throw SutDecodeException(
      'This file is not a readable Clip Studio brush (${error.message}).',
    );
  } finally {
    database.close();
  }
}

Future<SutImportResult> _decode(
  Database database, {
  required String sourceName,
}) async {
  final tables = database
      .select("SELECT name FROM sqlite_master WHERE type='table'")
      .map((row) => row['name'] as String)
      .toSet();
  if (!tables.contains('Node') || !tables.contains('Variant')) {
    throw const SutDecodeException(
      'No Clip Studio brush data found in this file.',
    );
  }

  final warnings = <String>[];
  final variantsById = <int, Map<String, Object?>>{};
  for (final row in database.select('SELECT * FROM Variant')) {
    final id = row['VariantID'];
    if (id is int) {
      variantsById[id] = Map<String, Object?>.from(row);
    }
  }

  final materials = <({String path, Uint8List data})>[];
  if (tables.contains('MaterialFile')) {
    for (final row in database.select('SELECT * FROM MaterialFile')) {
      final data = row['FileData'];
      final catalogPath = row['CatalogPath'] ?? row['OriginalPath'];
      if (data is Uint8List && catalogPath is String && catalogPath.isNotEmpty) {
        materials.add((path: _stripLayerSuffix(catalogPath), data: data));
      }
    }
  }

  final usedPresetIds = <String>{};
  BrushPresetId uniquePresetId(String base) {
    if (usedPresetIds.add(base)) {
      return BrushPresetId(base);
    }
    var suffix = 2;
    while (!usedPresetIds.add('$base-$suffix')) {
      suffix += 1;
    }
    return BrushPresetId('$base-$suffix');
  }

  final presets = <BrushPreset>[];
  var nodeIndex = 0;
  for (final row in database.select('SELECT * FROM Node')) {
    final node = Map<String, Object?>.from(row);
    nodeIndex += 1;
    final variantId = node['NodeVariantID'];
    final variant = variantId is int ? variantsById[variantId] : null;
    // Group/root nodes have no usable parameter set.
    if (variant == null || variant['BrushSize'] == null) {
      continue;
    }

    final nodeName = node['NodeName'];
    final name = nodeName is String && nodeName.isNotEmpty
        ? nodeName
        : '$sourceName brush $nodeIndex';
    final uuid = node['NodeUuid'];
    final idBase = uuid is Uint8List && uuid.length >= 16
        ? 'sut-${_hex(uuid)}'
        : 'sut-$sourceName-$nodeIndex';
    final presetId = uniquePresetId(idBase);

    BrushTipMask? mask;
    if (_intOf(variant['BrushUsePatternImage']) == 1) {
      mask = await _tipMaskFromPatternArray(
        variant['BrushPatternImageArray'],
        materials: materials,
        maskId: '$idBase-tip',
        brushName: name,
        warnings: warnings,
      );
    }

    presets.add(
      BrushPreset(
        id: presetId,
        name: name,
        settings: _settingsFromVariant(variant, mask: mask),
      ),
    );
  }

  if (presets.isEmpty) {
    throw const SutDecodeException(
      'The file contained no importable brushes.',
    );
  }
  return SutImportResult(presets: presets, warnings: warnings);
}

BrushSettings _settingsFromVariant(
  Map<String, Object?> variant, {
  required BrushTipMask? mask,
}) {
  final size = _doubleOf(variant['BrushSize']) ?? 24.0;
  final opacityPercent = _doubleOf(variant['Opacity']) ?? 100.0;
  final flowPercent = _doubleOf(variant['BrushFlow']) ?? 100.0;
  final hardnessPercent = _doubleOf(variant['BrushHardness']) ?? 100.0;
  final intervalPercent = _doubleOf(variant['BrushInterval']) ?? 25.0;
  final thicknessPercent = _doubleOf(variant['BrushThickness']) ?? 100.0;
  final rotation = _doubleOf(variant['BrushRotation']) ?? 0.0;

  final pressureSize = _effectorUsesPressure(variant['BrushSizeEffector']);
  final pressureOpacity =
      _effectorUsesPressure(variant['BrushOpacityEffector']) ||
      _effectorUsesPressure(variant['BrushFlowEffector']);
  final minimumSizeRatio = pressureSize
      ? _effectorMinimumRatio(variant['BrushSizeEffector'])
      : 0.0;

  // Spray mode scatters dabs around the stroke; the spray size is a
  // percentage of the brush size (its diameter), so the radius is half.
  var scatterRadiusRatio = 0.0;
  var scatterCount = 1;
  if (_intOf(variant['BrushUseSpray']) == 1) {
    final spraySize = _doubleOf(variant['BrushSpraySize']) ?? 0.0;
    scatterRadiusRatio = spraySize.isFinite
        ? (spraySize / 100.0 / 2.0).clamp(0.0, 10.0).toDouble()
        : 0.0;
    scatterCount = (_intOf(variant['BrushSprayDensity']) ?? 1).clamp(1, 16);
  }

  return BrushSettings(
    size: size.isFinite && size > 0 ? size : 24,
    opacity: (opacityPercent / 100.0).clamp(0.0, 1.0).toDouble(),
    flow: (flowPercent / 100.0).clamp(0.0, 1.0).toDouble(),
    hardness: (hardnessPercent / 100.0).clamp(0.0, 1.0).toDouble(),
    spacing: intervalPercent.isFinite && intervalPercent > 0
        ? (intervalPercent / 100.0).clamp(0.01, 10.0).toDouble()
        : 0.25,
    roundness: (thicknessPercent / 100.0).clamp(0.01, 1.0).toDouble(),
    angleDegrees: rotation.isFinite ? ((rotation % 180.0) + 180.0) % 180.0 : 0,
    pressureSize: pressureSize,
    pressureOpacity: pressureOpacity,
    tipMask: mask,
    minimumSizeRatio: minimumSizeRatio,
    scatterRadiusRatio: scatterRadiusRatio,
    scatterCount: scatterCount,
  );
}

/// Effector blobs start with two header ints, then the input-source flags:
/// bit 0x10 selects pen pressure (0x20/0x80 are velocity/random and stay
/// unmapped).
bool _effectorUsesPressure(Object? blob) {
  if (blob is! Uint8List || blob.length < 12) {
    return false;
  }
  final flags = ByteData.sublistView(blob).getInt32(8);
  return (flags & 0x10) != 0;
}

/// The effector's minimum-output percentage (byte offset 12) — Clip
/// Studio's 최소치 slider, the pressure floor for the affected value.
double _effectorMinimumRatio(Object? blob) {
  if (blob is! Uint8List || blob.length < 16) {
    return 0.0;
  }
  final minimum = ByteData.sublistView(blob).getInt32(12);
  return (minimum / 100.0).clamp(0.0, 1.0).toDouble();
}

Future<BrushTipMask?> _tipMaskFromPatternArray(
  Object? patternArray, {
  required List<({String path, Uint8List data})> materials,
  required String maskId,
  required String brushName,
  required List<String> warnings,
}) async {
  if (patternArray is! Uint8List || materials.isEmpty) {
    if (patternArray != null) {
      warnings.add('Brush "$brushName": tip bitmap is not embedded; '
          'imported with a round tip.');
    }
    return null;
  }
  // The array blob carries UTF-16BE catalog paths; match them against the
  // embedded material files. The earliest referenced material is the
  // primary tip (pattern brushes with several tips use only the first).
  final text = _utf16Runs(patternArray);
  ({String path, Uint8List data})? tipMaterial;
  var bestIndex = -1;
  for (final material in materials) {
    final index = text.indexOf(material.path);
    if (index >= 0 && (bestIndex == -1 || index < bestIndex)) {
      bestIndex = index;
      tipMaterial = material;
    }
  }
  if (tipMaterial == null) {
    warnings.add('Brush "$brushName": tip bitmap reference not found; '
        'imported with a round tip.');
    return null;
  }

  final png = _largestPng(tipMaterial.data);
  if (png == null) {
    warnings.add('Brush "$brushName": embedded material holds no readable '
        'image; imported with a round tip.');
    return null;
  }
  try {
    return await _maskFromPngBytes(png, maskId: maskId);
  } catch (error) {
    warnings.add('Brush "$brushName": tip image could not be decoded '
        '($error); imported with a round tip.');
    return null;
  }
}

String _stripLayerSuffix(String path) {
  final index = path.indexOf(':data:');
  return index > 0 ? path.substring(0, index) : path;
}

/// Extracts the printable UTF-16 characters of [bytes] in both byte orders
/// (CSP writes the catalog paths little-endian, but be permissive).
String _utf16Runs(Uint8List bytes) {
  final buffer = StringBuffer();
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final littleEndian = bytes[i] | (bytes[i + 1] << 8);
    if (littleEndian >= 0x20 && littleEndian < 0x7F) {
      buffer.writeCharCode(littleEndian);
    }
  }
  buffer.write('\n');
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final bigEndian = (bytes[i] << 8) | bytes[i + 1];
    if (bigEndian >= 0x20 && bigEndian < 0x7F) {
      buffer.writeCharCode(bigEndian);
    }
  }
  return buffer.toString();
}

/// Finds the largest embedded PNG in a CSP material archive blob — the tip
/// image itself; smaller PNGs are thumbnails.
Uint8List? _largestPng(Uint8List data) {
  Uint8List? best;
  var bestArea = 0;
  for (var i = 0; i + 26 < data.length; i += 1) {
    if (data[i] != 0x89 ||
        data[i + 1] != 0x50 ||
        data[i + 2] != 0x4E ||
        data[i + 3] != 0x47) {
      continue;
    }
    final view = ByteData.sublistView(data, i);
    final width = view.getUint32(16);
    final height = view.getUint32(20);
    final end = _pngEnd(data, i);
    if (end == null) {
      continue;
    }
    final area = width * height;
    if (area > bestArea) {
      bestArea = area;
      best = Uint8List.sublistView(data, i, end);
    }
    i = end - 1;
  }
  return best;
}

/// Walks PNG chunks from [start] to the end of IEND; `null` when corrupt.
int? _pngEnd(Uint8List data, int start) {
  var offset = start + 8;
  final view = ByteData.sublistView(data);
  while (offset + 8 <= data.length) {
    final length = view.getUint32(offset);
    final type = String.fromCharCodes(data, offset + 4, offset + 8);
    offset += 8 + length + 4;
    if (offset > data.length) {
      return null;
    }
    if (type == 'IEND') {
      return offset;
    }
  }
  return null;
}

/// Longest mask side kept after import; larger tips are downscaled so the
/// preset library stays reasonably sized.
const int _maxMaskSide = 256;

Future<BrushTipMask> _maskFromPngBytes(
  Uint8List png, {
  required String maskId,
}) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (byteData == null) {
      throw const FormatException('image pixels unavailable');
    }
    final rgba = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    // Coverage: alpha shaped by darkness. Black-on-transparent tips resolve
    // to their alpha; black-on-white opaque tips resolve to inverted
    // luminance. If that yields nothing (e.g. white-on-transparent), fall
    // back to the alpha channel alone.
    var gray = Uint8List(width * height);
    var sum = 0;
    for (var index = 0; index < gray.length; index += 1) {
      final r = rgba[index * 4];
      final g = rgba[index * 4 + 1];
      final b = rgba[index * 4 + 2];
      final a = rgba[index * 4 + 3];
      final luminance = (r * 299 + g * 587 + b * 114) ~/ 1000;
      final value = a * (255 - luminance) ~/ 255;
      gray[index] = value;
      sum += value;
    }
    if (sum == 0) {
      for (var index = 0; index < gray.length; index += 1) {
        gray[index] = rgba[index * 4 + 3];
      }
    }

    var maskWidth = width;
    var maskHeight = height;
    final longSide = math.max(width, height);
    if (longSide > _maxMaskSide) {
      final scale = _maxMaskSide / longSide;
      final scaledWidth = math.max(1, (width * scale).round());
      final scaledHeight = math.max(1, (height * scale).round());
      gray = _resizeGray(
        gray,
        width: width,
        height: height,
        newWidth: scaledWidth,
        newHeight: scaledHeight,
      );
      maskWidth = scaledWidth;
      maskHeight = scaledHeight;
    }

    // Pad to the engine's centered-square mask requirement.
    final side = math.max(maskWidth, maskHeight);
    final alpha = Uint8List(side * side);
    final offsetX = (side - maskWidth) ~/ 2;
    final offsetY = (side - maskHeight) ~/ 2;
    for (var y = 0; y < maskHeight; y += 1) {
      alpha.setRange(
        (offsetY + y) * side + offsetX,
        (offsetY + y) * side + offsetX + maskWidth,
        gray,
        y * maskWidth,
      );
    }
    return BrushTipMask(id: maskId, size: side, alpha: alpha);
  } finally {
    image.dispose();
  }
}

/// Bilinear grayscale resize.
Uint8List _resizeGray(
  Uint8List source, {
  required int width,
  required int height,
  required int newWidth,
  required int newHeight,
}) {
  final output = Uint8List(newWidth * newHeight);
  for (var y = 0; y < newHeight; y += 1) {
    final sourceY = (y + 0.5) * height / newHeight - 0.5;
    final y0 = sourceY.floor().clamp(0, height - 1);
    final y1 = (y0 + 1).clamp(0, height - 1);
    final fy = (sourceY - y0).clamp(0.0, 1.0);
    for (var x = 0; x < newWidth; x += 1) {
      final sourceX = (x + 0.5) * width / newWidth - 0.5;
      final x0 = sourceX.floor().clamp(0, width - 1);
      final x1 = (x0 + 1).clamp(0, width - 1);
      final fx = (sourceX - x0).clamp(0.0, 1.0);
      final top =
          source[y0 * width + x0] * (1 - fx) + source[y0 * width + x1] * fx;
      final bottom =
          source[y1 * width + x0] * (1 - fx) + source[y1 * width + x1] * fx;
      output[y * newWidth + x] = (top * (1 - fy) + bottom * fy).round();
    }
  }
  return output;
}

String _hex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final value in bytes) {
    buffer.write(value.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

int? _intOf(Object? value) => value is int ? value : null;

double? _doubleOf(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return null;
}
