import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';

void main() {
  group('Layer.kind', () {
    test('defaults to animation kind', () {
      expect(_layer().kind, LayerKind.animation);
    });

    test('copyWith changes kind and preserves other fields', () {
      final layer = _layer();

      final storyboardLayer = layer.copyWith(kind: LayerKind.storyboard);

      expect(storyboardLayer.kind, LayerKind.storyboard);
      expect(storyboardLayer.id, layer.id);
      expect(storyboardLayer.name, layer.name);
      expect(storyboardLayer.frames, layer.frames);
      expect(storyboardLayer.timeline, layer.timeline);
      expect(storyboardLayer.marks, layer.marks);
      expect(storyboardLayer.isVisible, layer.isVisible);
      expect(storyboardLayer.opacity, layer.opacity);
    });

    test('equality and hashCode include kind', () {
      final animationLayer = _layer();
      final storyboardLayer = _layer(kind: LayerKind.storyboard);

      expect(storyboardLayer, isNot(animationLayer));
      expect(storyboardLayer.hashCode, isNot(animationLayer.hashCode));
      expect(
        storyboardLayer,
        animationLayer.copyWith(kind: LayerKind.storyboard),
      );
    });

    test('JSON round-trip preserves kind', () {
      final layer = _layer(kind: LayerKind.storyboard);

      final restoredLayer = Layer.fromJson(layer.toJson());

      expect(restoredLayer, layer);
      expect(restoredLayer.kind, LayerKind.storyboard);
      expect(layer.toJson()['kind'], 'storyboard');
    });

    test('old JSON without kind defaults to animation', () {
      final json = _layer(kind: LayerKind.storyboard).toJson()..remove('kind');

      final restoredLayer = Layer.fromJson(json);

      expect(restoredLayer.kind, LayerKind.animation);
    });

    test('fromJson throws for invalid kind JSON', () {
      final json = _layer().toJson()..['kind'] = 'panel';

      expect(() => Layer.fromJson(json), throwsArgumentError);
    });
  });
}

Layer _layer({LayerKind kind = LayerKind.animation}) {
  return Layer(
    id: const LayerId('layer-1'),
    name: 'Line',
    frames: [
      Frame(id: const FrameId('frame-1'), duration: 2, strokes: const []),
    ],
    isVisible: false,
    opacity: 0.5,
    kind: kind,
  );
}
