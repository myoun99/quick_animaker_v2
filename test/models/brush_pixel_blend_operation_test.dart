import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_pixel_blend_operation.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';

void main() {
  final before = RgbaColor(r: 0, g: 0, b: 0, a: 0);
  final after = RgbaColor(r: 255, g: 0, b: 0, a: 255);
  final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);

  BrushPixelBlendOperation operation() =>
      BrushPixelBlendOperation(x: 1, y: 2, before: before, after: after);

  group('BrushPixelBlendOperation', () {
    test('creates with valid values', () {
      final value = operation();
      expect(value.x, 1);
      expect(value.y, 2);
      expect(value.before, before);
      expect(value.after, after);
    });

    test('rejects negative x', () {
      expect(
        () =>
            BrushPixelBlendOperation(x: -1, y: 0, before: before, after: after),
        throwsArgumentError,
      );
    });

    test('rejects negative y', () {
      expect(
        () =>
            BrushPixelBlendOperation(x: 0, y: -1, before: before, after: after),
        throwsArgumentError,
      );
    });

    test('rejects before equal to after', () {
      expect(
        () =>
            BrushPixelBlendOperation(x: 0, y: 0, before: before, after: before),
        throwsArgumentError,
      );
    });

    test('copyWith updates x', () => expect(operation().copyWith(x: 3).x, 3));

    test('copyWith updates y', () => expect(operation().copyWith(y: 4).y, 4));

    test('copyWith updates before', () {
      expect(operation().copyWith(before: blue).before, blue);
    });

    test('copyWith updates after', () {
      expect(operation().copyWith(after: blue).after, blue);
    });

    test('copyWith rejects no-op before == after', () {
      expect(() => operation().copyWith(after: before), throwsArgumentError);
    });

    test('equality includes all fields', () {
      final value = operation();
      expect(value, operation());
      expect(value, isNot(value.copyWith(x: 9)));
      expect(value, isNot(value.copyWith(y: 9)));
      expect(value, isNot(value.copyWith(before: blue)));
      expect(value, isNot(value.copyWith(after: blue)));
    });

    test('hashCode is value-based', () {
      expect(operation().hashCode, operation().hashCode);
    });

    test('toJson/fromJson round-trips', () {
      final value = operation();
      expect(BrushPixelBlendOperation.fromJson(value.toJson()), value);
    });

    test('toString includes useful data', () {
      final text = operation().toString();
      expect(text, contains('BrushPixelBlendOperation'));
      expect(text, contains('x: 1'));
      expect(text, contains('y: 2'));
      expect(text, contains('before:'));
      expect(text, contains('after:'));
    });
  });
}
