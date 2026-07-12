import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/drawing_block_move.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';

/// R10-④b: whole-block move planning — slides remap the timeline entry,
/// cross-layer moves carry the cel, and every landing needs empty space.
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

    test('rejects a no-op, a negative landing and an overlap', () {
      final layer = layerWith(
        'a',
        {
          0: const TimelineExposure.drawing(FrameId('a-f1'), length: 2),
          5: const TimelineExposure.drawing(FrameId('a-f2'), length: 2),
        },
        frameIds: ['a-f1', 'a-f2'],
      );

      Layer plan(int delta) =>
          planDrawingBlockMove(
            source: layer,
            target: layer,
            blockStartIndex: 0,
            frameDelta: delta,
          )?.sourceAfter ??
          layer;

      expect(plan(0), same(layer), reason: 'zero delta is a no-op');
      expect(plan(-1), same(layer), reason: 'cannot land before frame 0');
      // [4,6) overlaps the block at [5,7); [6,8) starts inside it too.
      expect(plan(4), same(layer));
      expect(plan(6), same(layer));
      // [3,5) touches the neighbor exactly — legal.
      expect(plan(3).timeline[3], isNotNull);
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

    test('rejects when the destination overlaps a target block', () {
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

      expect(
        planDrawingBlockMove(
          source: source,
          target: target,
          blockStartIndex: 0,
          frameDelta: 0,
        ),
        isNull,
        reason: '[0,3) overlaps the target block at [2,4)',
      );
      expect(
        planDrawingBlockMove(
          source: source,
          target: target,
          blockStartIndex: 0,
          frameDelta: 4,
        ),
        isNotNull,
        reason: '[4,7) clears it',
      );
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
