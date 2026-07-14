import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_stamp_image.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection.dart';

/// R19 pixel selection: Ctrl+T resamples the LIFTED STAMP through the
/// affine. Pins the exactness tiers: identity = same object, pure
/// translation = same bytes at a shifted center (the byte-preservation
/// contract — the user's retouch workflow), axis-aligned 90° rotation =
/// exact pixel permutation, scaling = alpha-weighted bilinear.
void main() {
  /// A 2×2 stamp with four distinct opaque colors:
  ///   R G
  ///   B W
  BrushDab stampDab() {
    final rgba = Uint8List.fromList([
      255, 0, 0, 255, /**/ 0, 255, 0, 255, //
      0, 0, 255, 255, /**/ 255, 255, 255, 255, //
    ]);
    return BrushDab(
      center: CanvasPoint(x: 10, y: 10),
      color: 0xFFFFFFFF,
      size: 2,
      opacity: 1,
      flow: 1,
      hardness: 1,
      tipShape: BrushTipShape.square,
      pressure: 1,
      sequence: 0,
      stamp: BrushStampImage(id: 'stamp', width: 2, height: 2, rgba: rgba),
    );
  }

  List<int> pixelOf(BrushStampImage stamp, int x, int y) {
    final offset = (y * stamp.width + x) * 4;
    return stamp.rgba.sublist(offset, offset + 4);
  }

  test('identity returns the dab untouched', () {
    final dab = stampDab();
    final out = transformStampDab(
      dab,
      SelectionAffine(pivot: CanvasPoint(x: 10, y: 10)),
    );
    expect(identical(out, dab), isTrue);
  });

  test('pure translation shifts the center and keeps the stamp BYTES '
      '(the retouch byte-preservation contract)', () {
    final dab = stampDab();
    final out = transformStampDab(
      dab,
      SelectionAffine(pivot: CanvasPoint(x: 10, y: 10), tx: 7, ty: -3),
    );
    expect(out.center, CanvasPoint(x: 17, y: 7));
    expect(
      identical(out.stamp!.rgba, dab.stamp!.rgba),
      isTrue,
      reason: 'no resample on a pure move — the same byte buffer travels',
    );
  });

  test('a 90° rotation about the stamp center is an exact pixel '
      'permutation (pixel centers land on pixel centers)', () {
    final dab = stampDab();
    final out = transformStampDab(
      dab,
      SelectionAffine(pivot: CanvasPoint(x: 10, y: 10), rotationDegrees: 90),
    );
    final stamp = out.stamp!;
    expect(stamp.width, 2);
    expect(stamp.height, 2);
    // 90° clockwise-in-screen-space (y down): R G / B W  →  B R / W G.
    expect(pixelOf(stamp, 0, 0), [0, 0, 255, 255]);
    expect(pixelOf(stamp, 1, 0), [255, 0, 0, 255]);
    expect(pixelOf(stamp, 0, 1), [255, 255, 255, 255]);
    expect(pixelOf(stamp, 1, 1), [0, 255, 0, 255]);
    expect(out.center, CanvasPoint(x: 10, y: 10));
  });

  test('a 2× scale doubles the footprint: interior pixels are fully '
      'opaque source color, edges feather, nothing changes hue', () {
    final rgba = Uint8List.fromList([
      for (var i = 0; i < 4; i += 1) ...[255, 0, 0, 255],
    ]);
    final dab = BrushDab(
      center: CanvasPoint(x: 10, y: 10),
      color: 0xFFFFFFFF,
      size: 2,
      opacity: 1,
      flow: 1,
      hardness: 1,
      tipShape: BrushTipShape.square,
      pressure: 1,
      sequence: 0,
      stamp: BrushStampImage(id: 'red', width: 2, height: 2, rgba: rgba),
    );
    final out = transformStampDab(
      dab,
      SelectionAffine(pivot: CanvasPoint(x: 10, y: 10), sx: 2, sy: 2),
    );
    final stamp = out.stamp!;
    expect(stamp.width, 4);
    expect(stamp.height, 4);
    expect(out.center, CanvasPoint(x: 10, y: 10));
    for (var y = 0; y < 4; y += 1) {
      for (var x = 0; x < 4; x += 1) {
        final pixel = pixelOf(stamp, x, y);
        if (pixel[3] == 0) {
          continue;
        }
        expect(pixel.sublist(0, 3), [255, 0, 0], reason: 'pure red ($x,$y)');
        final interior = x >= 1 && x <= 2 && y >= 1 && y <= 2;
        if (interior) {
          expect(pixel[3], 255, reason: 'interior full alpha ($x,$y)');
        }
      }
    }
  });

  test('transparent texels never bleed color into opaque neighbours '
      '(alpha-weighted sampling)', () {
    // A 2×1 stamp: opaque WHITE next to fully transparent BLACK.
    final rgba = Uint8List.fromList([
      255, 255, 255, 255, /**/ 0, 0, 0, 0, //
    ]);
    final dab = BrushDab(
      center: CanvasPoint(x: 10, y: 10),
      color: 0xFFFFFFFF,
      size: 2,
      opacity: 1,
      flow: 1,
      hardness: 1,
      tipShape: BrushTipShape.square,
      pressure: 1,
      sequence: 0,
      stamp: BrushStampImage(id: 'edge', width: 2, height: 1, rgba: rgba),
    );
    final out = transformStampDab(
      dab,
      SelectionAffine(pivot: CanvasPoint(x: 10, y: 10), sx: 2, sy: 2),
    );
    final stamp = out.stamp!;
    for (var y = 0; y < stamp.height; y += 1) {
      for (var x = 0; x < stamp.width; x += 1) {
        final pixel = pixelOf(stamp, x, y);
        if (pixel[3] == 0) {
          continue;
        }
        expect(
          pixel.sublist(0, 3),
          [255, 255, 255],
          reason:
              'every visible pixel stays pure white — the transparent '
              'black texel contributes no color at ($x,$y)',
        );
      }
    }
  });
}
