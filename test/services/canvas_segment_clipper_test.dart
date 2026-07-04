import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/services/canvas_segment_clipper.dart';

void main() {
  const clipper = CanvasSegmentClipper();
  const size = CanvasSize(width: 100, height: 80);

  test('inside to outside fast movement clips to canvas edge', () {
    final segment = clipper.clip(
      previous: CanvasPoint(x: 50, y: 40),
      current: CanvasPoint(x: 150, y: 40),
      canvasSize: size,
    );

    expect(segment, isNotNull);
    expect(segment!.start.x, 50);
    expect(segment.end.x, 100);
    expect(segment.startsNewVisibleSegment, isFalse);
  });

  test('outside to inside fast movement starts at canvas edge', () {
    final segment = clipper.clip(
      previous: CanvasPoint(x: -50, y: 40),
      current: CanvasPoint(x: 50, y: 40),
      canvasSize: size,
    );

    expect(segment, isNotNull);
    expect(segment!.start.x, 0);
    expect(segment.end.x, 50);
    expect(segment.startsNewVisibleSegment, isTrue);
  });

  test(
    'outside to outside crossing canvas produces in-canvas segment only',
    () {
      final segment = clipper.clip(
        previous: CanvasPoint(x: -50, y: 40),
        current: CanvasPoint(x: 150, y: 40),
        canvasSize: size,
      );

      expect(segment, isNotNull);
      expect(segment!.start.x, 0);
      expect(segment.end.x, 100);
      expect(segment.startsNewVisibleSegment, isTrue);
    },
  );

  test('outside to outside without crossing produces no segment', () {
    final segment = clipper.clip(
      previous: CanvasPoint(x: -50, y: -40),
      current: CanvasPoint(x: -10, y: -20),
      canvasSize: size,
    );

    expect(segment, isNull);
  });
}
