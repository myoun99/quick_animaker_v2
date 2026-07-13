import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command.dart';
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
      Future<void> Function(CanvasTool tool) setTool,
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

    Future<void> pumpWith(CanvasTool tool) async {
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
    }

    await pumpWith(tool);
    return (
      coordinator: coordinator,
      history: history,
      commands: commands,
      setTool: pumpWith,
    );
  }

  List<BrushPaintCommand> frameCommands(
    BrushFrameEditingCoordinator coordinator,
  ) => coordinator.frameStore
      .getOrCreateFrame(coordinator.activeFrameKey)
      .visibleActivePaintCommands;

  List<BrushDab> strokeDabs(BrushFrameEditingCoordinator coordinator) =>
      frameCommands(coordinator).single.sourceDabs;

  /// The lift command's STAMP dab (R14-④: the Move tool's first
  /// interaction commits [erase, stamp]; moves translate the stamp).
  BrushDab liftStampDab(BrushFrameEditingCoordinator coordinator) =>
      frameCommands(coordinator).last.sourceDabs.last;

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

  testWidgets('marquee selects; the MOVE tool commits one undoable rewrite '
      '(R11-⑧: selection ≠ move)', (tester) async {
    final env = await pumpSelectionPanel(tester);

    // Marquee around the whole stroke (viewport is identity: local ==
    // canvas coordinates).
    await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
    expect(env.commands.hasSelection, isTrue);

    // A MARQUEE-tool drag inside the region draws a NEW region — content
    // never moves on the selection tools.
    await dragOnLayer(tester, const Offset(25, 25), const Offset(68, 68));
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 30, y: 30));
    expect(env.commands.hasSelection, isTrue);

    // The MOVE tool opens a TVP-style SESSION (R16-①): drags move only
    // the floating stamp — nothing lands and nothing is undoable until
    // the CONFIRM, which adopts lift + final position as ONE entry.
    await env.setTool(CanvasTool.move);
    final entriesBeforeMove = env.history.undoCount;
    await dragOnLayer(tester, const Offset(45, 45), const Offset(55, 50));

    expect(
      frameCommands(env.coordinator),
      hasLength(2),
      reason: 'the raw lift erase is committed; the stamp floats',
    );
    expect(
      frameCommands(env.coordinator).last.sourceDabs.every((d) => d.erase),
      isTrue,
      reason: 'pending: the base holds only the erase',
    );
    expect(env.commands.movePending, isTrue);
    expect(
      env.history.undoCount,
      entriesBeforeMove,
      reason: 'nothing is undoable before the confirm',
    );

    // CONFIRM: one history entry; the stamp lands at the moved position.
    // The ACTIVE marquee is the second one, (25,25)-(68,68) → a 44×44
    // stamp centered at (47,47), moved by the drag delta (+10,+5).
    env.commands.confirmPendingMove();
    await tester.pump();
    expect(env.commands.movePending, isFalse);
    expect(env.history.undoCount, entriesBeforeMove + 1);
    expect(liftStampDab(env.coordinator).center, CanvasPoint(x: 57, y: 52));
    expect(
      frameCommands(env.coordinator).first.sourceDabs.first.center,
      CanvasPoint(x: 30, y: 30),
      reason: 'bitmap lift moves pixels, never the source stroke',
    );

    env.history.undo(); // the WHOLE session (lift + move) as one step
    await tester.pump();
    expect(
      frameCommands(env.coordinator),
      hasLength(1),
      reason: 'one undo restores the pre-lift picture',
    );

    env.history.redo();
    await tester.pump();
    expect(liftStampDab(env.coordinator).center, CanvasPoint(x: 57, y: 52));

    // Outside the region the move tool does nothing.
    await dragOnLayer(tester, const Offset(150, 150), const Offset(170, 170));
    expect(liftStampDab(env.coordinator).center, CanvasPoint(x: 57, y: 52));
  });

  testWidgets('the session floats through the WHOLE interaction: the base '
      'holds only the erase until the confirm; a zero-move confirm is an '
      'identity landing (R16-①)', (tester) async {
    final env = await pumpSelectionPanel(tester);
    await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
    await env.setTool(CanvasTool.move);

    final origin = tester.getTopLeft(find.byKey(layerKey));
    final gesture = await tester.startGesture(origin + const Offset(45, 45));
    await tester.pump();
    // Mid-drag: the lift command carries the erase but NOT the stamp —
    // the base never shows the moving pixels (no double image).
    final midDabs = frameCommands(env.coordinator).last.sourceDabs;
    expect(midDabs.every((dab) => dab.erase), isTrue);

    // Zero-move release: the session STAYS pending (the float keeps
    // showing the pixels); the base still holds only the erase.
    await gesture.up();
    await tester.pump();
    expect(env.commands.movePending, isTrue);
    expect(
      frameCommands(env.coordinator).last.sourceDabs.every((d) => d.erase),
      isTrue,
    );

    // Confirm: the stamp lands at its origin — identity picture.
    env.commands.confirmPendingMove();
    await tester.pump();
    expect(env.commands.movePending, isFalse);
    expect(liftStampDab(env.coordinator).center, CanvasPoint(x: 45.5, y: 45.5));
  });

  testWidgets('selecting and deselecting are undoable steps (R11-⑧)', (
    tester,
  ) async {
    final env = await pumpSelectionPanel(tester);

    await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
    expect(env.commands.hasSelection, isTrue);
    expect(env.history.canUndo, isTrue);

    env.history.undo();
    await tester.pump();
    expect(env.commands.hasSelection, isFalse);

    env.history.redo();
    await tester.pump();
    expect(env.commands.hasSelection, isTrue);

    // Ctrl+D is undoable too.
    env.commands.deselect();
    await tester.pump();
    expect(env.commands.hasSelection, isFalse);
    env.history.undo();
    await tester.pump();
    expect(env.commands.hasSelection, isTrue);
  });

  testWidgets('a marquee missing the stroke selects nothing movable', (
    tester,
  ) async {
    final env = await pumpSelectionPanel(tester);

    await dragOnLayer(tester, const Offset(100, 100), const Offset(140, 140));
    expect(env.commands.hasSelection, isTrue);

    // The move tool grabs nothing there (no commands joined the region).
    await env.setTool(CanvasTool.move);
    await dragOnLayer(tester, const Offset(110, 110), const Offset(120, 120));
    expect(strokeDabs(env.coordinator).first.center, CanvasPoint(x: 30, y: 30));
  });

  testWidgets('click-away and Ctrl+D deselect; nudges move by one pixel', (
    tester,
  ) async {
    final env = await pumpSelectionPanel(tester);

    await dragOnLayer(tester, const Offset(20, 20), const Offset(70, 70));
    expect(env.commands.hasSelection, isTrue);

    // Arrow nudges move the SESSION's float only (R16-①); the confirm
    // lands the accumulated result as one entry. The source stroke never
    // moves.
    env.commands.nudge(1, 0);
    env.commands.nudge(0, -1);
    await tester.pump();
    expect(frameCommands(env.coordinator), hasLength(2));
    expect(env.commands.movePending, isTrue);
    env.commands.confirmPendingMove();
    await tester.pump();
    expect(
      frameCommands(env.coordinator).first.sourceDabs.first.center,
      CanvasPoint(x: 30, y: 30),
    );
    expect(liftStampDab(env.coordinator).center, CanvasPoint(x: 46.5, y: 44.5));

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

      // Drag inside the box: rides the session (nothing committed yet —
      // the history holds only the marquee's Select entry).
      final undoDepthBefore = env.history.undoCount;
      await dragOnLayer(tester, const Offset(45, 45), const Offset(55, 48));
      expect(env.history.undoCount, undoDepthBefore);
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
    // The nudge lifts the lasso region's pixels into a pending session —
    // bbox (10,10)-(90,90) → an 81×81 stamp centered at (50.5,50.5),
    // nudged +2 and CONFIRMED; the source stroke stays put.
    env.commands.nudge(2, 0);
    await tester.pump();
    env.commands.confirmPendingMove();
    await tester.pump();
    expect(
      frameCommands(env.coordinator).first.sourceDabs.first.center,
      CanvasPoint(x: 30, y: 30),
    );
    expect(liftStampDab(env.coordinator).center, CanvasPoint(x: 52.5, y: 50.5));
  });
}
