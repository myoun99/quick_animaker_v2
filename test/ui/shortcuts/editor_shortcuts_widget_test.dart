import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
import 'package:quick_animaker_v2/src/ui/brush/main_canvas_brush_host.dart';
import 'package:quick_animaker_v2/src/ui/brush/tools_panel.dart';
import 'package:quick_animaker_v2/src/ui/editor_canvas_area.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';

/// P1: the app-level shortcut layer end to end — flipping, tools, undo,
/// the text-field bare-letter guard and live re-recording through the
/// Keyboard Shortcuts dialog.
void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
  }

  String counterText(WidgetTester tester) => tester
      .widget<Text>(
        find.byKey(const ValueKey<String>('timeline-current-frame-counter')),
      )
      .data!;

  testWidgets('comma/period flip frames; Ctrl variants jump drawings', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(counterText(tester), '1');

    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    expect(counterText(tester), '2');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(counterText(tester), '3');

    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.pumpAndSettle();
    expect(counterText(tester), '2');

    // Clamped at the cut start.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.pumpAndSettle();
    expect(counterText(tester), '1');

    // A drawing at frame 1, playhead moved ahead: Ctrl+, jumps back to
    // the block start.
    await tester.tap(find.byKey(const ValueKey<String>('menu-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('menu-edit-new-drawing')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    expect(counterText(tester), '3');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(counterText(tester), '1');
  });

  testWidgets('B/E switch tools; typing in a text field never does', (
    tester,
  ) async {
    await pumpHome(tester);
    CanvasTool toolOf() =>
        tester.widget<ToolsPanel>(find.byType(ToolsPanel)).tool;

    expect(toolOf(), CanvasTool.brush);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();
    expect(toolOf(), CanvasTool.eraser);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(toolOf(), CanvasTool.brush);

    // A focused text field absorbs bare letters (the rename dialog).
    await tester.tap(find.byKey(const ValueKey<String>('menu-cut')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('menu-cut-rename')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();
    expect(toolOf(), CanvasTool.brush, reason: 'typing must not switch tools');
    // Close the dialog.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });

  testWidgets('I enters the eyedropper remembering the return tool; G fills', (
    tester,
  ) async {
    await pumpHome(tester);
    CanvasTool toolOf() =>
        tester.widget<ToolsPanel>(find.byType(ToolsPanel)).tool;
    BrushToolState stateOf() => tester
        .widget<EditorCanvasArea>(find.byType(EditorCanvasArea))
        .brushToolState
        .value;

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();
    expect(toolOf(), CanvasTool.eraser);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pumpAndSettle();
    expect(toolOf(), CanvasTool.eyedropper);
    expect(stateOf().eyedropperReturnTool, CanvasTool.eraser);

    // Pressing I again must not overwrite the memory with the eyedropper
    // itself (a pick would then trap the tool).
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pumpAndSettle();
    expect(stateOf().eyedropperReturnTool, CanvasTool.eraser);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pumpAndSettle();
    expect(toolOf(), CanvasTool.fill);
  });

  testWidgets('R/Shift+R rotate the canvas view; H flips it (P8)', (
    tester,
  ) async {
    await pumpHome(tester);
    // The canvas area syncs every viewport change back into the host's
    // viewport param — a stable oracle even without an editable frame.
    CanvasViewport viewportOf() =>
        tester
            .widget<MainCanvasBrushHost>(find.byType(MainCanvasBrushHost))
            .viewport ??
        CanvasViewport();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();
    expect(viewportOf().rotationDegrees, -15);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(viewportOf().rotationDegrees, 15);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    expect(viewportOf().flipHorizontal, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    expect(viewportOf().flipHorizontal, isFalse);
  });

  testWidgets('Ctrl+Z undoes; Space enters playback', (tester) async {
    await pumpHome(tester);

    // Create an undoable step (a drawing via the menu).
    await tester.tap(find.byKey(const ValueKey<String>('menu-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('menu-edit-new-drawing')),
    );
    await tester.pumpAndSettle();
    final undoButton = find.byKey(const ValueKey<String>('undo-button'));
    expect(tester.widget<IconButton>(undoButton).onPressed, isNotNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(undoButton).onPressed, isNull);

    // Space starts playback (the playback view mounts). Plain pumps: the
    // playback ticker never lets pumpAndSettle settle.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('canvas-playback-view')),
      findsOneWidget,
    );
    // Space again pauses without leaving playback mode.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('canvas-playback-view')),
      findsOneWidget,
    );
    // Stop so no ticker leaks out of the test.
    await tester.tap(
      find.byKey(const ValueKey<String>('canvas-playback-view')),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('the Keyboard Shortcuts dialog re-records a binding LIVE '
      'and Reset All restores the defaults', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey<String>('menu-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('menu-edit-keyboard-shortcuts')),
    );
    await tester.pumpAndSettle();

    // Record N as the new Next Frame key.
    await tester.tap(
      find.byKey(const ValueKey<String>('shortcut-record-frame-next')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('shortcut-recording-hint')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('shortcut-action-list')),
        matching: find.text('N'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('shortcut-close-button')),
    );
    await tester.pumpAndSettle();

    // The NEW key flips; the replaced default no longer does.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(counterText(tester), '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    expect(counterText(tester), '2');

    // Reset All restores the stock bindings.
    await tester.tap(find.byKey(const ValueKey<String>('menu-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('menu-edit-keyboard-shortcuts')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('shortcut-reset-all-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('shortcut-close-button')),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pumpAndSettle();
    expect(counterText(tester), '3');
  });
}
