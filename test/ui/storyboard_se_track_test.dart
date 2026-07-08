import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/timeline/dialogue_fit_text.dart';

Cut _cut({
  required String id,
  required int duration,
  required String seLabel,
  required int seStart,
  required int seLength,
}) {
  return Cut(
    id: CutId(id),
    name: id,
    duration: duration,
    canvasSize: const CanvasSize(width: 640, height: 360),
    layers: [
      Layer(
        id: LayerId('$id-cel'),
        name: 'A',
        frames: const [],
        timeline: const {},
      ),
      Layer(
        id: LayerId('$id-se'),
        name: 'S1',
        kind: LayerKind.se,
        frames: [
          Frame(
            id: FrameId('$id-se-f'),
            duration: seLength,
            name: seLabel,
            strokes: const [],
          ),
        ],
        timeline: {
          seStart: TimelineExposure.drawing(
            FrameId('$id-se-f'),
            length: seLength,
          ),
        },
      ),
    ],
  );
}

Project _project() {
  return Project(
    id: const ProjectId('sb-se-project'),
    name: 'SB SE Project',
    createdAt: DateTime.utc(2026, 7, 8),
    tracks: [
      Track(
        id: const TrackId('sb-se-track'),
        name: 'Video',
        cuts: [
          _cut(
            id: 'cut-1',
            duration: 8,
            seLabel: 'One!',
            seStart: 1,
            seLength: 3,
          ),
          // The second cut's entry runs past its duration (6): the
          // storyboard clamps the span at the cut boundary.
          _cut(
            id: 'cut-2',
            duration: 6,
            seLabel: 'Two!',
            seStart: 2,
            seLength: 99,
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('the storyboard shows synced SE rows: rail label + per-cut '
      'spans on the global frame axis, clamped at cut ends', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomePage(initialProject: _project())),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-mode-storyboard-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('storyboard-se-label-sb-se-track-1')),
      findsOneWidget,
    );
    expect(find.text('S1'), findsWidgets);

    final rowFinder = find.byKey(
      const ValueKey<String>('storyboard-se-row-0-1'),
    );
    expect(rowFinder, findsOneWidget);

    final spanOne = find.byKey(
      const ValueKey<String>('storyboard-se-span-cut-1-1'),
    );
    final spanTwo = find.byKey(
      const ValueKey<String>('storyboard-se-span-cut-2-2'),
    );
    expect(spanOne, findsOneWidget);
    expect(spanTwo, findsOneWidget);
    // Dialogue is painted (fitted glyphs) — read the widget fields.
    String dialogueOf(Finder span) => tester
        .widget<DialogueFitText>(
          find.descendant(of: span, matching: find.byType(DialogueFitText)),
        )
        .text;
    expect(dialogueOf(spanOne), 'One!');
    expect(dialogueOf(spanTwo), 'Two!');
    // Each span sits on its own paper block.
    expect(
      find.byKey(const ValueKey<String>('storyboard-se-paper-cut-1-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('storyboard-se-paper-cut-2-2')),
      findsOneWidget,
    );

    // Global placement: cut-2 starts at frame 8, its entry at local 2 →
    // global 10; the 99-frame entry clamps at the cut's 6 frames → 4 wide.
    final rowLeft = tester.getTopLeft(rowFinder).dx;
    final spanOneRect = tester.getRect(spanOne);
    final spanTwoRect = tester.getRect(spanTwo);
    final pixelsPerFrame = (spanOneRect.left - rowLeft) / 1;
    expect(pixelsPerFrame, greaterThan(0));
    expect(
      spanTwoRect.left - rowLeft,
      moreOrLessEquals(10 * pixelsPerFrame, epsilon: 0.01),
    );
    expect(
      spanTwoRect.width,
      moreOrLessEquals(4 * pixelsPerFrame, epsilon: 0.01),
    );
  });
}
