import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_repeat.dart';

Frame _frame(String id) =>
    Frame(id: FrameId(id), duration: 1, strokes: const []);

Layer _layer({
  required Map<int, TimelineExposure> timeline,
  List<TimelineRepeatRegion> regions = const [],
  List<String> frameIds = const ['a', 'b', 'c'],
}) {
  return Layer(
    id: const LayerId('layer-1'),
    name: 'L',
    frames: [for (final id in frameIds) _frame(id)],
    timeline: timeline,
    repeatRegions: regions,
  );
}

TimelineExposure _draw(String id, int length) =>
    TimelineExposure.drawing(FrameId(id), length: length);

void main() {
  test('no regions and no ghosts returns the SAME layer instance', () {
    final layer = _layer(timeline: {0: _draw('a', 3)});
    expect(identical(rederiveRepeatRegions(layer), layer), isTrue);
  });

  test('a single-block run cycles glued after the span', () {
    final layer = _layer(
      timeline: {0: _draw('a', 3)},
      regions: const [
        TimelineRepeatRegion(
          id: 'r1',
          anchorFrameId: FrameId('a'),
          sourceSpanFrames: 3,
          frameCount: 6,
        ),
      ],
    );

    final derived = rederiveRepeatRegions(layer);
    // Ghost entries share the source frameId and carry the region id.
    final ghost3 = derived.timeline[3]!;
    final ghost6 = derived.timeline[6]!;
    expect(ghost3.frameId, const FrameId('a'));
    expect(ghost3.length, 3);
    expect(ghost6.frameId, const FrameId('a'));
    expect(ghost6.length, 3);
    expect(ghost3.ghost && ghost6.ghost, isTrue);
    expect(ghost3.repeatRegionId, 'r1');
    // The region spec survives untouched.
    expect(derived.repeatRegions, layer.repeatRegions);
  });

  test('a multi-block pattern with a gap repeats the WHOLE pattern '
      '(gaps included), truncating the tail at the region end', () {
    // Span [0,4): a@0 len2, gap at 2, b@3 len1.
    final layer = _layer(
      timeline: {0: _draw('a', 2), 3: _draw('b', 1)},
      regions: const [
        TimelineRepeatRegion(
          id: 'r1',
          anchorFrameId: FrameId('a'),
          sourceSpanFrames: 4,
          frameCount: 7,
        ),
      ],
    );

    final derived = rederiveRepeatRegions(layer);
    // Cycle 1 at 4: a@4 len2, b@7 len1. Cycle 2 at 8: a@8 len2, b@11 —
    // but the budget ends at 4+7=11, so b@11 is out and a@8 fits whole.
    expect(derived.timeline[4]!.frameId, const FrameId('a'));
    expect(derived.timeline[4]!.length, 2);
    expect(derived.timeline[7]!.frameId, const FrameId('b'));
    expect(derived.timeline[8]!.frameId, const FrameId('a'));
    expect(derived.timeline[8]!.length, 2);
    expect(derived.timeline.containsKey(11), isFalse);
    for (final key in [4, 7, 8]) {
      expect(derived.timeline[key]!.ghost, isTrue, reason: 'ghost at $key');
    }
  });

  test('LIVE SYNC: moving/resizing the anchored run re-arranges the ghosts '
      'on the next rederive', () {
    const region = TimelineRepeatRegion(
      id: 'r1',
      anchorFrameId: FrameId('a'),
      sourceSpanFrames: 3,
      frameCount: 3,
    );
    final before = rederiveRepeatRegions(
      _layer(timeline: {0: _draw('a', 3)}, regions: const [region]),
    );
    expect(before.timeline[3]!.ghost, isTrue);

    // The run moved to 5 (e.g. a range move rewrote the base timeline).
    final movedBase = _layer(
      timeline: {5: _draw('a', 3)},
      regions: const [region],
    );
    final after = rederiveRepeatRegions(movedBase);
    expect(after.timeline.containsKey(3), isFalse);
    expect(after.timeline[8]!.ghost, isTrue);
    expect(after.timeline[8]!.frameId, const FrameId('a'));
  });

  test('a vanished anchor DROPS the region and its ghosts', () {
    const region = TimelineRepeatRegion(
      id: 'r1',
      anchorFrameId: FrameId('zz'),
      sourceSpanFrames: 3,
      frameCount: 3,
    );
    final layer = _layer(timeline: {0: _draw('a', 3)}, regions: const [region]);
    final derived = rederiveRepeatRegions(layer);
    expect(derived.repeatRegions, isEmpty);
    expect(derived.timeline.values.any((entry) => entry.ghost), isFalse);
  });

  test('ghosts CLAMP before the next authored entry (block or mark) — '
      'derived frames never displace authored ones', () {
    final layer = _layer(
      timeline: {
        0: _draw('a', 2),
        5: const TimelineExposure.mark(),
        8: _draw('b', 2),
      },
      regions: const [
        TimelineRepeatRegion(
          id: 'r1',
          anchorFrameId: FrameId('a'),
          sourceSpanFrames: 2,
          frameCount: 10,
        ),
      ],
    );

    final derived = rederiveRepeatRegions(layer);
    // Budget [2,12) clamps at the mark (5): one whole cycle at 2, then the
    // cycle at 4 truncates to length 1.
    expect(derived.timeline[2]!.ghost, isTrue);
    expect(derived.timeline[2]!.length, 2);
    expect(derived.timeline[4]!.ghost, isTrue);
    expect(derived.timeline[4]!.length, 1);
    expect(derived.timeline[5], const TimelineExposure.mark());
    expect(derived.timeline[8]!.ghost, isFalse);
    // Fully occluded is still a KEPT spec.
    expect(derived.repeatRegions, layer.repeatRegions);
  });

  test('a hold spilling past the span end pushes the ghosts out instead of '
      'overlapping it', () {
    // Block a@0 len5; the region was created when the span was 3 — the
    // hold has since grown past it.
    final layer = _layer(
      timeline: {0: _draw('a', 5)},
      regions: const [
        TimelineRepeatRegion(
          id: 'r1',
          anchorFrameId: FrameId('a'),
          sourceSpanFrames: 3,
          frameCount: 3,
        ),
      ],
    );

    final derived = rederiveRepeatRegions(layer);
    expect(derived.timeline[5]!.ghost, isTrue);
    expect(derived.timeline[5]!.length, 3);
    // The pattern clamps to the span (3 frames), not the block's 5.
  });

  test('stale ghosts from an edited-away region are stripped', () {
    // A layer whose timeline still carries ghosts but whose regions list
    // is empty (e.g. the region was deleted): rederive cleans up.
    final layer = _layer(
      timeline: {
        0: _draw('a', 2),
        2: const TimelineExposure.drawing(
          FrameId('a'),
          length: 2,
          ghost: true,
          repeatRegionId: 'gone',
        ),
      },
    );
    final derived = rederiveRepeatRegions(layer);
    expect(derived.timeline.length, 1);
    expect(derived.timeline[0]!.ghost, isFalse);
  });

  test('timelineIndexIsGhost covers ghost holds, not authored ones', () {
    final layer = rederiveRepeatRegions(
      _layer(
        timeline: {0: _draw('a', 2)},
        regions: const [
          TimelineRepeatRegion(
            id: 'r1',
            anchorFrameId: FrameId('a'),
            sourceSpanFrames: 2,
            frameCount: 4,
          ),
        ],
      ),
    );
    expect(timelineIndexIsGhost(layer, 0), isFalse);
    expect(timelineIndexIsGhost(layer, 1), isFalse);
    expect(timelineIndexIsGhost(layer, 2), isTrue); // ghost start
    expect(timelineIndexIsGhost(layer, 3), isTrue); // inside ghost hold
    expect(timelineIndexIsGhost(layer, 4), isTrue);
    expect(timelineIndexIsGhost(layer, 6), isFalse); // past the region
  });

  test('layer JSON round-trips regions and ghost entries', () {
    final layer = rederiveRepeatRegions(
      _layer(
        timeline: {0: _draw('a', 3)},
        regions: const [
          TimelineRepeatRegion(
            id: 'r1',
            anchorFrameId: FrameId('a'),
            sourceSpanFrames: 3,
            frameCount: 3,
          ),
        ],
      ),
    );
    final decoded = Layer.fromJson(layer.toJson());
    expect(decoded, layer);
    expect(decoded.repeatRegions.single.id, 'r1');
    expect(decoded.timeline[3]!.ghost, isTrue);
    expect(decoded.timeline[3]!.repeatRegionId, 'r1');
  });
}
