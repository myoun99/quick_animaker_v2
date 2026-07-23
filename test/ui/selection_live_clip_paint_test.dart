import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_live_stroke_rasterizer.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection_region.dart';
import 'package:quick_animaker_v2/src/ui/canvas/active_stroke_overlay.dart';
import 'package:quick_animaker_v2/src/ui/canvas/bitmap_surface_painter.dart';

/// R26 #18, display half: what the pen SHOWS while drawing is clipped to
/// the selection exactly like what the commit lands.
///
/// The pre-blend route is the dangerous one — its overlay tiles carry the
/// commit's finished pixels and the base pass CLIPS THEM OUT, so a naive
/// "just clip the overlay draw" would punch a hole in the artwork outside
/// the selection. Both routes are driven here (the strip cap forces the
/// isolation-layer fallback), through the production painter.
void main() {
  const canvasSize = CanvasSize(width: 40, height: 40);

  BrushDab dab(double x, double y) => BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: 0xFF000000,
    size: 8,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: 0,
  );

  /// The selection: the LEFT half of the canvas.
  final leftHalf = CanvasSelectionRegion.shape(
    CanvasSelectionShape.rect(left: 0, top: 0, right: 20, bottom: 40),
  );

  Future<Uint8List> paintedBytes({
    required BitmapSurface base,
    required ActiveStrokeOverlayModel overlay,
    CanvasSelectionRegion? clip,
  }) async {
    final recorder = ui.PictureRecorder();
    BitmapSurfacePainter(
      surface: base,
      overlayModel: overlay,
      showTransparentBackground: false,
      strokeClipRegion: clip,
      // A fresh scope keeps another test's tile at the same coordinate out
      // of the stale-image fallback (the parity suite's rule).
      staleScope: Object(),
    ).paint(Canvas(recorder), const Size(40, 40));
    final image = await recorder.endRecording().toImage(40, 40);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  int alphaAt(Uint8List pixels, int x, int y) => pixels[(y * 40 + x) * 4 + 3];
  int redAt(Uint8List pixels, int x, int y) => pixels[(y * 40 + x) * 4];

  /// A horizontal stroke straddling the selection's right edge (x = 20).
  Future<ActiveStrokeOverlayModel> strokeOverlay({
    required bool preBlended,
    BitmapSurface? preBlendBase,
  }) async {
    final rasterizer = BrushLiveStrokeRasterizer(canvasSize: canvasSize);
    final dabs = [for (var x = 6; x <= 34; x += 4) dab(x.toDouble(), 20)];
    final region = rasterizer.blendFrom(dabs, from: 0)!;
    final model = ActiveStrokeOverlayModel(tileSize: 16);
    if (preBlended) {
      // The production contract (R27 #4b): every stroke pre-blends against
      // the cel it paints on, so the overlay tiles carry finished pixels.
      model.preBlendBase =
          preBlendBase ?? BitmapSurface(canvasSize: canvasSize, tileSize: 64);
    }
    addTearDown(model.dispose);
    model.updateRegion(source: rasterizer, region: region);
    await model.waitForPendingDecodes();
    expect(model.hasStrokeContent, isTrue);
    return model;
  }

  /// Paper the base surface so "the base survives outside the clip" is a
  /// visible fact and not just transparency.
  BitmapSurface paintedBase() => materializeBrushDabSequenceOnBitmapSurface(
    surface: BitmapSurface(canvasSize: canvasSize, tileSize: 64),
    sequence: BrushDabSequence([
      BrushDab(
        center: CanvasPoint(x: 20, y: 20),
        color: 0xFFCC2222,
        size: 40,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.square,
        pressure: 1,
        sequence: 0,
      ),
    ]),
  ).surface;

  test('a plain overlay draws only inside the region', () async {
    final overlay = await strokeOverlay(preBlended: false);
    final base = paintedBase();

    final unclipped = await paintedBytes(base: base, overlay: overlay);
    final clipped = await paintedBytes(
      base: base,
      overlay: overlay,
      clip: leftHalf,
    );

    // Unclipped: the black stroke covers both sides.
    expect(redAt(unclipped, 10, 20), lessThan(64));
    expect(redAt(unclipped, 30, 20), lessThan(64));

    // Clipped: the left keeps the stroke, the right shows the RED base
    // again — not a hole, not the stroke.
    expect(redAt(clipped, 10, 20), lessThan(64), reason: 'stroke inside');
    expect(redAt(clipped, 30, 20), greaterThan(160), reason: 'base outside');
    expect(alphaAt(clipped, 30, 20), 255, reason: 'no hole punched');
  });

  test('the PRE-BLENDED replacement route clips without holing the '
      'base outside the region', () async {
    final base = paintedBase();
    final overlay = await strokeOverlay(preBlended: true, preBlendBase: base);

    final clipped = await paintedBytes(
      base: base,
      overlay: overlay,
      clip: leftHalf,
    );
    expect(redAt(clipped, 10, 20), lessThan(64), reason: 'stroke inside');
    expect(
      redAt(clipped, 30, 20),
      greaterThan(160),
      reason: 'the base pass kept painting outside the selection',
    );
    expect(alphaAt(clipped, 30, 20), 255);
  });

  test('the isolation-layer FALLBACK route clips the same way', () async {
    final previousCap = BitmapSurfacePainter.maxReplacementClipStrips;
    BitmapSurfacePainter.maxReplacementClipStrips = 0;
    addTearDown(
      () => BitmapSurfacePainter.maxReplacementClipStrips = previousCap,
    );

    final base = paintedBase();
    final overlay = await strokeOverlay(preBlended: true, preBlendBase: base);
    final clipped = await paintedBytes(
      base: base,
      overlay: overlay,
      clip: leftHalf,
    );
    expect(redAt(clipped, 10, 20), lessThan(64), reason: 'stroke inside');
    expect(redAt(clipped, 30, 20), greaterThan(160), reason: 'base outside');
    expect(alphaAt(clipped, 30, 20), 255);
  });

  test('a composite region clips through its own fold — a subtracted '
      'hole shows the base', () async {
    final overlay = await strokeOverlay(preBlended: false);
    final base = paintedBase();
    final withHole = leftHalf
        .combinedWith(
          CanvasSelectionShape.rect(left: 0, top: 0, right: 40, bottom: 40),
          SelectionCombineMode.add,
        )!
        .combinedWith(
          CanvasSelectionShape.rect(left: 14, top: 0, right: 26, bottom: 40),
          SelectionCombineMode.subtract,
        )!;

    final clipped = await paintedBytes(
      base: base,
      overlay: overlay,
      clip: withHole,
    );
    expect(redAt(clipped, 8, 20), lessThan(64), reason: 'left of the hole');
    expect(redAt(clipped, 20, 20), greaterThan(160), reason: 'in the hole');
    expect(redAt(clipped, 32, 20), lessThan(64), reason: 'right of the hole');
  });

  test('NO region leaves the pipeline byte-identical', () async {
    final base = paintedBase();
    final overlay = await strokeOverlay(preBlended: true, preBlendBase: base);
    expect(
      await paintedBytes(base: base, overlay: overlay),
      await paintedBytes(base: base, overlay: overlay, clip: null),
    );
  });
}
