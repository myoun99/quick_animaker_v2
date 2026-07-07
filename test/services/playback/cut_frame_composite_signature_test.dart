import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/playback_quality.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/services/playback/cut_frame_composite_signature.dart';

void main() {
  Frame frame(String id) =>
      Frame(id: FrameId(id), duration: 1, strokes: const []);

  Layer drawingLayer({
    String id = 'layer-1',
    double opacity = 1,
    bool isVisible = true,
  }) {
    return Layer(
      id: LayerId(id),
      name: 'A',
      frames: [frame('frame-1'), frame('frame-2')],
      timeline: {
        0: TimelineExposure.drawing(const FrameId('frame-1'), length: 6),
        6: TimelineExposure.drawing(const FrameId('frame-2'), length: 4),
      },
      opacity: opacity,
      isVisible: isVisible,
    );
  }

  Cut cut({
    List<Layer>? layers,
    CanvasSize canvasSize = const CanvasSize(width: 100, height: 50),
  }) {
    return Cut(
      id: const CutId('cut'),
      name: 'Cut',
      layers: layers ?? [drawingLayer()],
      duration: 24,
      canvasSize: canvasSize,
    );
  }

  CutFrameCompositeSignature signature({
    Cut? forCut,
    int frameIndex = 0,
    PlaybackQuality quality = PlaybackQuality.half,
    int Function(LayerId, FrameId)? revisionOf,
  }) {
    return computeCutFrameCompositeSignature(
      cut: forCut ?? cut(),
      frameIndex: frameIndex,
      quality: quality,
      revisionOf: revisionOf ?? (_, _) => 7,
    );
  }

  test('held frames share one signature', () {
    expect(signature(frameIndex: 0), signature(frameIndex: 5));
    expect(signature(frameIndex: 6), signature(frameIndex: 9));
    expect(signature(frameIndex: 0), isNot(signature(frameIndex: 6)));
  });

  test('blank exposure contributes no layer', () {
    expect(signature(frameIndex: 10).layers, isEmpty);
  });

  test('camera and hidden layers are excluded', () {
    final withExtras = cut(
      layers: [
        drawingLayer(),
        drawingLayer(id: 'hidden', isVisible: false),
        drawingLayer(id: 'transparent', opacity: 0),
        Layer(
          id: const LayerId('camera'),
          name: 'Camera',
          frames: const [],
          timeline: const {},
          kind: LayerKind.camera,
        ),
      ],
    );

    expect(signature(forCut: withExtras), signature());
  });

  test('source revision changes the signature', () {
    expect(
      signature(revisionOf: (_, _) => 1),
      isNot(signature(revisionOf: (_, _) => 2)),
    );
  });

  test('opacity, visibility, quality and canvas size change the signature', () {
    final base = signature();

    expect(
      signature(forCut: cut(layers: [drawingLayer(opacity: 0.5)])),
      isNot(base),
    );
    expect(
      signature(
        forCut: cut(canvasSize: const CanvasSize(width: 200, height: 100)),
      ),
      isNot(base),
    );
    expect(signature(quality: PlaybackQuality.full), isNot(base));
  });

  test('layer order is part of the signature', () {
    final ab = cut(
      layers: [
        drawingLayer(),
        drawingLayer(id: 'layer-2'),
      ],
    );
    final ba = cut(
      layers: [
        drawingLayer(id: 'layer-2'),
        drawingLayer(),
      ],
    );

    expect(signature(forCut: ab), isNot(signature(forCut: ba)));
  });

  test('undrawn frames participate with their resolver revision', () {
    final drawn = signature(
      revisionOf: (_, frameId) => frameId.value == 'frame-1' ? 3 : 0,
    );
    final undrawn = signature(revisionOf: (_, _) => 0);

    expect(drawn, isNot(undrawn));
    expect(undrawn.layers.single.sourceRevision, 0);
  });
}
