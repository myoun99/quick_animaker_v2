import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_action_toolbar.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_orientation.dart';
import 'package:quick_animaker_v2/src/ui/timeline_tab_host.dart';
import 'package:quick_animaker_v2/src/ui/timesheet_tab_host.dart';

/// R13-2 playhead rebuild guards: committed seeks and cursor moves must
/// not rebuild what they don't change — measured on device as the
/// frame-flip hitch (the timesheet repainted the whole B4 sheet per
/// cursor move; the timeline rebuilt its whole transport + action toolbar
/// per seek).
void main() {
  testWidgets('a committed seek inside the same enablement state does NOT '
      'rebuild the timeline toolbar', (tester) async {
    final session = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineTabHost(
            session: session,
            orientation: TimelineOrientation.horizontal,
            onOrientationChanged: (_) {},
            pixelsPerFrame: 24,
            onPixelsPerFrameChanged: (_) {},
            showSeconds: false,
            onShowSecondsChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = tester.widget(find.byType(TimelineActionToolbar));

    // Frames 2 and 3 are both empty cells on the default project — the
    // toolbar's enablement token is identical, so the seek must be
    // swallowed whole.
    session.selectFrameIndex(2);
    await tester.pump();
    session.selectFrameIndex(3);
    await tester.pump();

    expect(
      identical(tester.widget(find.byType(TimelineActionToolbar)), before),
      isTrue,
      reason: 'same-enablement seeks must not reconstruct the toolbar',
    );

    // A seek that CHANGES what the buttons can do rebuilds once: landing
    // on a drawn cel flips the cell-sensitive enablements.
    session.selectFrameIndex(0);
    session.createDrawingAtCurrentFrame();
    session.selectFrameIndex(3);
    await tester.pump();
    session.selectFrameIndex(0);
    await tester.pump();
    expect(
      identical(tester.widget(find.byType(TimelineActionToolbar)), before),
      isFalse,
      reason: 'enablement changes still refresh the toolbar',
    );

    // Drain the prerender scheduler's debounced warming.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('a cursor move repaints only the timesheet playhead overlay '
      '— never the sheet painter', (tester) async {
    final session = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimesheetTabHost(
            session: session,
            continuous: false,
            onContinuousChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paintFinder = find.byKey(
      const ValueKey<String>('timesheet-document-paint'),
    );
    expect(paintFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('timesheet-playhead-overlay')),
      findsOneWidget,
    );
    final before = tester.widget(paintFinder);

    // Cursor moves and committed seeks within the same page: the sheet
    // paint widget must remain the IDENTICAL instance (repaints happen
    // on the overlay's own layer).
    session.editingFrameCursor.value = 3;
    await tester.pump();
    session.selectFrameIndex(5);
    await tester.pump();

    expect(
      identical(tester.widget(paintFinder), before),
      isTrue,
      reason: 'playhead moves must not rebuild the sheet painter',
    );

    // Drain the prerender scheduler's debounced warming.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
