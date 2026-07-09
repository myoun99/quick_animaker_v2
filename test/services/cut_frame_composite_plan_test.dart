import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/transform_track.dart';
import 'package:quick_animaker_v2/src/services/cut_frame_composite_plan.dart';

void main() {
  const canvasSize = CanvasSize(width: 4, height: 4);

  BitmapSurface surfaceWithMarker(int marker) {
    return BitmapSurface(
      canvasSize: canvasSize,
      tileSize: 4,
      tiles: {
        TileCoord(x: 0, y: 0): BitmapTile(
          coord: TileCoord(x: 0, y: 0),
          size: 4,
          pixels: Uint8List(4 * 4 * 4)..[0] = marker,
        ),
      },
    );
  }

  Frame frame(String id) =>
      Frame(id: FrameId(id), duration: 1, strokes: const []);

  Cut cut(List<Layer> layers) => Cut(
    id: const CutId('cut'),
    name: 'Cut',
    layers: layers,
    duration: 24,
    canvasSize: canvasSize,
  );

  // Resolver keyed by frame id suffix number as marker.
  BitmapSurface? resolver(Layer layer, Frame frame) {
    final marker = int.tryParse(frame.id.value.split('-').last);
    return marker == null ? null : surfaceWithMarker(marker);
  }

  int markerOf(CutFrameCompositeLayer layer) =>
      layer.surface.tiles.values.single.pixels[0];

  test('composites layers bottom to top in list order', () {
    final plan = planCutFrameComposite(
      cut: cut([
        Layer(
          id: const LayerId('bottom'),
          name: 'A',
          frames: [frame('frame-1')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-1'), length: 1),
          },
        ),
        Layer(
          id: const LayerId('top'),
          name: 'B',
          frames: [frame('frame-2')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-2'), length: 1),
          },
        ),
      ]),
      frameIndex: 0,
      surfaceResolver: resolver,
    );

    expect(plan.map(markerOf), [1, 2]);
  });

  test('skips camera, hidden and fully transparent layers', () {
    final plan = planCutFrameComposite(
      cut: cut([
        Layer(
          id: const LayerId('visible'),
          name: 'A',
          frames: [frame('frame-1')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-1'), length: 1),
          },
        ),
        Layer(
          id: const LayerId('hidden'),
          name: 'B',
          frames: [frame('frame-2')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-2'), length: 1),
          },
          isVisible: false,
        ),
        Layer(
          id: const LayerId('transparent'),
          name: 'C',
          frames: [frame('frame-3')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-3'), length: 1),
          },
          opacity: 0,
        ),
        Layer(
          id: const LayerId('camera'),
          name: 'Camera',
          frames: const [],
          timeline: const {},
          kind: LayerKind.camera,
        ),
      ]),
      frameIndex: 0,
      surfaceResolver: resolver,
    );

    expect(plan.map(markerOf), [1]);
  });

  test('held exposures keep the frame across their block coverage', () {
    final layer = Layer(
      id: const LayerId('layer'),
      name: 'A',
      frames: [frame('frame-1'), frame('frame-2')],
      timeline: {
        0: TimelineExposure.drawing(const FrameId('frame-1'), length: 6),
        6: TimelineExposure.drawing(const FrameId('frame-2'), length: 4),
      },
    );

    List<CutFrameCompositeLayer> planAt(int index) => planCutFrameComposite(
      cut: cut([layer]),
      frameIndex: index,
      surfaceResolver: resolver,
    );

    expect(planAt(0).map(markerOf), [1]);
    expect(planAt(5).map(markerOf), [1]);
    expect(planAt(6).map(markerOf), [2]);
    expect(planAt(9).map(markerOf), [2]);
    // Past the last block's explicit end nothing shows.
    expect(planAt(99), isEmpty);
  });

  test('blank exposures and missing surfaces contribute nothing', () {
    final plan = planCutFrameComposite(
      cut: cut([
        Layer(
          id: const LayerId('blank'),
          name: 'A',
          frames: [frame('frame-1')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-1'), length: 2),
          },
        ),
        Layer(
          id: const LayerId('undrawn'),
          name: 'B',
          frames: [frame('frame-x')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-x'), length: 1),
          },
        ),
      ]),
      frameIndex: 3,
      surfaceResolver: resolver,
    );

    expect(plan, isEmpty);
  });

  test('layer opacity carries into the plan', () {
    final plan = planCutFrameComposite(
      cut: cut([
        Layer(
          id: const LayerId('faded'),
          name: 'A',
          frames: [frame('frame-1')],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('frame-1'), length: 1),
          },
          opacity: 0.25,
        ),
      ]),
      frameIndex: 0,
      surfaceResolver: resolver,
    );

    expect(plan.single.opacity, 0.25);
  });

  test('layer transforms resolve into the plan; empty tracks stay the '
      'identity null', () {
    Layer transformed({TransformTrack? track}) => Layer(
      id: const LayerId('moved'),
      name: 'A',
      frames: [frame('frame-1')],
      timeline: {
        0: TimelineExposure.drawing(const FrameId('frame-1'), length: 12),
      },
      transformTrack: track,
    );

    // Empty track = identity: the plan carries null so compositors skip
    // the transform entirely.
    final identityPlan = planCutFrameComposite(
      cut: cut([transformed()]),
      frameIndex: 0,
      surfaceResolver: resolver,
    );
    expect(identityPlan.single.pose, isNull);

    // A keyed track resolves per frame (interpolating between keys); the
    // unkeyed components fall back to the identity pose (canvas center).
    final track = TransformTrack(
      keyframes: {
        0: TransformPose(center: CanvasPoint(x: 0, y: 0)),
        10: TransformPose(center: CanvasPoint(x: 10, y: 20)),
      },
    );
    final poseAt5 = planCutFrameComposite(
      cut: cut([transformed(track: track)]),
      frameIndex: 5,
      surfaceResolver: resolver,
    ).single.pose;
    expect(poseAt5, isNotNull);
    expect(poseAt5!.center.x, 5);
    expect(poseAt5.center.y, 10);
    expect(poseAt5.zoom, 1);
  });

  test('layerIdentityPose centers the canvas at zoom 1, no rotation', () {
    final pose = layerIdentityPose(canvasSize);
    expect(pose.center.x, 2);
    expect(pose.center.y, 2);
    expect(pose.zoom, 1);
    expect(pose.rotationDegrees, 0);
  });
}
