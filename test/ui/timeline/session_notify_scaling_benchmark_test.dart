@Tags(['benchmark'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_orientation.dart';
import 'package:quick_animaker_v2/src/ui/timeline_tab_host.dart';

/// MEASUREMENT for the scoped-notify round (R27 #20 / #7, R28 #4).
///
/// The complaints are all "it gets slow", and the suspected root is one
/// structural fact: `EditorSessionManager.notifyListeners()` is a single
/// app-wide signal fired from ~128 call sites, so an edit that changes
/// ONE cell announces itself to everything subscribed.
///
/// The question that decides whether scoping is worth a round is not "is
/// it slow on the default project" — it is **does the cost grow with the
/// project**. A cost that scales with layers × frames can always be made
/// to lag by a big enough cut, which is exactly the "unpredictable heavy
/// situation" this has to survive. A flat cost means the notify is not
/// the problem and the round should go elsewhere.
///
/// So this drives the SAME operations at growing project sizes and prints
/// the per-operation UI-thread time. Prints; asserts only that the work
/// happened. Benchmarks run alone and only the A/B ratio is trusted
/// (verify-discipline).
///
/// CORRECTION (scoped-notify round): the host is now wrapped in a
/// ListenableBuilder(session) — the app's PanelAwareListenableBuilder. An
/// earlier revision pumped the bare host, which does NOT subscribe to the
/// session notify, so `create drawing` / `select layer` timed only the
/// seek-adjacent cursor + warm + toolbar-token cost and never the notify
/// rebuild. What the corrected harness then showed: the per-row memo already
/// scopes row rebuilds (only touched rows rebuild); the residual per-notify
/// cost is the CHROME (transport + action toolbar + ruler) rebuilding on
/// every notify, plus the framework's O(visible-rows) layout/paint walk.
void main() {
  /// One host, one project size. Returns the session so the caller can
  /// drive it; the widget tree is already pumped and settled.
  Future<EditorSessionManager> pumpTimeline(
    WidgetTester tester, {
    required int extraLayers,
    required int framesPerLayer,
  }) async {
    final session = EditorSessionManager(initialProject: createDefaultProject());

    for (var i = 0; i < extraLayers; i += 1) {
      session.addLayer();
    }
    // Fill each layer with drawings so the grid has real content to lay
    // out — an empty timeline is not what the user's project looks like.
    for (final layer in session.layers.toList()) {
      session.selectLayer(layer.id);
      for (var frame = 0; frame < framesPerLayer; frame += 1) {
        session.selectFrameIndex(frame);
        if (session.canCreateDrawingAtCurrentFrame) {
          session.createDrawingAtCurrentFrame();
        }
      }
    }
    session.selectFrameIndex(0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // THE session subscription: the app wraps the host in
          // PanelAwareListenableBuilder(listenable: session) (editor_workspace).
          // Without it a bare host NEVER rebuilds on a session notify, so
          // `create drawing` / `select layer` measured only the seek-adjacent
          // cursor + warm + token cost — NOT the notify rebuild this file
          // exists to size. This wrapper makes the notify path real.
          body: ListenableBuilder(
            listenable: session,
            builder: (context, _) => TimelineTabHost(
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
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  /// Wall time of [rounds] operations, each followed by the frame it
  /// causes — build + layout + paint on the test binding, which is the
  /// UI-thread work the user waits for.
  double microsPerOp(
    WidgetTester tester,
    void Function(int round) operation, {
    int rounds = 12,
  }) {
    final watch = Stopwatch()..start();
    for (var round = 0; round < rounds; round += 1) {
      operation(round);
      tester.binding.scheduleFrame();
      tester.binding.handleBeginFrame(Duration(milliseconds: 16 * round));
      tester.binding.handleDrawFrame();
    }
    watch.stop();
    return watch.elapsedMicroseconds / rounds;
  }

  /// Drops the host and the session so the next size starts clean — the
  /// playback prerender scheduler keeps a timer alive while a tree is up.
  Future<void> teardown(WidgetTester tester, EditorSessionManager session) async {
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    await tester.pumpAndSettle();
  }

  testWidgets('session notify cost vs project size', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // WARMUP, discarded. Without it the FIRST size measured carries the
    // JIT cost of the whole widget tree and reads slower than the biggest
    // project — which inverts the very trend this is here to find.
    final warm = await pumpTimeline(tester, extraLayers: 2, framesPerLayer: 4);
    microsPerOp(tester, (round) => warm.selectFrameIndex(round % 4));
    microsPerOp(tester, (round) {
      warm.selectFrameIndex(4 + round);
      warm.createDrawingAtCurrentFrame();
    });
    await teardown(tester, warm);

    // ignore: avoid_print
    print('--- scoped-notify measurement (debug build; ratios, not absolutes)');
    for (final size in const [
      (layers: 4, frames: 12, label: 'small  (4 layers x 12f)'),
      (layers: 12, frames: 24, label: 'medium (12 layers x 24f)'),
      (layers: 24, frames: 48, label: 'large  (24 layers x 48f)'),
    ]) {
      // A FRESH session per operation. Measuring them in sequence on one
      // session was wrong and quietly so: `create drawing` grows the
      // project, so the `seek` after it was timing a bigger timeline than
      // its own label claimed.
      Future<double> measure(
        void Function(EditorSessionManager session, int round) operation,
      ) async {
        final session = await pumpTimeline(
          tester,
          extraLayers: size.layers,
          framesPerLayer: size.frames,
        );
        final result = microsPerOp(
          tester,
          (round) => operation(session, round),
        );
        await teardown(tester, session);
        return result;
      }

      // 1. A layer switch: changes one field, then announces app-wide.
      // The closest thing to "pure announcement cost" a public API gives.
      final selectLayer = await measure((session, round) {
        final ids = session.layers.map((layer) => layer.id).toList();
        session.selectLayer(ids[round % ids.length]);
      });

      // 2. R27 #20: create a drawing. One command + one notify.
      final createDrawing = await measure((session, round) {
        session.selectFrameIndex(size.frames + round);
        session.createDrawingAtCurrentFrame();
      });

      // 3. R27 #7 shape: move the cursor along the row (what a drag does
      // per step). Cursor moves are supposed to be scoped ALREADY, which
      // is what makes their cost the interesting number here.
      final seek = await measure(
        (session, round) => session.selectFrameIndex(round % size.frames),
      );

      // ignore: avoid_print
      print(
        '${size.label}: select layer '
        '${(selectLayer / 1000).toStringAsFixed(2)}ms'
        ' | create drawing ${(createDrawing / 1000).toStringAsFixed(2)}ms'
        ' | seek ${(seek / 1000).toStringAsFixed(2)}ms',
      );
      expect(selectLayer, greaterThan(0));
    }
  });

  /// WHERE, inside the operation? `create drawing` is the outlier by an
  /// order of magnitude, and "scoped notify" only helps if the cost is in
  /// the REBUILD. If it is in the command itself, no amount of listener
  /// scoping touches it and the round would be aimed at the wrong thing.
  testWidgets('create drawing: command time vs rebuild time', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final warm = await pumpTimeline(tester, extraLayers: 2, framesPerLayer: 4);
    microsPerOp(tester, (round) {
      warm.selectFrameIndex(4 + round);
      warm.createDrawingAtCurrentFrame();
    });
    await teardown(tester, warm);

    // ignore: avoid_print
    print('--- create drawing, split (the R27 #20 outlier)');
    for (final size in const [
      (layers: 6, frames: 24, label: 'layers  6 x frames 24'),
      (layers: 24, frames: 48, label: 'layers 24 x frames 48'),
    ]) {
      final session = await pumpTimeline(
        tester,
        extraLayers: size.layers,
        framesPerLayer: size.frames,
      );
      const rounds = 8;
      final command = Stopwatch();
      final frame = Stopwatch();
      for (var round = 0; round < rounds; round += 1) {
        session.selectFrameIndex(size.frames + round);
        command.start();
        session.createDrawingAtCurrentFrame();
        command.stop();
        frame.start();
        tester.binding.scheduleFrame();
        tester.binding.handleBeginFrame(Duration(milliseconds: 16 * round));
        tester.binding.handleDrawFrame();
        frame.stop();
      }
      // ignore: avoid_print
      print(
        '${size.label}: command '
        '${(command.elapsedMicroseconds / rounds / 1000).toStringAsFixed(2)}ms'
        ' | rebuild '
        '${(frame.elapsedMicroseconds / rounds / 1000).toStringAsFixed(2)}ms',
      );
      expect(command.elapsedMicroseconds, greaterThan(0));
      await teardown(tester, session);
    }
  });

  /// WHICH AXIS? The scaling above cannot say whether the cost is per ROW
  /// (a rebuild of every layer's controls + band) or per CELL (grid
  /// geometry over frames). The fix is different for each, so hold one
  /// axis still and move the other.
  testWidgets('which axis drives it: layers or frames', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final warm = await pumpTimeline(tester, extraLayers: 2, framesPerLayer: 4);
    microsPerOp(tester, (round) => warm.selectFrameIndex(round % 4));
    await teardown(tester, warm);

    // ignore: avoid_print
    print('--- axis isolation (seek = the most scoped operation there is)');
    for (final probe in const [
      (layers: 6, frames: 24, label: 'layers  6 x frames 24'),
      (layers: 24, frames: 24, label: 'layers 24 x frames 24  (4x LAYERS)'),
      (layers: 6, frames: 96, label: 'layers  6 x frames 96  (4x FRAMES)'),
    ]) {
      final session = await pumpTimeline(
        tester,
        extraLayers: probe.layers,
        framesPerLayer: probe.frames,
      );
      final seek = microsPerOp(
        tester,
        (round) => session.selectFrameIndex(round % probe.frames),
      );
      // ignore: avoid_print
      print('${probe.label}: seek ${(seek / 1000).toStringAsFixed(2)}ms');
      expect(seek, greaterThan(0));
      await teardown(tester, session);
    }
  });
}
