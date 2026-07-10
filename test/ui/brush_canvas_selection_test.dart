import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_edit_cache_invalidation_sink.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
import 'package:quick_animaker_v2/src/ui/brush/canvas_selection_commands.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_selection_layer.dart';

import '../helpers/brush_canvas_fixture.dart';

/// P9 widget routing: the selection layer mounts only for selection
/// tools, the marquee selects committed strokes, moving/nudging commits
/// ONE undoable rewrite, and click-away/Ctrl+D deselect.
void main() {
  const layerKey = ValueKey<String>('canvas-selection-layer');

  BrushDab dab(double x, double y) => BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: 0xFFFF0000,
    size: 4,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: 0,
  );

  Future<
    ({
      BrushFrameEditingCoordinator coordinator,
      HistoryManager history,
      CanvasSelectionCommands commands,
    })
  >
  pumpSelectionPanel(
    WidgetTester tester, {
    CanvasTool tool = CanvasTool.selectRect,
  }) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
    );
    final history = HistoryManager();
    final commands = CanvasSelectionCommands();
    // One committed stroke around canvas (30..60, 30..60).
    coordinator.commitSourceStroke(
      sourceDabs: [dab(30, 30), dab(45, 45), dab(60, 60)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrushCanvasPanel(
            coordinator: coordinator,
            availableFrameKeys: frameKeys,
            cacheInvalidationSink: BrushEditCacheInvalidationSink(),
            historyManager: history,
            brushToolState: BrushToolState.defaults.copyWith(tool: tool),
            selectionCommands: commands,
          ),
        ),
      ),
    );
    await tester.pump();
    return (coordinator: coordinator, history: history, commands: commands);
  }

  List<BrushDab> strokeDabs(BrushFrameEditingCoordinator coordinator) =>
      coordinator.frameStore
          .getOrCreateFrame(coordinator.activeFrameKey)
          .visibleActivePaintCommands
          .single
          .sourceDabs;

  Future<void> dragOnLayer(WidgetTester tester, Offset from, Offset to) async {
    final origin = tester.getTopLeft(find.byKey(layerKey));
    final gesture = await tester.startGesture(origin + from);
    await tester.pump();
    await gesture.moveTo(origin + to);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('the layer mounts for selection tools only', (tester) async {
    await pumpSelectionPanel(tester, tool: CanvasTool.brush);
    expect(find.byKey(layerKey), findsNothing);

    await pumpSelectionPanel(tester);
    expect(find.byKey(layerKey), findsOneWidget);
    expect(find.byType(CanvasSelectionLayer), findsOneWidget);
  });

  testWidgets('marquee selects, move commits one undoable rewrite', (
    tester,
  ) async {
    final env = await pumpSelectionPanel(tester);

    // Marquee around the whole stroke (viewport is identity: local ==
    // canvas coordinates).
    await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
    expect(env.commands.hasSelection, isTrue);

    // Drag INSIDE the selection: move by (+10, +5).
    await dragOnLayer(tester, const Offset(45, 45), const Offset(55, 50));

    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 40, y: 35));
    expect(env.history.canUndo, isTrue);

    env.history.undo();
    await tester.pump();
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 30, y: 30));

    env.history.redo();
    await tester.pump();
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 40, y: 35));
  });

  testWidgets('a marquee missing the stroke selects nothing movable', (
    tester,
  ) async {
    final env = await pumpSelectionPanel(tester);

    await dragOnLayer(tester, const Offset(100, 100), const Offset(140, 140));
    expect(env.commands.hasSelection, isTrue);

    // Dragging from inside the empty region starts a NEW marquee (nothing
    // selected there), never a move.
    await dragOnLayer(tester, const Offset(110, 110), const Offset(120, 120));
    expect(env.history.canUndo, isFalse);
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 30, y: 30));
  });

  testWidgets('click-away and Ctrl+D deselect; nudges move by one pixel', (
    tester,
  ) async {
    final env = await pumpSelectionPanel(tester);

    await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
    expect(env.commands.hasSelection, isTrue);

    // Arrow nudge: one canvas pixel, one undo entry.
    env.commands.nudge(1, 0);
    await tester.pump();
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 31, y: 30));
    env.commands.nudge(0, -1);
    await tester.pump();
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 31, y: 29));

    // Ctrl+D (through the channel) deselects.
    env.commands.deselect();
    await tester.pump();
    expect(env.commands.hasSelection, isFalse);

    // Re-select, then a click (degenerate marquee) deselects too.
    await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
    expect(env.commands.hasSelection, isTrue);
    await tester.tapAt(
      tester.getTopLeft(find.byKey(layerKey)) + const Offset(150, 150),
    );
    await tester.pump();
    expect(env.commands.hasSelection, isFalse);
  });

  group('Ctrl+T free transform (P9b)', () {
    testWidgets('inside-drag translates; Enter commits one undo entry', (
      tester,
    ) async {
      final env = await pumpSelectionPanel(tester);
      await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));

      env.commands.beginTransform();
      await tester.pump();
      expect(env.commands.transformActive, isTrue);

      // Drag inside the box: rides the session (nothing committed yet).
      await dragOnLayer(tester, const Offset(45, 45), const Offset(55, 48));
      expect(env.history.canUndo, isFalse);
      expect(
        strokeDabs(env.coordinator).first.center,
        CanvasPoint(x: 30, y: 30),
      );

      env.commands.commitTransform();
      await tester.pump();
      expect(env.commands.transformActive, isFalse);
      expect(
        strokeDabs(env.coordinator).first.center,
        CanvasPoint(x: 40, y: 33),
      );
      expect(env.history.canUndo, isTrue);
      env.history.undo();
      expect(
        strokeDabs(env.coordinator).first.center,
        CanvasPoint(x: 30, y: 30),
      );
    });

    testWidgets('a corner drag scales anchored on the opposite corner', (
      tester,
    ) async {
      final env = await pumpSelectionPanel(tester);
      // Selection box (20,20)..(70,70): pivot (45,45), BR handle at (70,70).
      await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
      env.commands.beginTransform();
      await tester.pump();

      // Drag BR to (95,95): 1.5× about the anchored TL corner (20,20).
      await dragOnLayer(tester, const Offset(70, 70), const Offset(95, 95));
      env.commands.commitTransform();
      await tester.pump();

      final dabs = strokeDabs(env.coordinator);
      expect(dabs[0].center.x, closeTo(35, 0.001));
      expect(dabs[0].center.y, closeTo(35, 0.001));
      expect(dabs[2].center.x, closeTo(80, 0.001));
      expect(dabs[2].center.y, closeTo(80, 0.001));
      // Dab size scales by √|1.5·1.5| = 1.5.
      expect(dabs[0].size, closeTo(6, 0.001));
    });

    testWidgets('Alt scales about the center; Escape discards everything', (
      tester,
    ) async {
      final env = await pumpSelectionPanel(tester);
      await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
      env.commands.beginTransform();
      await tester.pump();

      // Alt+drag BR (70,70)→(95,95): 2× about the center (45,45).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await dragOnLayer(tester, const Offset(70, 70), const Offset(95, 95));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      env.commands.commitTransform();
      await tester.pump();

      final dabs = strokeDabs(env.coordinator);
      expect(dabs[0].center.x, closeTo(15, 0.001));
      expect(dabs[1].center.x, closeTo(45, 0.001));
      expect(dabs[2].center.x, closeTo(75, 0.001));

      // A second session cancelled with Escape leaves no trace.
      env.commands.beginTransform();
      await tester.pump();
      await dragOnLayer(tester, const Offset(45, 45), const Offset(60, 60));
      env.commands.cancelTransform();
      await tester.pump();
      expect(strokeDabs(env.coordinator)[0].center.x, closeTo(15, 0.001));
      expect(env.commands.transformActive, isFalse);
    });

    testWidgets('the rotate knob turns the selection about its center', (
      tester,
    ) async {
      final env = await pumpSelectionPanel(tester);
      // Lower box (20,40)..(70,90): 2/3 of the stroke's dabs inside (45,45)
      // and (60,60) — selected by the 60% rule; the knob stays on-layer.
      await dragOnLayer(tester, const Offset(20, 40), const Offset(70, 90));
      expect(env.commands.hasSelection, isTrue);
      env.commands.beginTransform();
      await tester.pump();

      // Knob sits 28px above the top edge midpoint (45,40) → (45,12).
      // Sweep to angle 0° about the center (45,65): +90° rotation.
      await dragOnLayer(tester, const Offset(45, 12), const Offset(90, 65));
      env.commands.commitTransform();
      await tester.pump();

      // Selection is COMMAND-level: the whole stroke turns (all 3 dabs).
      final dabs = strokeDabs(env.coordinator);
      // (45,45): local (0,−20) → R90 → (20,0) → (65,65).
      expect(dabs[1].center.x, closeTo(65, 0.01));
      expect(dabs[1].center.y, closeTo(65, 0.01));
      // (30,30): local (−15,−35) → R90 → (35,−15) → (80,50).
      expect(dabs[0].center.x, closeTo(80, 0.01));
      expect(dabs[0].center.y, closeTo(50, 0.01));
      // The tip angle turned with the selection.
      expect(dabs[1].angleDegrees, closeTo(90, 0.01));
    });
  });

  testWidgets('the lasso tool selects with a freehand region', (tester) async {
    final env = await pumpSelectionPanel(tester, tool: CanvasTool.lasso);

    // A rough triangle around the stroke.
    final origin = tester.getTopLeft(find.byKey(layerKey));
    final gesture = await tester.startGesture(origin + const Offset(10, 10));
    await tester.pump();
    for (final point in const [
      Offset(90, 10),
      Offset(90, 90),
      Offset(10, 90),
    ]) {
      await gesture.moveTo(origin + point);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(env.commands.hasSelection, isTrue);
    env.commands.nudge(2, 0);
    await tester.pump();
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 32, y: 30));
  });
}
