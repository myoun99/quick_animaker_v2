import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_layer_policy.dart';

void main() {
  group('storyboardLayerForCut', () {
    test('returns null when no storyboard layer exists', () {
      final cut = _cut(layers: [_layer('anim-a', LayerKind.animation)]);

      expect(storyboardLayerForCut(cut), isNull);
    });

    test(
      'returns the ordinary Layer(kind: storyboard) when exactly one exists',
      () {
        final storyboardLayer = _layer('storyboard-a', LayerKind.storyboard);
        final cut = _cut(
          layers: [
            _layer('anim-below', LayerKind.animation),
            storyboardLayer,
            _layer('anim-above', LayerKind.animation),
          ],
        );

        expect(identical(storyboardLayerForCut(cut), storyboardLayer), isTrue);
      },
    );

    test('finds storyboard layer regardless of layer name', () {
      final storyboardLayer = _layer(
        'misleading-storyboard-kind',
        LayerKind.storyboard,
        name: 'Animation',
      );
      final cut = _cut(
        layers: [
          _layer(
            'misleading-animation-kind',
            LayerKind.animation,
            name: 'Storyboard',
          ),
          storyboardLayer,
        ],
      );

      expect(storyboardLayerForCut(cut)?.id, storyboardLayer.id);
    });

    test('finds storyboard layer regardless of raw layer position', () {
      final first = _layer('first-animation', LayerKind.animation);
      final storyboardLayer = _layer('middle-storyboard', LayerKind.storyboard);
      final last = _layer('last-animation', LayerKind.animation);
      final cut = _cut(layers: [first, storyboardLayer, last]);

      expect(storyboardLayerForCut(cut)?.id, storyboardLayer.id);
    });

    test('throws StateError when a cut has multiple storyboard layers', () {
      final cut = _cut(
        layers: [
          _layer('storyboard-a', LayerKind.storyboard),
          _layer('animation-a', LayerKind.animation),
          _layer('storyboard-b', LayerKind.storyboard),
        ],
      );

      expect(() => storyboardLayerForCut(cut), throwsStateError);
    });

    test('does not mutate the Cut', () {
      final cut = _cut(
        layers: [
          _layer('animation-a', LayerKind.animation),
          _layer('storyboard-a', LayerKind.storyboard),
        ],
      );
      final beforeJson = cut.toJson().toString();

      storyboardLayerForCut(cut);

      expect(cut.toJson().toString(), beforeJson);
    });
  });
}

Cut _cut({required List<Layer> layers}) {
  return Cut(
    id: const CutId('cut-a'),
    name: 'Cut A',
    duration: 24,
    canvasSize: const CanvasSize(width: 1280, height: 720),
    layers: layers,
  );
}

Layer _layer(String id, LayerKind kind, {String? name}) {
  return Layer(
    id: LayerId(id),
    name: name ?? id,
    kind: kind,
    frames: [Frame(id: FrameId('frame-$id'), duration: 1, strokes: const [])],
  );
}
