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

Cut _cut(String id, int duration) {
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
    ],
  );
}

Frame _frame(String id, String name, int length) =>
    Frame(id: FrameId(id), duration: length, name: name, strokes: const []);

/// TRACK-owned SE row on the global frame axis: an entry inside cut 1, an
/// entry CROSSING the cut-1→cut-2 boundary (frame 8), and one inside
/// cut 2.
Project _project() {
  return Project(
    id: const ProjectId('sb-se-project'),
    name: 'SB SE Project',
    createdAt: DateTime.utc(2026, 7, 8),
    tracks: [
      Track(
        id: const TrackId('sb-se-track'),
        name: 'Video',
        cuts: [_cut('cut-1', 8), _cut('cut-2', 6)],
        seLayers: [
          Layer(
            id: const LayerId('se-row-1'),
            name: 'S1',
            kind: LayerKind.se,
            frames: [
              _frame('f-one', 'One!', 3),
              _frame('f-cross', 'Cross!', 4),
              _frame('f-two', 'Two!', 2),
            ],
            timeline: {
              1: const TimelineExposure.drawing(FrameId('f-one'), length: 3),
              6: const TimelineExposure.drawing(FrameId('f-cross'), length: 4),
              10: const TimelineExposure.drawing(FrameId('f-two'), length: 2),
            },
          ),
          Layer(
            id: const LayerId('se-row-2'),
            name: 'S2',
            kind: LayerKind.se,
            frames: const [],
            timeline: const {},
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('the storyboard renders the TRACK SE row on the global axis: '
      'true lengths across cut ends with a ~ crossing mark', (tester) async {
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
      const ValueKey<String>('storyboard-se-span-se-row-1-1'),
    );
    final spanCross = find.byKey(
      const ValueKey<String>('storyboard-se-span-se-row-1-6'),
    );
    final spanTwo = find.byKey(
      const ValueKey<String>('storyboard-se-span-se-row-1-10'),
    );
    expect(spanOne, findsOneWidget);
    expect(spanCross, findsOneWidget);
    expect(spanTwo, findsOneWidget);
    // Dialogue is painted (fitted glyphs) — read the widget fields.
    String dialogueOf(Finder span) => tester
        .widget<DialogueFitText>(
          find.descendant(of: span, matching: find.byType(DialogueFitText)),
        )
        .text;
    expect(dialogueOf(spanOne), 'One!');
    expect(dialogueOf(spanCross), 'Cross!');
    expect(dialogueOf(spanTwo), 'Two!');

    // Global placement with TRUE lengths: the crossing entry [6, 10) keeps
    // its 4 frames straight across the cut boundary at 8…
    final rowLeft = tester.getTopLeft(rowFinder).dx;
    final spanOneRect = tester.getRect(spanOne);
    final spanCrossRect = tester.getRect(spanCross);
    final spanTwoRect = tester.getRect(spanTwo);
    final pixelsPerFrame = (spanOneRect.left - rowLeft) / 1;
    expect(pixelsPerFrame, greaterThan(0));
    expect(
      spanCrossRect.left - rowLeft,
      moreOrLessEquals(6 * pixelsPerFrame, epsilon: 0.01),
    );
    expect(
      spanCrossRect.width,
      moreOrLessEquals(4 * pixelsPerFrame, epsilon: 0.01),
    );
    expect(
      spanTwoRect.left - rowLeft,
      moreOrLessEquals(10 * pixelsPerFrame, epsilon: 0.01),
    );
    expect(
      spanTwoRect.width,
      moreOrLessEquals(2 * pixelsPerFrame, epsilon: 0.01),
    );

    // …and the crossed boundary carries the ~ continuation mark.
    expect(
      find.byKey(const ValueKey<String>('storyboard-se-crossing-se-row-1-8')),
      findsOneWidget,
    );
  });
}
