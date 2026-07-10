import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_id.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/services/canvas_selection.dart';

void main() {
  BrushDab dab(double x, double y) => BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: 0xFF000000,
    size: 4,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: 0,
  );

  BrushPaintCommand command(String id, List<BrushDab> dabs) =>
      BrushPaintCommand(
        id: BrushPaintCommandId(id),
        sequenceNumber: 1,
        kind: BrushPaintCommandKind.paintStroke,
        sourceDabs: dabs,
      );

  group('CanvasSelectionShape', () {
    test('rect contains its interior, not its outside', () {
      final shape = CanvasSelectionShape.rect(
        left: 40,
        top: 10,
        right: 10,
        bottom: 30,
      );
      expect(shape.containsPoint(CanvasPoint(x: 20, y: 20)), isTrue);
      expect(shape.containsPoint(CanvasPoint(x: 5, y: 20)), isFalse);
      expect(shape.containsPoint(CanvasPoint(x: 20, y: 35)), isFalse);
    });

    test('a concave lasso polygon selects by even-odd containment', () {
      // A "U" shape: the notch between the arms is OUTSIDE.
      final shape = CanvasSelectionShape([
        CanvasPoint(x: 0, y: 0),
        CanvasPoint(x: 30, y: 0),
        CanvasPoint(x: 30, y: 30),
        CanvasPoint(x: 20, y: 30),
        CanvasPoint(x: 20, y: 10),
        CanvasPoint(x: 10, y: 10),
        CanvasPoint(x: 10, y: 30),
        CanvasPoint(x: 0, y: 30),
      ]);
      expect(shape.containsPoint(CanvasPoint(x: 5, y: 20)), isTrue);
      expect(shape.containsPoint(CanvasPoint(x: 25, y: 20)), isTrue);
      expect(
        shape.containsPoint(CanvasPoint(x: 15, y: 20)),
        isFalse,
        reason: 'the notch is outside the U',
      );
    });

    test('translated moves every vertex', () {
      final shape = CanvasSelectionShape.rect(
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
      ).translated(dx: 5, dy: -2);
      expect(shape.containsPoint(CanvasPoint(x: 14, y: 7)), isTrue);
      expect(shape.containsPoint(CanvasPoint(x: 2, y: 2)), isFalse);
    });
  });

  group('selectCommandIdsInShape', () {
    final shape = CanvasSelectionShape.rect(
      left: 0,
      top: 0,
      right: 100,
      bottom: 100,
    );

    test('a command joins at >= 60% of dab centers inside', () {
      final selected = selectCommandIdsInShape(
        commands: [
          // 2/3 inside = 66% -> in.
          command('mostly-in', [dab(10, 10), dab(20, 20), dab(200, 200)]),
          // 1/3 inside = 33% -> out.
          command('mostly-out', [dab(10, 10), dab(200, 20), dab(200, 200)]),
          // Exactly 60% (3/5) -> in (inclusive threshold).
          command('exactly-60', [
            dab(1, 1),
            dab(2, 2),
            dab(3, 3),
            dab(200, 1),
            dab(200, 2),
          ]),
          command('empty', const []),
        ],
        shape: shape,
      );

      expect(selected, {
        const BrushPaintCommandId('mostly-in'),
        const BrushPaintCommandId('exactly-60'),
      });
    });
  });

  test('translateDabs moves centers and nothing else', () {
    final original = dab(10, 20).copyWith(sequence: 7);
    final moved = translateDabs([original], dx: 3, dy: -4).single;
    expect(moved.center, CanvasPoint(x: 13, y: 16));
    expect(moved.sequence, 7);
    expect(moved.size, original.size);
    expect(moved.color, original.color);
  });
}
