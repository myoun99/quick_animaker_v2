import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';

void main() {
  group('LayerKind', () {
    test('serializes stable strings', () {
      expect(LayerKind.animation.toJson(), 'animation');
      expect(LayerKind.storyboard.toJson(), 'storyboard');
    });

    test('deserializes stable strings', () {
      expect(LayerKind.fromJson('animation'), LayerKind.animation);
      expect(LayerKind.fromJson('storyboard'), LayerKind.storyboard);
    });

    test('throws for invalid JSON values', () {
      expect(() => LayerKind.fromJson('panel'), throwsArgumentError);
      expect(() => LayerKind.fromJson(0), throwsArgumentError);
      expect(() => LayerKind.fromJson(null), throwsArgumentError);
    });
  });
}
