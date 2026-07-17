import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/native/qa_native_engine.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_tile_ops.dart';

/// UI-R18 O7 T1: the native grid-tile rasterizer must be BYTE-IDENTICAL
/// to the Dart reference — randomized op streams (rects, lines, atlas
/// glyph blits; off-tile coordinates, edge alphas) rasterized through
/// both paths and compared per pixel. Skips (loudly) when no locally
/// built binary is found.
void main() {
  final dllPath =
      '${Directory.current.path}\\build\\native_standalone\\Release\\qa_engine.dll';
  final available = File(dllPath).existsSync();

  setUp(() {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = dllPath;
    QaNativeEngine.debugForceDartFallback = false;
  });

  tearDown(() {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = null;
    QaNativeEngine.debugForceDartFallback = false;
  });

  int randomRgba(Random random) {
    final roll = random.nextInt(10);
    final alpha = roll == 0
        ? 0
        : roll == 1
        ? 255
        : random.nextInt(256);
    return random.nextInt(256) |
        (random.nextInt(256) << 8) |
        (random.nextInt(256) << 16) |
        (alpha << 24);
  }

  test('native grid tile raster == Dart reference, byte for byte '
      '(randomized op streams)', () {
    if (!available) {
      markTestSkipped(
        'qa_engine.dll not built — run: cmake -S native -B '
        'build/native_standalone && cmake --build build/native_standalone '
        '--config Release',
      );
      return;
    }
    final engine = QaNativeEngine.instance;
    expect(engine, isNotNull, reason: 'the locally built engine must load');

    final random = Random(20260718);
    for (var round = 0; round < 32; round += 1) {
      final tileWidth = 1 + random.nextInt(96);
      final tileHeight = 1 + random.nextInt(48);
      const atlasWidth = 24;
      const atlasHeight = 24;
      final atlas = Uint8List(atlasWidth * atlasHeight);
      for (var i = 0; i < atlas.length; i += 1) {
        final roll = random.nextInt(8);
        atlas[i] = roll == 0
            ? 0
            : roll == 1
            ? 255
            : random.nextInt(256);
      }

      final writer = TimelineGridTileOpWriter();
      final opCount = random.nextInt(24);
      for (var op = 0; op < opCount; op += 1) {
        // Coordinates deliberately overhang every edge (negative and
        // past-extent): clipping must agree exactly.
        final x = random.nextInt(tileWidth + 24) - 12;
        final y = random.nextInt(tileHeight + 24) - 12;
        switch (random.nextInt(4)) {
          case 0:
            writer.fillRect(
              x,
              y,
              random.nextInt(40),
              random.nextInt(24),
              randomRgba(random),
            );
          case 1:
            writer.hline(
              x,
              y,
              random.nextInt(60),
              1 + random.nextInt(3),
              randomRgba(random),
            );
          case 2:
            writer.vline(
              x,
              y,
              random.nextInt(40),
              1 + random.nextInt(3),
              randomRgba(random),
            );
          case 3:
            writer.glyph(
              x,
              y,
              random.nextInt(atlasWidth + 8) - 4,
              random.nextInt(atlasHeight + 8) - 4,
              random.nextInt(16),
              random.nextInt(16),
              randomRgba(random),
            );
        }
      }
      final ops = writer.build();
      final background = randomRgba(random);

      final nativePixels = Uint8List(tileWidth * tileHeight * 4);
      final nativeResult = engine!.gridRasterTileBytes(
        pixels: nativePixels,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        backgroundRgba: background,
        ops: ops,
        atlas: atlas,
        atlasWidth: atlasWidth,
        atlasHeight: atlasHeight,
      );
      expect(nativeResult, 0, reason: 'round $round');

      final referencePixels = Uint8List(tileWidth * tileHeight * 4);
      final referenceResult = timelineGridRasterTileReference(
        pixels: referencePixels,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        backgroundRgba: background,
        ops: ops,
        atlas: atlas,
        atlasWidth: atlasWidth,
        atlasHeight: atlasHeight,
      );
      expect(referenceResult, 0);

      expect(
        nativePixels,
        equals(referencePixels),
        reason: 'round $round ($tileWidth x $tileHeight, $opCount ops)',
      );
      // A finished tile is OPAQUE by contract.
      for (var i = 3; i < nativePixels.length; i += 4) {
        expect(nativePixels[i], 255, reason: 'round $round alpha at $i');
      }
    }
  });

  test('the error contract matches: truncated stream / glyph without an '
      'atlas / unknown op', () {
    if (!available) {
      markTestSkipped('qa_engine.dll not built');
      return;
    }
    final engine = QaNativeEngine.instance!;

    int native(Int32List ops, {Uint8List? atlas}) {
      return engine.gridRasterTileBytes(
        pixels: Uint8List(8 * 8 * 4),
        tileWidth: 8,
        tileHeight: 8,
        backgroundRgba: 0,
        ops: ops,
        atlas: atlas,
        atlasWidth: atlas == null ? 0 : 1,
        atlasHeight: atlas == null ? 0 : 1,
      );
    }

    int reference(Int32List ops, {Uint8List? atlas}) {
      return timelineGridRasterTileReference(
        pixels: Uint8List(8 * 8 * 4),
        tileWidth: 8,
        tileHeight: 8,
        backgroundRgba: 0,
        ops: ops,
        atlas: atlas,
        atlasWidth: atlas == null ? 0 : 1,
        atlasHeight: atlas == null ? 0 : 1,
      );
    }

    final truncated = Int32List.fromList([TimelineGridTileOp.fillRect, 0, 0]);
    expect(native(truncated), -2);
    expect(reference(truncated), -2);

    final glyphNoAtlas = Int32List.fromList([
      TimelineGridTileOp.glyph,
      0,
      0,
      0,
      0,
      1,
      1,
      -1,
    ]);
    expect(native(glyphNoAtlas), -3);
    expect(reference(glyphNoAtlas), -3);

    final unknown = Int32List.fromList([99]);
    expect(native(unknown), -4);
    expect(reference(unknown), -4);
  });

  test('the reference alone is deterministic and clips off-tile ops to '
      'no-ops (fallback-path pin, no binary needed)', () {
    final writer = TimelineGridTileOpWriter()
      ..fillRect(-100, -100, 10, 10, 0x80FFFFFF)
      ..fillRect(1000, 1000, 10, 10, 0x80FFFFFF)
      ..hline(0, 2, 8, 1, timelineGridPackRgba(const Color(0xFF336699)));
    final ops = writer.build();

    final a = Uint8List(8 * 8 * 4);
    final b = Uint8List(8 * 8 * 4);
    expect(
      timelineGridRasterTileReference(
        pixels: a,
        tileWidth: 8,
        tileHeight: 8,
        backgroundRgba: timelineGridPackRgba(const Color(0xFF222222)),
        ops: ops,
      ),
      0,
    );
    expect(
      timelineGridRasterTileReference(
        pixels: b,
        tileWidth: 8,
        tileHeight: 8,
        backgroundRgba: timelineGridPackRgba(const Color(0xFF222222)),
        ops: ops,
      ),
      0,
    );
    expect(a, equals(b));
    // Row 2 carries the line color; row 0 stays background.
    expect(a[(2 * 8) * 4], 0x33);
    expect(a[0], 0x22);
  });
}
