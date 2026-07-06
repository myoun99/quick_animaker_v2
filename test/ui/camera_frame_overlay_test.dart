import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/camera_pose.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/ui/camera/camera_frame_overlay.dart';

void main() {
  const frameSize = CanvasSize(width: 1920, height: 1080);

  CameraFramePainter painter({
    required CameraPose pose,
    CanvasViewport? viewport,
  }) {
    return CameraFramePainter(
      pose: pose,
      cameraFrameSize: frameSize,
      viewport: viewport ?? CanvasViewport(),
      dimOpacity: 0.5,
      outlineColor: CameraFrameOverlay.outlineColor,
    );
  }

  group('CameraFramePainter.frameCornersInViewport', () {
    test('zoom 1 no rotation maps the frame 1:1 around the center', () {
      final corners = painter(
        pose: CameraPose(center: CanvasPoint(x: 1000, y: 600)),
      ).frameCornersInViewport();

      expect(corners[0], const Offset(1000 - 960, 600 - 540));
      expect(corners[1], const Offset(1000 + 960, 600 - 540));
      expect(corners[2], const Offset(1000 + 960, 600 + 540));
      expect(corners[3], const Offset(1000 - 960, 600 + 540));
    });

    test('camera zoom 2 halves the view rect on canvas', () {
      final corners = painter(
        pose: CameraPose(center: CanvasPoint(x: 1000, y: 600), zoom: 2),
      ).frameCornersInViewport();

      expect(corners[0], const Offset(1000 - 480, 600 - 270));
      expect(corners[2], const Offset(1000 + 480, 600 + 270));
    });

    test('viewport zoom and pan transform canvas points to screen', () {
      final corners = painter(
        pose: CameraPose(center: CanvasPoint(x: 1000, y: 600)),
        viewport: CanvasViewport(zoom: 0.5, panX: 10, panY: 20),
      ).frameCornersInViewport();

      expect(
        corners[0],
        const Offset((1000 - 960) * 0.5 + 10, (600 - 540) * 0.5 + 20),
      );
      expect(
        corners[2],
        const Offset((1000 + 960) * 0.5 + 10, (600 + 540) * 0.5 + 20),
      );
    });

    test('90 degrees rotates the frame clockwise around the center', () {
      final corners = painter(
        pose: CameraPose(
          center: CanvasPoint(x: 1000, y: 600),
          rotationDegrees: 90,
        ),
      ).frameCornersInViewport();

      // Top-left corner offset (-960, -540) rotated 90° clockwise in y-down
      // screen space becomes (540, -960).
      expect(corners[0].dx, closeTo(1000 + 540, 1e-6));
      expect(corners[0].dy, closeTo(600 - 960, 1e-6));
    });
  });

  test('rotate knob sits above the top edge midpoint', () {
    final knob = cameraRotateKnobInViewport(
      pose: CameraPose(center: CanvasPoint(x: 1000, y: 600)),
      cameraFrameSize: frameSize,
      viewport: CanvasViewport(zoom: 0.5),
    );

    // Top edge midpoint (500, 30), sticking 24 screen px away from the
    // center (500, 300).
    expect(knob, const Offset(500, 6));
  });

  group('CameraFrameOverlay interaction', () {
    // Camera center (1000, 600) at viewport zoom 0.5 = screen (500, 300);
    // top-left corner handle (20, 30); rotate knob (500, 6).
    Future<List<CameraPose>> pumpInteractiveOverlay(WidgetTester tester) async {
      final committed = <CameraPose>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraFrameOverlay(
              pose: CameraPose(center: CanvasPoint(x: 1000, y: 600)),
              cameraFrameSize: frameSize,
              viewport: CanvasViewport(zoom: 0.5),
              dimOpacity: 0.5,
              interactive: true,
              onPoseCommitted: committed.add,
            ),
          ),
        ),
      );
      return committed;
    }

    Offset overlayOrigin(WidgetTester tester) => tester.getTopLeft(
      find.byKey(const ValueKey<String>('camera-frame-overlay-gesture')),
    );

    testWidgets('dragging moves the camera and commits once on release', (
      tester,
    ) async {
      final committed = await pumpInteractiveOverlay(tester);

      await tester.drag(
        find.byKey(const ValueKey<String>('camera-frame-overlay-gesture')),
        const Offset(50, -30),
      );
      await tester.pump();

      // Screen delta divided by the viewport zoom 0.5 = canvas delta.
      expect(committed, hasLength(1));
      expect(committed.single.center.x, closeTo(1000 + 100, 1e-6));
      expect(committed.single.center.y, closeTo(600 - 60, 1e-6));
    });

    testWidgets('dragging a corner handle scales the zoom around the '
        'center', (tester) async {
      final committed = await pumpInteractiveOverlay(tester);
      final origin = overlayOrigin(tester);

      // From the top-left corner to half its distance from the center:
      // the view rect halves, so the zoom doubles.
      final gesture = await tester.startGesture(origin + const Offset(20, 30));
      await gesture.moveTo(origin + const Offset(260, 165));
      await gesture.up();
      await tester.pump();

      expect(committed, hasLength(1));
      expect(committed.single.zoom, closeTo(2, 1e-6));
      expect(committed.single.center.x, closeTo(1000, 1e-6));
      expect(committed.single.center.y, closeTo(600, 1e-6));
      expect(committed.single.rotationDegrees, closeTo(0, 1e-6));
    });

    testWidgets('dragging the rotate knob spins the camera around the '
        'center', (tester) async {
      final committed = await pumpInteractiveOverlay(tester);
      final origin = overlayOrigin(tester);

      // The knob starts straight above the center (-90°); dragging to the
      // center's right (0°) is a 90° clockwise turn.
      final gesture = await tester.startGesture(origin + const Offset(500, 6));
      await gesture.moveTo(origin + const Offset(770, 300));
      await gesture.up();
      await tester.pump();

      expect(committed, hasLength(1));
      expect(committed.single.rotationDegrees, closeTo(90, 1e-6));
      expect(committed.single.zoom, closeTo(1, 1e-6));
      expect(committed.single.center.x, closeTo(1000, 1e-6));
      expect(committed.single.center.y, closeTo(600, 1e-6));
    });

    testWidgets('non-interactive overlay ignores pointers', (tester) async {
      var tappedBelow = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => tappedBelow = true,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
                Positioned.fill(
                  child: CameraFrameOverlay(
                    pose: CameraPose(center: CanvasPoint(x: 100, y: 100)),
                    cameraFrameSize: frameSize,
                    viewport: CanvasViewport(),
                    dimOpacity: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('camera-frame-overlay')),
        warnIfMissed: false,
      );
      expect(tappedBelow, isTrue);
    });
  });
}
