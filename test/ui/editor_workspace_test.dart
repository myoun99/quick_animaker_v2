import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_preset_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_settings_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/tools_panel.dart';
import 'package:quick_animaker_v2/src/ui/camera/camera_panel.dart';
import 'package:quick_animaker_v2/src/ui/editor_canvas_area.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

const _canvasTabKey = ValueKey<String>('panel-tab-canvas');
const _brushesTabKey = ValueKey<String>('panel-tab-brushes');
const _brushSettingsTabKey = ValueKey<String>('panel-tab-brush-settings');
const _cameraTabKey = ValueKey<String>('panel-tab-camera');
const _timelineTabKey = ValueKey<String>('timeline-mode-timeline-button');
const _storyboardTabKey = ValueKey<String>('timeline-mode-storyboard-button');
const _rightDropRailKey = ValueKey<String>('editor-dock-drop-rail-right');

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  await tester.pumpAndSettle();
}

/// Drags a tab to a target (drags start immediately once the pointer
/// clears the touch slop). The target is a CLOSURE evaluated after the
/// lift, because lifting reveals the section split zones and shifts the
/// strips down.
Future<void> _dragTab(
  WidgetTester tester,
  Finder tab,
  Offset Function() target,
) async {
  final gesture = await tester.startGesture(tester.getCenter(tab));
  await tester.pump(const Duration(milliseconds: 20));
  // Clear the touch slop so the immediate drag wins the gesture arena.
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  final destination = target();
  await gesture.moveTo(destination + const Offset(0, -5));
  await tester.pump();
  await gesture.moveTo(destination);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('EditorWorkspace tool bars', () {
    testWidgets('vertical tool bars flank BOTH workspace edges', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(find.byType(ToolsPanel), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey<String>('tool-brush-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tool-brush-button-right')),
        findsOneWidget,
      );
    });

    testWidgets('both bars share the tool state', (tester) async {
      await _pumpHome(tester);

      // Choose the eraser on the RIGHT bar; both bars reflect it.
      await tester.tap(
        find.byKey(const ValueKey<String>('tool-eraser-button-right')),
      );
      await tester.pumpAndSettle();

      for (final panel in tester.widgetList<ToolsPanel>(
        find.byType(ToolsPanel),
      )) {
        expect(panel.tool.name, 'eraser');
      }
    });
  });

  group('EditorWorkspace left dock tabs', () {
    testWidgets('shows the three palette tabs with Brushes active', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(find.byKey(_brushesTabKey), findsOneWidget);
      expect(find.byKey(_brushSettingsTabKey), findsOneWidget);
      expect(find.byKey(_cameraTabKey), findsOneWidget);

      // Only the active tab's panel is built.
      expect(find.byType(BrushPresetPanel), findsOneWidget);
      expect(find.byType(BrushSettingsPanel), findsNothing);
      expect(find.byType(CameraPanel), findsNothing);
    });

    testWidgets('switching tabs swaps the visible panel', (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(_cameraTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(CameraPanel), findsOneWidget);
      expect(find.byType(BrushPresetPanel), findsNothing);

      await tester.tap(find.byKey(_brushSettingsTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(BrushSettingsPanel), findsOneWidget);
      expect(find.byType(CameraPanel), findsNothing);
    });
  });

  group('EditorWorkspace canvas panel', () {
    testWidgets('the canvas is a locked tab in the center dock', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(find.byKey(_canvasTabKey), findsOneWidget);
      expect(find.byType(EditorCanvasArea), findsOneWidget);

      // Locked by default: a drag toward the bottom strip does nothing.
      await _dragTab(
        tester,
        find.byKey(_canvasTabKey),
        () =>
            tester.getCenter(find.byKey(_storyboardTabKey)) +
            const Offset(150, 0),
      );

      expect(find.byType(EditorCanvasArea), findsOneWidget);
      expect(find.byType(TimelinePanel), findsOneWidget);
    });

    testWidgets('unlocking the canvas lets it re-dock', (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey<String>('panel-lock-canvas')));
      await tester.pumpAndSettle();

      await _dragTab(
        tester,
        find.byKey(_canvasTabKey),
        () =>
            tester.getCenter(find.byKey(_storyboardTabKey)) +
            const Offset(150, 0),
      );

      // The canvas now lives in the bottom dock as its active tab; the
      // center dock is an empty region.
      expect(find.byType(EditorCanvasArea), findsOneWidget);
      expect(find.byType(TimelinePanel), findsNothing);
      expect(find.byKey(_canvasTabKey), findsOneWidget);
    });
  });

  group('EditorWorkspace tab drag-docking', () {
    testWidgets('camera tab re-docks into the bottom strip and back', (
      tester,
    ) async {
      await _pumpHome(tester);

      // Drop on the bottom strip's tail (right of the storyboard tab).
      await _dragTab(
        tester,
        find.byKey(_cameraTabKey),
        () =>
            tester.getCenter(find.byKey(_storyboardTabKey)) +
            const Offset(150, 0),
      );

      // The camera panel now renders in the bottom region as its active
      // tab; the left dock keeps Brushes active.
      expect(find.byType(CameraPanel), findsOneWidget);
      expect(find.byType(TimelinePanel), findsNothing);
      expect(find.byType(BrushPresetPanel), findsOneWidget);

      // Timeline is still reachable in the bottom group.
      await tester.tap(find.byKey(_timelineTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(TimelinePanel), findsOneWidget);
      expect(find.byType(CameraPanel), findsNothing);

      // Drag the camera tab back to the left strip (tail after Settings).
      await _dragTab(
        tester,
        find.byKey(_cameraTabKey),
        () =>
            tester.getCenter(find.byKey(_brushSettingsTabKey)) +
            const Offset(60, 0),
      );

      expect(find.byType(CameraPanel), findsOneWidget);
      expect(find.byType(TimelinePanel), findsOneWidget);
    });

    testWidgets('a tab dropped on a split zone stacks a second panel', (
      tester,
    ) async {
      await _pumpHome(tester);

      // Lift the camera tab; the split zones appear while it is in
      // flight. Drop it below the left dock's only section.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_cameraTabKey)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      final splitZone = find.byKey(
        const ValueKey<String>('dock-section-split-left-1'),
      );
      expect(splitZone, findsOneWidget);
      await gesture.moveTo(tester.getCenter(splitZone));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Panel below panel: Brushes AND Camera visible at once.
      expect(find.byType(BrushPresetPanel), findsOneWidget);
      expect(find.byType(CameraPanel), findsOneWidget);
    });

    testWidgets('frame-axis tabs may dock into the side dock', (tester) async {
      await _pumpHome(tester);

      // Timeline into the left strip: allowed — the shell hosts it at its
      // minimum content size inside scrollers.
      await _dragTab(
        tester,
        find.byKey(_timelineTabKey),
        () => tester.getCenter(find.byKey(_cameraTabKey)) + const Offset(60, 0),
      );

      // Timeline renders in the side dock while the bottom region falls
      // back to the storyboard.
      expect(find.byType(TimelinePanel), findsOneWidget);
      expect(find.byType(StoryboardPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty right dock reveals a drop rail during a drag', (
      tester,
    ) async {
      await _pumpHome(tester);
      expect(find.byKey(_rightDropRailKey), findsNothing);

      // Lift the camera tab: the collapsed right dock shows its rail.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_cameraTabKey)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(find.byKey(_rightDropRailKey), findsOneWidget);

      // Dropping there docks the camera panel on the right.
      await gesture.moveTo(tester.getCenter(find.byKey(_rightDropRailKey)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(_rightDropRailKey), findsNothing);
      expect(find.byType(CameraPanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('editor-panel-dock-right')),
        findsOneWidget,
      );
    });

    testWidgets('left strip tabs can be drag-reordered', (tester) async {
      await _pumpHome(tester);

      // Drop Brushes on the right half of the Camera tab: order becomes
      // Settings, Camera, Brushes.
      await _dragTab(
        tester,
        find.byKey(_brushesTabKey),
        () => Offset(
          tester.getTopRight(find.byKey(_cameraTabKey)).dx - 3,
          tester.getCenter(find.byKey(_cameraTabKey)).dy,
        ),
      );

      expect(
        tester.getCenter(find.byKey(_brushesTabKey)).dx,
        greaterThan(tester.getCenter(find.byKey(_cameraTabKey)).dx),
      );
      // Selection is untouched by reordering.
      expect(find.byType(BrushPresetPanel), findsOneWidget);
    });
  });

  group('EditorWorkspace bottom tabs', () {
    testWidgets('keeps the legacy timeline/storyboard toggle keys working', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(find.byType(TimelinePanel), findsOneWidget);
      expect(find.byType(StoryboardPanel), findsNothing);

      await tester.tap(find.byKey(_storyboardTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(StoryboardPanel), findsOneWidget);
      expect(find.byType(TimelinePanel), findsNothing);

      await tester.tap(find.byKey(_timelineTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(TimelinePanel), findsOneWidget);
    });
  });
}
