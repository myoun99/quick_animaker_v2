import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_display_adapter.dart';

void main() {
  group('horizontalLayerDisplayOrder', () {
    test('empty list returns an empty defensive list', () {
      final layers = <Layer>[];

      final displayLayers = horizontalLayerDisplayOrder(layers);

      expect(displayLayers, isEmpty);
      expect(identical(displayLayers, layers), isFalse);
    });

    test('one layer returns one layer with the same object reference', () {
      final layer = _layer(id: 'layer-a', name: 'A');
      final layers = [layer];

      final displayLayers = horizontalLayerDisplayOrder(layers);

      expect(displayLayers, hasLength(1));
      expect(identical(displayLayers.single, layer), isTrue);
    });

    test('multiple layers preserve current order', () {
      final layerB = _layer(id: 'layer-b', name: 'B');
      final layerA = _layer(id: 'layer-a', name: 'A');
      final layerC = _layer(id: 'layer-c', name: 'C');

      final displayLayers = horizontalLayerDisplayOrder([
        layerB,
        layerA,
        layerC,
      ]);

      expect(displayLayers, [same(layerB), same(layerA), same(layerC)]);
    });

    test('returned list is not the same list instance as input', () {
      final layers = [_layer(id: 'layer-a', name: 'A')];

      final displayLayers = horizontalLayerDisplayOrder(layers);

      expect(identical(displayLayers, layers), isFalse);
    });

    test('returned list contains the same Layer object references', () {
      final layerA = _layer(id: 'layer-a', name: 'A');
      final layerB = _layer(id: 'layer-b', name: 'B');
      final layers = [layerA, layerB];

      final displayLayers = horizontalLayerDisplayOrder(layers);

      expect(identical(displayLayers[0], layerA), isTrue);
      expect(identical(displayLayers[1], layerB), isTrue);
    });

    test('mutating the returned list does not mutate the original input list', () {
      final layerA = _layer(id: 'layer-a', name: 'A');
      final layerB = _layer(id: 'layer-b', name: 'B');
      final layers = [layerA, layerB];

      final displayLayers = horizontalLayerDisplayOrder(layers);
      displayLayers.removeAt(0);

      expect(layers, [same(layerA), same(layerB)]);
      expect(displayLayers, [same(layerB)]);
    });

    test('animation and storyboard layers are both preserved', () {
      final animation = _layer(
        id: 'layer-animation',
        name: 'Animation',
      );
      final storyboard = _layer(
        id: 'layer-storyboard',
        name: 'Storyboard',
        kind: LayerKind.storyboard,
      );

      final displayLayers = horizontalLayerDisplayOrder([
        animation,
        storyboard,
      ]);

      expect(displayLayers, [same(animation), same(storyboard)]);
      expect(displayLayers.map((layer) => layer.kind), [
        LayerKind.animation,
        LayerKind.storyboard,
      ]);
    });

    test('does not sort by name', () {
      final zLayer = _layer(id: 'layer-z', name: 'Z');
      final aLayer = _layer(id: 'layer-a', name: 'A');
      final mLayer = _layer(id: 'layer-m', name: 'M');

      final displayLayers = horizontalLayerDisplayOrder([
        zLayer,
        aLayer,
        mLayer,
      ]);

      expect(displayLayers.map((layer) => layer.name), ['Z', 'A', 'M']);
      expect(displayLayers, [same(zLayer), same(aLayer), same(mLayer)]);
    });

    test('does not sort by LayerKind', () {
      final storyboardA = _layer(
        id: 'layer-storyboard-a',
        name: 'Storyboard A',
        kind: LayerKind.storyboard,
      );
      final animation = _layer(
        id: 'layer-animation',
        name: 'Animation',
      );
      final storyboardB = _layer(
        id: 'layer-storyboard-b',
        name: 'Storyboard B',
        kind: LayerKind.storyboard,
      );

      final displayLayers = horizontalLayerDisplayOrder([
        storyboardA,
        animation,
        storyboardB,
      ]);

      expect(displayLayers.map((layer) => layer.kind), [
        LayerKind.storyboard,
        LayerKind.animation,
        LayerKind.storyboard,
      ]);
      expect(displayLayers, [
        same(storyboardA),
        same(animation),
        same(storyboardB),
      ]);
    });

    test('existing B above A order stays B above A', () {
      final layerB = _layer(id: 'layer-b', name: 'B');
      final layerA = _layer(id: 'layer-a', name: 'A');

      final displayLayers = horizontalLayerDisplayOrder([layerB, layerA]);

      expect(displayLayers.map((layer) => layer.name), ['B', 'A']);
      expect(displayLayers, [same(layerB), same(layerA)]);
    });
  });
}

Layer _layer({
  required String id,
  required String name,
  LayerKind kind = LayerKind.animation,
}) {
  return Layer(id: LayerId(id), name: name, frames: const [], kind: kind);
}
