import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_stamp_image.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection.dart';

/// R14-④ lift builder: the erase+stamp pair cuts EXACTLY the selection's
/// pixels, a zero-move drop is byte-identical, and a translated stamp
/// lands the pixels at the destination.
void main() {
  const canvasSize = CanvasSize(width: 16, height: 16);

  BitmapSurface paintedSurface() {
    // A 4x4 opaque gradient block at (2,2)..(5,5).
    final rgba = Uint8List(4 * 4 * 4);
    for (var i = 0; i < 16; i += 1) {
      rgba[i * 4] = 40 + i * 10;
      rgba[i * 4 + 1] = 200 - i * 5;
      rgba[i * 4 + 2] = 90;
      rgba[i * 4 + 3] = 255;
    }
    return materializeBrushDabSequenceOnBitmapSurface(
      surface: BitmapSurface(canvasSize: canvasSize, tileSize: 8),
      sequence: BrushDabSequence([
        BrushDab(
          center: CanvasPoint(x: 4, y: 4),
          color: 0xFF000000,
          size: 4,
          opacity: 1,
          flow: 1,
          hardness: 1,
          tipShape: BrushTipShape.square,
          pressure: 1,
          sequence: 0,
          stamp: BrushStampImage(id: 'base', width: 4, height: 4, rgba: rgba),
        ),
      ]),
    ).surface;
  }

  List<int> pixelAt(BitmapSurface surface, int x, int y) {
    final tileSize = surface.tileSize;
    final tile = surface.tiles[TileCoord(x: x ~/ tileSize, y: y ~/ tileSize)];
    if (tile == null) {
      return const [0, 0, 0, 0];
    }
    final pixels = tile.pixels;
    final offset = ((y % tileSize) * tileSize + (x % tileSize)) * 4;
    return pixels.sublist(offset, offset + 4);
  }

  Uint8List snapshot(BitmapSurface surface) {
    final bytes = Uint8List(canvasSize.width * canvasSize.height * 4);
    for (var y = 0; y < canvasSize.height; y += 1) {
      for (var x = 0; x < canvasSize.width; x += 1) {
        bytes.setRange(
          (y * canvasSize.width + x) * 4,
          (y * canvasSize.width + x) * 4 + 4,
          pixelAt(surface, x, y),
        );
      }
    }
    return bytes;
  }

  test('a zero-move lift-and-drop is byte-identical to the original', () {
    final surface = paintedSurface();
    final before = snapshot(surface);

    final lift = buildSelectionLiftDabs(
      shape: CanvasSelectionShape.rect(left: 1, top: 1, right: 7, bottom: 7),
      surface: surface,
      liftId: 'roundtrip',
    )!;
    final after = materializeBrushDabSequenceOnBitmapSurface(
      surface: surface,
      sequence: BrushDabSequence([lift.eraseDab, lift.stampDab]),
    ).surface;

    expect(snapshot(after), before);
  });

  test('a PARTIAL selection lifts only the covered pixels — the boundary '
      'content splits between origin remnant and moved stamp', () {
    final surface = paintedSurface();

    // Select the LEFT half of the block: x in [2, 3].
    final lift = buildSelectionLiftDabs(
      shape: CanvasSelectionShape.rect(left: 2, top: 2, right: 4, bottom: 6),
      surface: surface,
      liftId: 'partial',
    )!;

    // Drop the lifted pixels 8px to the right (stamp center +8).
    final movedStamp = lift.stampDab.copyWith(
      center: CanvasPoint(
        x: lift.stampDab.center.x + 8,
        y: lift.stampDab.center.y,
      ),
    );
    final after = materializeBrushDabSequenceOnBitmapSurface(
      surface: surface,
      sequence: BrushDabSequence([lift.eraseDab, movedStamp]),
    ).surface;

    // Origin: selected columns cut, unselected columns intact.
    expect(pixelAt(after, 2, 2), const [0, 0, 0, 0]);
    expect(pixelAt(after, 3, 4), const [0, 0, 0, 0]);
    expect(pixelAt(after, 4, 2), isNot(const [0, 0, 0, 0]));
    expect(pixelAt(after, 5, 5), isNot(const [0, 0, 0, 0]));
    // Destination: the exact source bytes landed +8 to the right.
    expect(pixelAt(after, 10, 2), pixelAt(surface, 2, 2));
    expect(pixelAt(after, 11, 4), pixelAt(surface, 3, 4));
  });

  test('a selection over empty canvas builds no lift', () {
    expect(
      buildSelectionLiftDabs(
        shape: CanvasSelectionShape.rect(
          left: 10,
          top: 10,
          right: 14,
          bottom: 14,
        ),
        surface: paintedSurface(),
        liftId: 'empty',
      ),
      isNull,
    );
  });
}
