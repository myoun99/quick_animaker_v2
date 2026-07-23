import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/dirty_region.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection_paint_clip.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection_region.dart';

/// R26 #18: painting clips to the selection. The clip runs on the
/// stroke's own straight-alpha buffer, which is why one pass covers every
/// brush blend mode (alpha 0 = "destination survives" for all of them).
void main() {
  CanvasSelectionRegion regionRect(double l, double t, double r, double b) =>
      CanvasSelectionRegion.shape(
        CanvasSelectionShape.rect(left: l, top: t, right: r, bottom: b),
      );

  /// A solid opaque red block covering [bounds].
  Uint8List solidBlock(DirtyRegion bounds) {
    final pixels = Uint8List(bounds.width * bounds.height * 4);
    for (var i = 0; i < bounds.width * bounds.height; i += 1) {
      pixels[i * 4] = 255;
      pixels[i * 4 + 3] = 255;
    }
    return pixels;
  }

  int alphaAt(Uint8List pixels, DirtyRegion bounds, int x, int y) =>
      pixels[((y - bounds.top) * bounds.width + (x - bounds.left)) * 4 + 3];

  test('pixels inside the region survive, pixels outside are zeroed', () {
    final bounds = DirtyRegion.fromLTBR(
      left: 0,
      top: 0,
      rightExclusive: 20,
      bottomExclusive: 20,
    );
    final clipped = clipStrokePixelsToSelection(
      pixels: solidBlock(bounds),
      bounds: bounds,
      region: regionRect(5, 5, 15, 15),
    )!;
    expect(alphaAt(clipped.pixels, bounds, 10, 10), 255);
    expect(alphaAt(clipped.pixels, bounds, 2, 2), 0);
    expect(alphaAt(clipped.pixels, bounds, 17, 17), 0);
  });

  test('a cleared texel loses its RGB too — no colour ghost behind α0', () {
    final bounds = DirtyRegion.fromLTBR(
      left: 0,
      top: 0,
      rightExclusive: 4,
      bottomExclusive: 4,
    );
    final clipped = clipStrokePixelsToSelection(
      pixels: solidBlock(bounds),
      bounds: bounds,
      region: regionRect(2, 2, 4, 4),
    )!;
    // (0, 0) is outside: every channel zero.
    expect(clipped.pixels.sublist(0, 4), everyElement(0));
  });

  test('a stroke entirely outside the selection clips to NOTHING', () {
    final bounds = DirtyRegion.fromLTBR(
      left: 0,
      top: 0,
      rightExclusive: 4,
      bottomExclusive: 4,
    );
    expect(
      clipStrokePixelsToSelection(
        pixels: solidBlock(bounds),
        bounds: bounds,
        region: regionRect(50, 50, 60, 60),
      ),
      isNull,
    );
  });

  test('the composite region clips through the SAME fold (hole stays out)', () {
    final bounds = DirtyRegion.fromLTBR(
      left: 0,
      top: 0,
      rightExclusive: 20,
      bottomExclusive: 20,
    );
    final region = regionRect(
      0,
      0,
      20,
      20,
    ).combinedWith(
      CanvasSelectionShape.rect(left: 8, top: 8, right: 12, bottom: 12),
      SelectionCombineMode.subtract,
    )!;
    final clipped = clipStrokePixelsToSelection(
      pixels: solidBlock(bounds),
      bounds: bounds,
      region: region,
    )!;
    expect(alphaAt(clipped.pixels, bounds, 2, 2), 255);
    expect(alphaAt(clipped.pixels, bounds, 10, 10), 0, reason: 'in the hole');
  });

  group('rasterizeStrokeForClipping (no live raster available)', () {
    BrushDab dab(double x, double y, {bool erase = false}) => BrushDab(
      center: CanvasPoint(x: x, y: y),
      color: 0xFF0000FF,
      size: 6,
      opacity: 1,
      flow: 1,
      hardness: 1,
      tipShape: BrushTipShape.square,
      pressure: 1,
      sequence: 0,
      erase: erase,
    );

    test('rasterizes coverage the clip can then cut', () {
      final rasterized = rasterizeStrokeForClipping(
        dabs: [dab(20, 20)],
        canvasSize: const CanvasSize(width: 64, height: 64),
        tileSize: 32,
      )!;
      expect(rasterized.bounds.width, greaterThan(0));
      final clipped = clipStrokePixelsToSelection(
        pixels: rasterized.pixels,
        bounds: rasterized.bounds,
        region: regionRect(0, 0, 20, 64),
      );
      // The dab straddles x = 20, so the left half survives the clip.
      expect(clipped, isNotNull);
    });

    test('ERASE dabs rasterize as coverage (the flag is re-applied at the '
        'composite, never inside the buffer)', () {
      final erased = rasterizeStrokeForClipping(
        dabs: [dab(20, 20, erase: true)],
        canvasSize: const CanvasSize(width: 64, height: 64),
        tileSize: 32,
      );
      // Erasing an EMPTY scratch surface would produce nothing at all; the
      // helper flips the flag so the coverage is there to clip.
      expect(erased, isNotNull);
      expect(
        erased!.pixels.any((byte) => byte != 0),
        isTrue,
        reason: 'coverage, not an empty buffer',
      );
    });
  });
}
