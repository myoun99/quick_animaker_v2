import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/color/color_wheel_panel.dart';

void main() {
  group('ColorWheelGeometry', () {
    final geometry = ColorWheelGeometry(const Size(200, 200));

    test('ring and square regions resolve by position', () {
      expect(geometry.outerRadius, 100);
      expect(
        geometry.regionAt(const Offset(100, 100)),
        ColorWheelRegion.svSquare,
      );
      expect(
        geometry.regionAt(const Offset(191, 100)),
        ColorWheelRegion.hueRing,
      );
      expect(geometry.regionAt(const Offset(2, 2)), ColorWheelRegion.none);
    });

    test('hue runs clockwise from 3 o\'clock', () {
      expect(geometry.hueAt(const Offset(191, 100)), 0);
      expect(geometry.hueAt(const Offset(100, 191)), 90);
      expect(geometry.hueAt(const Offset(9, 100)), 180);
      expect(geometry.hueAt(const Offset(100, 9)), 270);
    });

    test('saturation grows rightward, value upward, clamped to the square', () {
      final rect = geometry.squareRect;
      final (s1, v1) = geometry.svAt(rect.topRight);
      expect(s1, 1);
      expect(v1, 1);
      final (s0, v0) = geometry.svAt(rect.bottomLeft);
      expect(s0, 0);
      expect(v0, 0);
      final (sClamped, vClamped) = geometry.svAt(
        rect.bottomRight + const Offset(50, 50),
      );
      expect(sClamped, 1);
      expect(vClamped, 0);
    });
  });

  group('ColorWheelPanel', () {
    Future<Rect> pumpPanel(
      WidgetTester tester, {
      required int color,
      required List<int> changes,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 300,
                child: ColorWheelPanel(
                  color: color,
                  onColorChanged: changes.add,
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getRect(find.byKey(const ValueKey<String>('color-wheel')));
    }

    testWidgets('tapping the ring spins the hue (red → green stays pure)', (
      tester,
    ) async {
      final changes = <int>[];
      final wheelRect = await pumpPanel(
        tester,
        color: 0xFFFF0000,
        changes: changes,
      );

      final geometry = ColorWheelGeometry(wheelRect.size);
      // 120° on the ring's center radius = pure green for s=1, v=1.
      final ringRadius = geometry.innerRadius + geometry.ringWidth / 2;
      final local =
          geometry.center +
          Offset.fromDirection(120 * 3.14159265 / 180, ringRadius);
      await tester.tapAt(wheelRect.topLeft + local);
      await tester.pump();

      expect(changes, isNotEmpty);
      expect(changes.last, 0xFF00FF00);
    });

    testWidgets('tapping the square picks saturation/value (bottom-left = '
        'black) and the hex label follows', (tester) async {
      final changes = <int>[];
      final wheelRect = await pumpPanel(
        tester,
        color: 0xFFFF0000,
        changes: changes,
      );

      final rect = ColorWheelGeometry(wheelRect.size).squareRect;
      // Start inside the square (locks the region), then drag PAST the
      // bottom-left corner — the mapping clamps to exactly s=0, v=0.
      final gesture = await tester.startGesture(
        wheelRect.topLeft + rect.center,
      );
      await gesture.moveTo(
        wheelRect.topLeft + rect.bottomLeft + const Offset(-30, 30),
      );
      await gesture.up();
      await tester.pump();

      expect(changes, isNotEmpty);
      expect(changes.last, 0xFF000000);
      expect(find.text('#000000'), findsOneWidget);
    });
  });
}
