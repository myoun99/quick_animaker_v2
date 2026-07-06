import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/camera_pose.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/ui/camera/camera_toolbar.dart';

void main() {
  Future<void> pumpToolbar(
    WidgetTester tester, {
    bool cameraViewEnabled = false,
    ValueChanged<bool>? onCameraViewChanged,
    bool isCameraLayerActive = false,
    CameraPose? pose,
    bool hasKeyframe = false,
    ValueChanged<CameraPose>? onPoseCommitted,
    VoidCallback? onRemoveKeyframe,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CameraToolbar(
              cameraViewEnabled: cameraViewEnabled,
              onCameraViewChanged: onCameraViewChanged ?? (_) {},
              dimOpacity: 0.5,
              onDimOpacityChanged: (_) {},
              isCameraLayerActive: isCameraLayerActive,
              pose:
                  pose ??
                  CameraPose(center: CanvasPoint(x: 100, y: 100), zoom: 1.5),
              hasKeyframeAtCurrentFrame: hasKeyframe,
              onPoseCommitted: onPoseCommitted ?? (_) {},
              onRemoveKeyframe: onRemoveKeyframe ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('camera view toggle reports the flipped state', (tester) async {
    bool? reported;
    await pumpToolbar(tester, onCameraViewChanged: (value) => reported = value);

    await tester.tap(find.byKey(const ValueKey<String>('camera-view-toggle')));
    expect(reported, isTrue);
  });

  testWidgets('dim slider only shows while the camera view is on', (
    tester,
  ) async {
    await pumpToolbar(tester);
    expect(
      find.byKey(const ValueKey<String>('camera-dim-slider')),
      findsNothing,
    );

    await pumpToolbar(tester, cameraViewEnabled: true);
    expect(
      find.byKey(const ValueKey<String>('camera-dim-slider')),
      findsOneWidget,
    );
  });

  testWidgets('pose controls only show while the camera layer is active', (
    tester,
  ) async {
    await pumpToolbar(tester);
    expect(
      find.byKey(const ValueKey<String>('camera-zoom-field')),
      findsNothing,
    );

    await pumpToolbar(tester, isCameraLayerActive: true);
    expect(
      find.byKey(const ValueKey<String>('camera-zoom-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('camera-rotation-field')),
      findsOneWidget,
    );
  });

  testWidgets('zoom field shows percent and submits as a zoom factor', (
    tester,
  ) async {
    final committed = <CameraPose>[];
    await pumpToolbar(
      tester,
      isCameraLayerActive: true,
      onPoseCommitted: committed.add,
    );

    final zoomField = find.byKey(const ValueKey<String>('camera-zoom-field'));
    expect(tester.widget<TextField>(zoomField).controller!.text, '150');

    await tester.enterText(zoomField, '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(committed, hasLength(1));
    expect(committed.single.zoom, closeTo(2.0, 1e-9));
  });

  testWidgets('rotation field submits degrees', (tester) async {
    final committed = <CameraPose>[];
    await pumpToolbar(
      tester,
      isCameraLayerActive: true,
      onPoseCommitted: committed.add,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('camera-rotation-field')),
      '-45',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(committed, hasLength(1));
    expect(committed.single.rotationDegrees, closeTo(-45, 1e-9));
  });

  testWidgets('set key commits the current pose', (tester) async {
    final committed = <CameraPose>[];
    final pose = CameraPose(center: CanvasPoint(x: 10, y: 20), zoom: 1.25);
    await pumpToolbar(
      tester,
      isCameraLayerActive: true,
      pose: pose,
      onPoseCommitted: committed.add,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('camera-set-key-button')),
    );
    expect(committed, [pose]);
  });

  testWidgets('remove key is disabled without a keyframe at the frame', (
    tester,
  ) async {
    var removed = false;
    await pumpToolbar(
      tester,
      isCameraLayerActive: true,
      hasKeyframe: false,
      onRemoveKeyframe: () => removed = true,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('camera-remove-key-button')),
    );
    expect(removed, isFalse);

    await pumpToolbar(
      tester,
      isCameraLayerActive: true,
      hasKeyframe: true,
      onRemoveKeyframe: () => removed = true,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('camera-remove-key-button')),
    );
    expect(removed, isTrue);
  });
}
