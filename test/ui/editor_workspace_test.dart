import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_preset_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_settings_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/tools_panel.dart';
import 'package:quick_animaker_v2/src/ui/camera/camera_panel.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

const _toolsTabKey = ValueKey<String>('panel-tab-tools');
const _brushesTabKey = ValueKey<String>('panel-tab-brushes');
const _brushSettingsTabKey = ValueKey<String>('panel-tab-brush-settings');
const _cameraTabKey = ValueKey<String>('panel-tab-camera');
const _timelineTabKey = ValueKey<String>('timeline-mode-timeline-button');
const _storyboardTabKey = ValueKey<String>('timeline-mode-storyboard-button');

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  await tester.pumpAndSettle();
}

void main() {
  group('EditorWorkspace left dock tabs', () {
    testWidgets('shows the four palette tabs with Brushes active', (
      tester,
    ) async {
      await _pumpHome(tester);

      expect(find.byKey(_toolsTabKey), findsOneWidget);
      expect(find.byKey(_brushesTabKey), findsOneWidget);
      expect(find.byKey(_brushSettingsTabKey), findsOneWidget);
      expect(find.byKey(_cameraTabKey), findsOneWidget);

      // Only the active tab's panel is built.
      expect(find.byType(BrushPresetPanel), findsOneWidget);
      expect(find.byType(ToolsPanel), findsNothing);
      expect(find.byType(BrushSettingsPanel), findsNothing);
      expect(find.byType(CameraPanel), findsNothing);
    });

    testWidgets('switching tabs swaps the visible panel', (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(_cameraTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(CameraPanel), findsOneWidget);
      expect(find.byType(BrushPresetPanel), findsNothing);

      await tester.tap(find.byKey(_toolsTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(ToolsPanel), findsOneWidget);
      expect(find.byType(CameraPanel), findsNothing);

      await tester.tap(find.byKey(_brushSettingsTabKey));
      await tester.pumpAndSettle();
      expect(find.byType(BrushSettingsPanel), findsOneWidget);
      expect(find.byType(ToolsPanel), findsNothing);
    });

    testWidgets('tool choice survives switching away and back', (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byKey(_toolsTabKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('tool-eraser-button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_brushesTabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_toolsTabKey));
      await tester.pumpAndSettle();

      final toolsPanel = tester.widget<ToolsPanel>(find.byType(ToolsPanel));
      expect(toolsPanel.tool.name, 'eraser');
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
