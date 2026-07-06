import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';
import '../../models/brush_settings.dart';
import '../../models/brush_tip_mask.dart';
import 'abr_byte_reader.dart';
import 'photoshop_descriptor.dart';

/// Result of decoding a Photoshop `.abr` brush file.
class AbrImportResult {
  const AbrImportResult({required this.presets, required this.warnings});

  /// One preset per usable brush, ready for the preset library.
  final List<BrushPreset> presets;

  /// Human-readable notes about entries that could not be fully imported.
  final List<String> warnings;
}

/// Thrown when the file cannot be read as a supported ABR at all.
class AbrDecodeException implements Exception {
  const AbrDecodeException(this.message);

  final String message;

  @override
  String toString() => 'AbrDecodeException: $message';
}

/// Decodes a Photoshop `.abr` brush file (version 6/7/10 — the format every
/// modern Photoshop writes) into brush presets.
///
/// The `samp` section provides the sampled tip bitmaps (grayscale, raw or
/// PackBits RLE); the `desc` section provides names and tip parameters
/// (diameter, spacing, angle, roundness, hardness) for sampled AND computed
/// brushes, joined to their bitmaps by the sampled-data UUID. When the
/// descriptor cannot be parsed, the tip bitmaps still import with default
/// settings and a warning.
AbrImportResult decodeAbrBrushFile(Uint8List bytes, {required String sourceName}) {
  final reader = AbrByteReader(bytes);
  if (bytes.length < 4) {
    throw const AbrDecodeException('File is too short to be an ABR file.');
  }
  final version = reader.readInt16();
  if (version == 1 || version == 2) {
    throw AbrDecodeException(
      'ABR version $version (Photoshop 6 era) is not supported yet; '
      're-save the brushes with a modern Photoshop.',
    );
  }
  if (version != 6 && version != 7 && version != 10) {
    throw AbrDecodeException('Not a supported ABR file (version $version).');
  }
  final subversion = reader.readInt16();

  final warnings = <String>[];
  final tipsByKey = <String, BrushTipMask>{};
  final tipOrder = <String>[];
  PsDescriptor? descriptor;

  while (_seekTo8bimSection(reader)) {
    final tag = reader.readAscii(4);
    final sectionLength = reader.readInt32();
    final sectionEnd = reader.offset + sectionLength;
    if (sectionLength < 0 || sectionEnd > reader.length) {
      throw const AbrDecodeException('Corrupt ABR section length.');
    }
    switch (tag) {
      case 'samp':
        _readSampledTips(
          reader,
          sectionEnd: sectionEnd,
          subversion: subversion,
          tipsByKey: tipsByKey,
          tipOrder: tipOrder,
          warnings: warnings,
        );
      case 'desc':
        try {
          descriptor = readVersionedDescriptor(
            AbrByteReader(reader.readBytes(sectionLength)),
          );
        } on FormatException catch (error) {
          warnings.add(
            'Brush parameters could not be read (${error.message}); '
            'imported tips with default settings.',
          );
        }
      default:
        break;
    }
    reader.offset = sectionEnd;
  }

  if (tipsByKey.isEmpty && descriptor == null) {
    throw const AbrDecodeException('No brushes found in the ABR file.');
  }

  final presets = <BrushPreset>[];
  final usedTipKeys = <String>{};
  final brushList = _brushListOf(descriptor);
  if (brushList != null) {
    var computedIndex = 0;
    for (final entry in brushList) {
      if (entry is! PsDescriptor) {
        continue;
      }
      final preset = _presetFromBrushDescriptor(
        entry,
        tipsByKey: tipsByKey,
        usedTipKeys: usedTipKeys,
        sourceName: sourceName,
        computedIndex: () => ++computedIndex,
        warnings: warnings,
      );
      if (preset != null) {
        presets.add(preset);
      }
    }
  }

  // Tips the descriptor did not claim (or no descriptor at all): import
  // them with default settings so no artwork data is silently dropped.
  var unnamedIndex = 0;
  for (final key in tipOrder) {
    if (usedTipKeys.contains(key)) {
      continue;
    }
    unnamedIndex += 1;
    presets.add(
      BrushPreset(
        id: BrushPresetId('abr-$key'),
        name: '$sourceName tip $unnamedIndex',
        settings: _settingsForTip(
          tipsByKey[key]!,
          diameterPixels: tipsByKey[key]!.size.toDouble(),
          spacingRatio: 0.25,
          angleDegrees: 0,
          roundness: 1,
        ),
      ),
    );
  }

  if (presets.isEmpty) {
    throw const AbrDecodeException(
      'The ABR file contained no importable brushes.',
    );
  }
  return AbrImportResult(presets: presets, warnings: warnings);
}

/// Positions the reader at the start of the next `8BIM` signature; returns
/// false at end of data. Robust against writer padding differences.
bool _seekTo8bimSection(AbrByteReader reader) {
  while (reader.remaining >= 12) {
    final bytes = reader.readBytes(4);
    if (bytes[0] == 0x38 && // 8
        bytes[1] == 0x42 && // B
        bytes[2] == 0x49 && // I
        bytes[3] == 0x4D) {
      return true;
    }
    reader.offset -= 3;
  }
  return false;
}

void _readSampledTips(
  AbrByteReader reader, {
  required int sectionEnd,
  required int subversion,
  required Map<String, BrushTipMask> tipsByKey,
  required List<String> tipOrder,
  required List<String> warnings,
}) {
  while (reader.offset < sectionEnd - 4) {
    final entryLength = reader.readInt32();
    if (entryLength <= 0) {
      break;
    }
    final entryStart = reader.offset;
    final nextEntry = math.min(
      entryStart + ((entryLength + 3) & ~3),
      sectionEnd,
    );
    try {
      final key = reader.readPascalString();
      // The fixed preamble (key + short coordinates, plus unknown bytes in
      // subversion >= 2) measured from the entry start.
      final preamble = subversion == 1 ? 47 : 301;
      final consumed = reader.offset - entryStart;
      if (preamble > consumed) {
        reader.skip(preamble - consumed);
      }

      final top = reader.readInt32();
      final left = reader.readInt32();
      final bottom = reader.readInt32();
      final right = reader.readInt32();
      final depth = reader.readInt16();
      final compressed = reader.readUint8() != 0;
      final width = right - left;
      final height = bottom - top;
      if (width <= 0 || height <= 0) {
        throw const FormatException('Empty tip bitmap.');
      }
      if (depth != 8) {
        warnings.add(
          'Skipped tip "$key": $depth-bit tips are not supported.',
        );
        continue;
      }

      final pixels = compressed
          ? _decodePackBitsScanlines(reader, width: width, height: height)
          : Uint8List.fromList(reader.readBytes(width * height));
      final mask = _squareMaskFromTipPixels(
        key: key,
        pixels: pixels,
        width: width,
        height: height,
      );
      tipsByKey[key] = mask;
      tipOrder.add(key);
    } on FormatException catch (error) {
      warnings.add('Skipped a corrupt sampled tip (${error.message}).');
    } finally {
      reader.offset = nextEntry;
    }
  }
}

/// ABR tip RLE: one 16-bit compressed byte count per scanline, then
/// PackBits data per scanline.
Uint8List _decodePackBitsScanlines(
  AbrByteReader reader, {
  required int width,
  required int height,
}) {
  final scanlineLengths = List<int>.generate(
    height,
    (_) => reader.readUint16(),
  );
  final output = Uint8List(width * height);
  for (var y = 0; y < height; y += 1) {
    final compressed = reader.readBytes(scanlineLengths[y]);
    var read = 0;
    var write = y * width;
    final rowEnd = write + width;
    while (read < compressed.length && write < rowEnd) {
      final control = compressed[read].toSigned(8);
      read += 1;
      if (control >= 0) {
        final count = control + 1;
        if (read + count > compressed.length || write + count > rowEnd) {
          throw const FormatException('Corrupt RLE scanline.');
        }
        output.setRange(write, write + count, compressed, read);
        read += count;
        write += count;
      } else if (control != -128) {
        final count = 1 - control;
        if (read >= compressed.length || write + count > rowEnd) {
          throw const FormatException('Corrupt RLE scanline.');
        }
        output.fillRange(write, write + count, compressed[read]);
        read += 1;
        write += count;
      }
    }
    if (write != rowEnd) {
      throw const FormatException('RLE scanline ended short.');
    }
  }
  return output;
}

/// Pads a tip bitmap to a centered square, matching the engine's
/// square-mask requirement.
BrushTipMask _squareMaskFromTipPixels({
  required String key,
  required Uint8List pixels,
  required int width,
  required int height,
}) {
  final side = math.max(width, height);
  final alpha = Uint8List(side * side);
  final offsetX = (side - width) ~/ 2;
  final offsetY = (side - height) ~/ 2;
  for (var y = 0; y < height; y += 1) {
    alpha.setRange(
      (offsetY + y) * side + offsetX,
      (offsetY + y) * side + offsetX + width,
      pixels,
      y * width,
    );
  }
  return BrushTipMask(id: 'abr-$key', size: side, alpha: alpha);
}

List<Object?>? _brushListOf(PsDescriptor? descriptor) {
  if (descriptor == null) {
    return null;
  }
  final direct = descriptor['Brsh'];
  if (direct is List) {
    return direct;
  }
  // Defensive: some writers nest the list one level down.
  for (final value in descriptor.items.values) {
    if (value is List) {
      return value;
    }
  }
  return null;
}

BrushPreset? _presetFromBrushDescriptor(
  PsDescriptor entry, {
  required Map<String, BrushTipMask> tipsByKey,
  required Set<String> usedTipKeys,
  required String sourceName,
  required int Function() computedIndex,
  required List<String> warnings,
}) {
  final tip = entry.childDescriptor('Brsh') ?? entry;
  final name = entry.textValue('Nm  ') ?? tip.textValue('Nm  ');

  final sampledKey = tip.textValue('sampledData');
  BrushTipMask? mask;
  if (sampledKey != null) {
    mask = tipsByKey[sampledKey];
    if (mask == null) {
      warnings.add(
        'Brush "${name ?? sampledKey}" references a missing tip bitmap; '
        'skipped.',
      );
      return null;
    }
    usedTipKeys.add(sampledKey);
  }

  final diameter =
      tip.numberValue('Dmtr') ?? mask?.size.toDouble() ?? 24.0;
  final spacingPercent = tip.numberValue('Spcn') ?? 25.0;
  final angle = tip.numberValue('Angl') ?? 0.0;
  final roundnessPercent = tip.numberValue('Rndn') ?? 100.0;
  final hardnessPercent = tip.numberValue('Hrdn') ?? 100.0;

  final id = sampledKey != null
      ? BrushPresetId('abr-$sampledKey')
      : BrushPresetId('abr-$sourceName-computed-${computedIndex()}');
  final fallbackName = sampledKey != null
      ? '$sourceName brush'
      : '$sourceName round';

  return BrushPreset(
    id: id,
    name: (name == null || name.isEmpty) ? fallbackName : name,
    settings: _settingsForTip(
      mask,
      diameterPixels: diameter,
      spacingRatio: spacingPercent / 100.0,
      angleDegrees: angle,
      roundness: roundnessPercent / 100.0,
      hardness: hardnessPercent / 100.0,
    ),
  );
}

BrushSettings _settingsForTip(
  BrushTipMask? mask, {
  required double diameterPixels,
  required double spacingRatio,
  required double angleDegrees,
  required double roundness,
  double hardness = 1.0,
}) {
  // Photoshop angles span -180..180; the ellipse repeats every 180.
  final normalizedAngle = ((angleDegrees % 180.0) + 180.0) % 180.0;
  return BrushSettings(
    size: diameterPixels.isFinite && diameterPixels > 0 ? diameterPixels : 24,
    spacing: spacingRatio.isFinite && spacingRatio > 0
        ? spacingRatio.clamp(0.01, 10.0).toDouble()
        : 0.25,
    angleDegrees: normalizedAngle.isFinite ? normalizedAngle : 0.0,
    roundness: roundness.isFinite
        ? roundness.clamp(0.01, 1.0).toDouble()
        : 1.0,
    hardness: hardness.isFinite ? hardness.clamp(0.0, 1.0).toDouble() : 1.0,
    tipMask: mask,
  );
}
