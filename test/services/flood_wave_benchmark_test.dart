import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/native/qa_native_engine.dart';

/// R22-E3 wave-flood scaling bench: floods a fully-composed 8000x8000
/// raster (the worst single-call case — every compose tile is in the
/// wave) and prints wall times. Run twice to see thread scaling:
///   flutter test ... (full pool)  vs  QA_ENGINE_THREADS=2 ... (1 worker)
/// Assertions pin the RESULT (full-canvas bounds), not the clock.
void main() {
  test('8K fully-composed flood wall time (prints; pool-scaled)', () {
    final dllPath =
        '${Directory.current.path}/build/native_standalone/Release/qa_engine.dll';
    if (!File(dllPath).existsSync()) {
      markTestSkipped('qa_engine.dll not built');
      return;
    }
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = dllPath;
    final engine = QaNativeEngine.instance;
    expect(engine, isNotNull);

    const width = 8000;
    const height = 8000;
    final handles = engine!.acquireFloodRaster(
      width: width,
      height: height,
      composeTileSize: 256,
    );
    engine.fillPaperRect(
      handles: handles,
      left: 0,
      top: 0,
      rightExclusive: width,
      bottomExclusive: height,
      paperR: 250,
      paperG: 250,
      paperB: 250,
    );
    // A border ring so the flood has real walls.
    final rgb = handles.rgbView;
    for (var x = 0; x < width; x += 1) {
      for (final y in [0, height - 1]) {
        final base = (y * width + x) * 4;
        rgb[base] = 0;
        rgb[base + 1] = 0;
        rgb[base + 2] = 0;
      }
    }
    for (var y = 0; y < height; y += 1) {
      for (final x in [0, width - 1]) {
        final base = (y * width + x) * 4;
        rgb[base] = 0;
        rgb[base + 1] = 0;
        rgb[base + 2] = 0;
      }
    }
    handles.composedView.fillRange(0, handles.composedView.length, 1);

    final threads = Platform.environment['QA_ENGINE_THREADS'] ?? 'default';
    for (var run = 0; run < 3; run += 1) {
      final watch = Stopwatch()..start();
      final result = engine.floodFillRun(
        handles: handles,
        seedX: width ~/ 2,
        seedY: height ~/ 2,
        seedR: 250,
        seedG: 250,
        seedB: 250,
        tolerance: 32,
        ensureComposed: (_) {},
      )!;
      watch.stop();
      expect(result.minX, 1);
      expect(result.maxX, width - 2);
      expect(result.minY, 1);
      expect(result.maxY, height - 2);
      // ignore: avoid_print
      print(
        'WAVE8K threads=$threads run#$run '
        '${watch.elapsedMilliseconds}ms',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
