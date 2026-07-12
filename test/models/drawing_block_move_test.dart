import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/drawing_block_move.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';

/// R10-④b + R12-②: whole-block move planning — slides remap the timeline
/// entry, cross-layer moves carry the cel, and blocks in the way are PUSHED
/// in the direction of travel (leftward pushes clamp at the frame-0 wall).
void main() {
  Layer layerWith(
    String id,
    Map<int, TimelineExposure> timeline, {
    List<String> frameIds = const [],
  }) => Layer(
    id: LayerId(id),
    name: id,
    frames: [
      for (final frameId in frameIds)
        Frame(id: FrameId(frameId), duration: 1, strokes: const []),
    ],
    timeline: timeline,
  );

  group('same-layer slide', () {
    test('remaps the entry and keeps the frames list', () {
      final layer = layerWith(
        'a',
        {0: const TimelineExposure.drawing(FrameId('a-f1'), length: 3)},
        frameIds: ['a-f1'],
      );

      final plan = planDrawingBlockMove(
        source: layer,
        target: layer,
        blockStartIndex: 0,
        frameDelta: 4,
      );

      expect(plan, isNotNull);
      expect(plan!.isCrossLayer, isFalse);
      expect(plan.destinationStartIndex, 4);
      expect(plan.sourceAfter.timeline[0], isNull);
      expect(plan.sourceAfter.timeline[4]!.frameId, const FrameId('a-f1'));
      expect(plan.sourceAfter.timeline[4]!.length, 3);
      expect(plan.sourceAfter.frames, layer.frames);
      expect(plan.movedFrameIds, isEmpty);
    });

    test('rejects a no-op and a fully clamped leftward move', () {
      final layer = layerWith(
        'a',
        {
          0: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          5: const TimelineExposure.drawing(FrameId('a-f2'), length: 2),
        },
        frameIds: ['a-f1', 'a-f2'],
      );

      DrawingBlockMovePlan? plan(int delta) => planDrawingBlockMove(
        source: layer,
        target: layer,
        blockStartIndex: 0,
        frameDelta: delta,
      );

      expect(plan(0), isNull, reason: 'zero delta is a no-op');
      expect(
        plan(-1),
        isNull,
        reason: 'the frame-0 wall clamps the move back to its own start',
      );
    });

    test('rightward push: the block ahead shifts by the overlap, cascading',
        () {
      final layer = layerWith(
        'a',
        {
          0: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          3: const TimelineExposure.drawing(FrameId('a-f2'), length: 2),
          6: const TimelineExposure.drawing(FrameId('a-f3'), length: 2),
        },
        frameIds: ['a-f1', 'a-f2', 'a-f3'],
      );

      final plan = planDrawingBlockMove(
        source: layer,
        target: layer,
        blockStartIndex: 0,
        frameDelta: 3,
      );

      expect(plan, isNotNull);
      final timeline = plan!.sourceAfter.timeline;
      expect(plan.destinationStartIndex, 3);
      expect(timeline[3]!.frameId, const FrameId('a-f1'));
      // [3,5) pushed to [5,7); that push shoves [6,8) on to [7,9).
      expect(timeline[5]!.frameId, const FrameId('a-f2'));
      expect(timeline[7]!.frameId, const FrameId('a-f3'));
      expect(timeline.length, 3);
    });

    test('leftward push: the block ahead slides toward frame 0, and the '
        'move clamps when the wall stops the chain', () {
      // A gap in front of the leading block: pushing can consume it.
      final pushable = layerWith(
        'a',
        {
          2: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          6: const TimelineExposure.drawing(FrameId('a-f2'), length: 2),
        },
        frameIds: ['a-f1', 'a-f2'],
      );
      final pushed = planDrawingBlockMove(
        source: pushable,
        target: pushable,
        blockStartIndex: 6,
        frameDelta: -3,
      );
      expect(pushed, isNotNull);
      expect(pushed!.destinationStartIndex, 3);
      expect(pushed.sourceAfter.timeline[1]!.frameId, const FrameId('a-f1'));
      expect(pushed.sourceAfter.timeline[3]!.frameId, const FrameId('a-f2'));

      // No gap anywhere: the chain hits the wall and the landing clamps
      // flush against the leading block.
      final packed = layerWith(
        'a',
        {
          0: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          5: const TimelineExposure.drawing(FrameId('a-f2'), length: 2),
        },
        frameIds: ['a-f1', 'a-f2'],
      );
      final clamped = planDrawingBlockMove(
        source: packed,
        target: packed,
        blockStartIndex: 5,
        frameDelta: -5,
      );
      expect(clamped, isNotNull);
      expect(clamped!.destinationStartIndex, 2);
      expect(clamped.sourceAfter.timeline[0]!.frameId, const FrameId('a-f1'));
      expect(clamped.sourceAfter.timeline[2]!.frameId, const FrameId('a-f2'));
    });

    test('a linked cel may slide (frames stay put), but a mark blocks the '
        'landing start only', () {
      final layer = layerWith(
        'a',
        {
          0: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          6: const TimelineExposure.drawing(FrameId('a-f1'), length: 1),
          4: const TimelineExposure.mark(),
        },
        frameIds: ['a-f1'],
      );

      // Landing ON the mark's index is rejected (map key collision)…
      expect(
        planDrawingBlockMove(
          source: layer,
          target: layer,
          blockStartIndex: 0,
          frameDelta: 4,
        ),
        isNull,
      );
      // …but covering it with the hold is fine (marks live inside holds),
      // linked cel notwithstanding — a slide moves no frames.
      final plan = planDrawingBlockMove(
        source: layer,
        target: layer,
        blockStartIndex: 0,
        frameDelta: 3,
      );
      expect(plan, isNotNull);
      expect(plan!.sourceAfter.timeline[3]!.frameId, const FrameId('a-f1'));
      expect(plan.sourceAfter.timeline[4]!.isMark, isTrue);
    });
  });

  group('cross-layer move', () {
    test('carries the cel: timelines and frames update on both layers', () {
      final source = layerWith(
        'a',
        {2: const TimelineExposure.drawing(FrameId('a-f1'), length: 3)},
        frameIds: ['a-f1'],
      );
      final target = layerWith(
        'b',
        {0: const TimelineExposure.drawing(FrameId('b-f1'), length: 2)},
        frameIds: ['b-f1'],
      );

      final plan = planDrawingBlockMove(
        source: source,
        target: target,
        blockStartIndex: 2,
        frameDelta: 1,
      );

      expect(plan, isNotNull);
      expect(plan!.isCrossLayer, isTrue);
      expect(plan.destinationStartIndex, 3);
      expect(plan.movedFrameIds, [const FrameId('a-f1')]);
      expect(plan.sourceAfter.timeline, isEmpty);
      expect(plan.sourceAfter.frames, isEmpty);
      expect(plan.targetAfter!.timeline[3]!.frameId, const FrameId('a-f1'));
      expect(plan.targetAfter!.timeline[3]!.length, 3);
      expect(plan.targetAfter!.frames, hasLength(2));
      // The untouched target block survives.
      expect(plan.targetAfter!.timeline[0]!.frameId, const FrameId('b-f1'));
    });

    test('an occupied landing pushes the target block out of the way '
        '(rightward default)', () {
      final source = layerWith(
        'a',
        {0: const TimelineExposure.drawing(FrameId('a-f1'), length: 3)},
        frameIds: ['a-f1'],
      );
      final target = layerWith(
        'b',
        {2: const TimelineExposure.drawing(FrameId('b-f1'), length: 2)},
        frameIds: ['b-f1'],
      );

      final plan = planDrawingBlockMove(
        source: source,
        target: target,
        blockStartIndex: 0,
        frameDelta: 0,
      );

      expect(plan, isNotNull);
      expect(plan!.destinationStartIndex, 0);
      expect(plan.targetAfter!.timeline[0]!.frameId, const FrameId('a-f1'));
      // [2,4) pushed behind the landed block: [3,5).
      expect(plan.targetAfter!.timeline[3]!.frameId, const FrameId('b-f1'));
      expect(plan.targetAfter!.timeline.length, 2);
    });

    test('rejects a linked cel (another entry references the frame)', () {
      final source = layerWith(
        'a',
        {
          0: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          5: const TimelineExposure.drawing(FrameId('a-f1'), length: 1),
        },
        frameIds: ['a-f1'],
      );
      final target = layerWith('b', const {});

      expect(
        planDrawingBlockMove(
          source: source,
          target: target,
          blockStartIndex: 0,
          frameDelta: 0,
        ),
        isNull,
        reason: 'moving the cel would break the link at frame 5',
      );
    });
  });
}
