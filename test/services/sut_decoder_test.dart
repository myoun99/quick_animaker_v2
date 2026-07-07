import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/sut/sut_decoder.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds synthetic Clip Studio brush databases mirroring the real layout
/// (verified against CSP 1.x/3.x exports): `Node` tool entries, `Variant`
/// parameter rows (schema varies across versions — fixtures use a subset),
/// and `MaterialFile` rows whose FileData embeds PNGs.
void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('sut_decoder_test');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Uint8List effector(int flags, {int minimumPercent = 0}) {
    final bytes = ByteData(16)
      ..setInt32(0, 44)
      ..setInt32(4, 0xf0)
      ..setInt32(8, flags)
      ..setInt32(12, minimumPercent);
    return bytes.buffer.asUint8List();
  }

  /// UTF-16LE catalog reference blob, as CSP writes pattern arrays.
  Uint8List patternArray(String catalogPath) {
    final builder = BytesBuilder();
    builder.add(Uint8List(16)); // framing header (ignored by the decoder)
    for (final unit in catalogPath.codeUnits) {
      builder.addByte(unit & 0xFF);
      builder.addByte(unit >> 8);
    }
    builder.add(Uint8List(6));
    return builder.toBytes();
  }

  /// PNG bytes for a [width]x[height] opaque black rectangle.
  Future<Uint8List> blackPng(int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<String> buildFixture({
    required Uint8List tipPng,
    Uint8List? thumbnailPng,
    Uint8List? texturePng,
    String catalogPath = '.:36:43:fixture-tip-catalog',
    String textureCatalogPath = '.:25:01:fixture-texture-catalog',
    bool includeMaterial = true,
  }) async {
    final path = '${tempDirectory.path}/fixture.sut';
    final database = sqlite3.open(path);
    database.execute('''
      CREATE TABLE Node(_PW_ID INTEGER PRIMARY KEY, NodeUuid BLOB,
        NodeName TEXT, NodeVariantID INTEGER);
      CREATE TABLE Variant(_PW_ID INTEGER PRIMARY KEY, VariantID INTEGER,
        Opacity INTEGER, BrushSize REAL, BrushFlow INTEGER,
        BrushHardness INTEGER, BrushInterval REAL, BrushThickness INTEGER,
        BrushRotation REAL, BrushUsePatternImage INTEGER,
        BrushPatternImageArray BLOB, BrushSizeEffector BLOB,
        BrushOpacityEffector BLOB, BrushFlowEffector BLOB,
        BrushUseSpray INTEGER, BrushSpraySize REAL,
        BrushSprayDensity INTEGER, TextureImage BLOB,
        TextureScale2 REAL, TextureDensity INTEGER);
      CREATE TABLE MaterialFile(_PW_ID INTEGER PRIMARY KEY,
        CatalogPath TEXT, OriginalPath TEXT, FileData BLOB);
    ''');

    // Group root: no variant -> skipped.
    database.execute(
      "INSERT INTO Node(_PW_ID, NodeUuid, NodeName, NodeVariantID) "
      "VALUES (1, x'00', '', NULL)",
    );
    // Sampled brush.
    database.execute(
      'INSERT INTO Node(_PW_ID, NodeUuid, NodeName, NodeVariantID) '
      'VALUES (2, ?, ?, 9)',
      [Uint8List.fromList(List<int>.generate(16, (i) => i + 1)), '테스트 브러시'],
    );
    database.execute(
      'INSERT INTO Variant(VariantID, Opacity, BrushSize, BrushFlow, '
      'BrushHardness, BrushInterval, BrushThickness, BrushRotation, '
      'BrushUsePatternImage, BrushPatternImageArray, BrushSizeEffector, '
      'BrushOpacityEffector, BrushFlowEffector, BrushUseSpray, '
      'BrushSpraySize, BrushSprayDensity, TextureImage, TextureScale2, '
      'TextureDensity) '
      'VALUES (9, 80, 50.0, 60, 70, 15.0, 40, 200.0, 1, ?, ?, ?, ?, '
      '1, 200.0, 4, ?, 182.0, 90)',
      [
        patternArray(catalogPath),
        effector(0x10, minimumPercent: 59),
        effector(0x00),
        effector(0x30),
        texturePng == null ? null : patternArray(textureCatalogPath),
      ],
    );
    // Round brush without pattern data.
    database.execute(
      'INSERT INTO Node(_PW_ID, NodeUuid, NodeName, NodeVariantID) '
      'VALUES (3, ?, ?, 12)',
      [Uint8List.fromList(List<int>.generate(16, (i) => 40 + i)), 'Round Pen'],
    );
    database.execute(
      'INSERT INTO Variant(VariantID, Opacity, BrushSize, BrushHardness, '
      'BrushInterval) VALUES (12, 100, 8.0, 90, 8.0)',
    );

    if (includeMaterial) {
      // FileData: junk + a small thumbnail PNG + the (larger) tip PNG.
      final fileData = BytesBuilder();
      fileData.add(ascii.encode('catalog.zip'));
      fileData.add(Uint8List(21));
      if (thumbnailPng != null) {
        fileData.add(thumbnailPng);
        fileData.add(Uint8List(9));
      }
      fileData.add(tipPng);
      fileData.add(Uint8List(15));
      database.execute(
        'INSERT INTO MaterialFile(CatalogPath, OriginalPath, FileData) '
        'VALUES (?, ?, ?)',
        [catalogPath, '$catalogPath:data:material_0.layer', fileData.toBytes()],
      );
      if (texturePng != null) {
        final textureData = BytesBuilder();
        textureData.add(ascii.encode('catalog.zip'));
        textureData.add(Uint8List(13));
        textureData.add(texturePng);
        textureData.add(Uint8List(7));
        database.execute(
          'INSERT INTO MaterialFile(CatalogPath, OriginalPath, FileData) '
          'VALUES (?, ?, ?)',
          [
            textureCatalogPath,
            '$textureCatalogPath:data:material_0.layer',
            textureData.toBytes(),
          ],
        );
      }
    }
    database.close();
    return path;
  }

  test('imports sampled and round brushes with mapped parameters', () async {
    final path = await buildFixture(
      tipPng: await blackPng(6, 4),
      thumbnailPng: await blackPng(2, 2),
      texturePng: await blackPng(8, 8),
    );
    final result = await decodeSutBrushFile(
      filePath: path,
      sourceName: 'fixture',
    );

    expect(result.warnings, isEmpty);
    expect(result.presets, hasLength(2));

    final sampled = result.presets.first;
    expect(sampled.id.value, 'sut-0102030405060708090a0b0c0d0e0f10');
    expect(sampled.name, '테스트 브러시');
    final s = sampled.settings;
    expect(s.size, 50.0);
    expect(s.opacity, closeTo(0.8, 1e-9));
    expect(s.flow, closeTo(0.6, 1e-9));
    expect(s.hardness, closeTo(0.7, 1e-9));
    expect(s.spacing, closeTo(0.15, 1e-9));
    expect(s.roundness, closeTo(0.4, 1e-9));
    expect(s.angleDegrees, closeTo(20.0, 1e-9)); // 200 normalized into 0-180
    expect(s.pressureSize, isTrue); // effector flag 0x10
    expect(s.pressureOpacity, isTrue); // via the flow effector's 0x30
    expect(s.minimumSizeRatio, closeTo(0.59, 1e-9)); // effector minimum 59%
    // Spray maps to scatter: 200% spray size -> radius ratio 1.0.
    expect(s.scatterRadiusRatio, closeTo(1.0, 1e-9));
    expect(s.scatterCount, 4);
    // Paper texture joins its own material; scale 182% and density 90%.
    expect(s.textureMask, isNotNull);
    expect(s.textureMask!.size, 8);
    expect(s.textureScale, closeTo(1.82, 1e-9));
    expect(s.textureDensity, closeTo(0.9, 1e-9));

    // The larger PNG is the tip (the 2x2 one is a thumbnail); 6x4 pads to
    // a centered 6x6 square, black-opaque pixels become full coverage.
    final mask = s.tipMask!;
    expect(mask.size, 6);
    expect(mask.alpha[0], 0); // padded top row
    expect(mask.alpha[1 * 6 + 2], 255);
    expect(mask.alpha[5 * 6 + 2], 0); // padded bottom row

    final round = result.presets[1];
    expect(round.name, 'Round Pen');
    expect(round.settings.tipMask, isNull);
    expect(round.settings.size, 8.0);
    expect(round.settings.hardness, closeTo(0.9, 1e-9));
    expect(round.settings.pressureSize, isFalse);
  });

  test('missing material degrades to a round tip with a warning', () async {
    final path = await buildFixture(
      tipPng: await blackPng(4, 4),
      includeMaterial: false,
    );
    final result = await decodeSutBrushFile(
      filePath: path,
      sourceName: 'fixture',
    );

    expect(result.presets, hasLength(2));
    expect(result.presets.first.settings.tipMask, isNull);
    expect(result.warnings, isNotEmpty);
  });

  test('rejects non-sqlite and non-brush files with clear errors', () async {
    final bogus = '${tempDirectory.path}/bogus.sut';
    await File(bogus).writeAsString('not a database at all');
    expect(
      () => decodeSutBrushFile(filePath: bogus, sourceName: 'bogus'),
      throwsA(isA<SutDecodeException>()),
    );

    final empty = '${tempDirectory.path}/empty.sut';
    final database = sqlite3.open(empty);
    database.execute('CREATE TABLE Unrelated(a INTEGER)');
    database.close();
    expect(
      () => decodeSutBrushFile(filePath: empty, sourceName: 'empty'),
      throwsA(isA<SutDecodeException>()),
    );
  });

  test('oversized tips are downscaled to the mask cap', () async {
    final path = await buildFixture(tipPng: await blackPng(320, 100));
    final result = await decodeSutBrushFile(
      filePath: path,
      sourceName: 'fixture',
    );

    final mask = result.presets.first.settings.tipMask!;
    expect(mask.size, 256); // 320 -> capped at 256, padded square
    // The 100px side scales to 80 and centers vertically: rows well above
    // and below the band stay empty, the middle is full coverage.
    expect(mask.alpha[(128 * 256) + 128], 255);
    expect(mask.alpha[(20 * 256) + 128], 0);
    expect(mask.alpha[(235 * 256) + 128], 0);
  });
}
