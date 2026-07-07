import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_preset_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_settings_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/tools_panel.dart';
import 'package:quick_animaker_v2/src/ui/camera/camera_panel.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

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

/// Long-presses a tab to lift it, then drags it to [target].
Future<void> _dragTab(WidgetTester tester, Finder tab, Offset target) async {
  final gesture = await tester.startGesture(tester.getCenter(tab));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.moveTo(target + const Offset(0, -10));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('EditorWorkspace tool bar', () {
    testWidgets('the vertical tool bar is always present', (tester) async {
      await _pumpHome(tester);

      expect(find.byType(ToolsPanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('tool-brush-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tool-eraser-button')),
        findsOneWidget,
      );
    });

    testWidgets('tool choice survives dock tab switches', (tester) async {
      await _pumpHome(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('tool-eraser-button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_cameraTabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_brushesTabKey));
      await tester.pumpAndSettle();

      final toolsPanel = tester.widget<ToolsPanel>(find.byType(ToolsPanel));
      expect(toolsPanel.tool.name, 'eraser');
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

  group('EditorWorkspace tab drag-docking', () {
    testWidgets('camera tab re-docks into the bottom strip and back', (
      tester,
    ) async {
      await _pumpHome(tester);

      // Drop on the bottom strip's tail (right of the storyboard tab).
      final bottomTail =
          tester.getCenter(find.byKey(_storyboardTabKey)) +
          const Offset(150, 0);
      await _dragTab(tester, find.byKey(_cameraTabKey), bottomTail);

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
      final leftTail =
          tester.getCenter(find.byKey(_brushSettingsTabKey)) +
          const Offset(60, 0);
      await _dragTab(tester, find.byKey(_cameraTabKey), leftTail);

      expect(find.byType(CameraPanel), findsOneWidget);
      expect(find.byType(TimelinePanel), findsOneWidget);
    });

    testWidgets('frame-axis tabs may dock into the side dock', (tester) async {
      await _pumpHome(tester);

      // Timeline into the left strip: allowed — the shell hosts it at its
      // minimum content width inside a horizontal scroller.
      final leftTail =
          tester.getCenter(find.byKey(_cameraTabKey)) + const Offset(60, 0);
      await _dragTab(tester, find.byKey(_timelineTabKey), leftTail);

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
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(10, 0));
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
      final cameraRightHalf = Offset(
        tester.getTopRight(find.byKey(_cameraTabKey)).dx - 3,
        tester.getCenter(find.byKey(_cameraTabKey)).dy,
      );
      await _dragTab(tester, find.byKey(_brushesTabKey), cameraRightHalf);

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
