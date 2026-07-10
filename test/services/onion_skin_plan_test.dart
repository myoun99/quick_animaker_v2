import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/onion_skin_settings.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/services/onion_skin_plan.dart';

void main() {
  Frame frame(String id) =>
      Frame(id: FrameId(id), duration: 1, strokes: const []);

  /// A: [0,3) held, B: [3,5), A again (linked): [5,7), C: [8,10) — with an
  /// empty cell at 7.
  final layer = Layer(
    id: const LayerId('layer'),
    name: 'L',
    frames: [frame('a'), frame('b'), frame('c')],
    timeline: {
      0: const TimelineExposure.drawing(FrameId('a'), length: 3),
      3: const TimelineExposure.drawing(FrameId('b'), length: 2),
      5: const TimelineExposure.drawing(FrameId('a'), length: 2),
      8: const TimelineExposure.drawing(FrameId('c'), length: 2),
    },
  );

  const settings = OnionSkinSettings(
    enabled: true,
    beforePegs: [
      OnionPeg(enabled: true, opacity: 0.4),
      OnionPeg(enabled: true, opacity: 0.2),
    ],
    afterPegs: [OnionPeg(enabled: true, opacity: 0.3)],
  );

  test('pegs resolve UNIQUE drawings around the playhead, holds respected, '
      'linked repeats of the current cel skipped', () {
    // Playhead mid-B (frame 4): before = A (its block start, once — the
    // linked A at 5 is after); after = the linked A at 5? A is unique vs
    // current B, so after peg 1 = a.
    final plans = planOnionSkin(
      layer: layer,
      frameIndex: 4,
      settings: settings,
    );
    expect(plans.map((p) => p.frameId.value), ['a', 'a']);
    expect(plans.first.opacity, 0.4);
    expect(plans.first.tint, settings.tintBefore);
    expect(plans.last.opacity, 0.3);
    expect(plans.last.tint, settings.tintAfter);
  });

  test('a held playhead mid-block sees the PREVIOUS drawing, not its own '
      'block start; duplicates across the walk collapse', () {
    // Playhead at frame 6 (inside the linked-A block): current cel = a.
    // Before: b (frame 3); the a-block at 0 is SKIPPED (same cel as
    // current). After: c.
    final plans = planOnionSkin(
      layer: layer,
      frameIndex: 6,
      settings: settings,
    );
    expect(plans.map((p) => p.frameId.value), ['b', 'c']);
  });

  test('disabled pegs keep their slot (peg 2 stays two drawings back) and '
      'Images mode drops the tints', () {
    final plans = planOnionSkin(
      layer: layer,
      frameIndex: 8,
      settings: settings.copyWith(
        mode: OnionSkinMode.images,
        beforePegs: const [
          OnionPeg(enabled: false, opacity: 0.4),
          OnionPeg(enabled: true, opacity: 0.2),
        ],
        afterPegs: const [OnionPeg(enabled: true, opacity: 0.3)],
      ),
    );
    // At C: unique drawings before are a (5), b (3) — peg 1 (a) is off,
    // peg 2 = b shows; nothing after C.
    expect(plans.map((p) => p.frameId.value), ['b']);
    expect(plans.single.opacity, 0.2);
    expect(plans.single.tint, isNull);
  });

  test('disabled master or an empty timeline yields nothing', () {
    expect(
      planOnionSkin(
        layer: layer,
        frameIndex: 4,
        settings: settings.copyWith(enabled: false),
      ),
      isEmpty,
    );
    expect(
      planOnionSkin(
        layer: layer.copyWith(timeline: const {}, frames: const []),
        frameIndex: 4,
        settings: settings,
      ),
      isEmpty,
    );
  });

  test('an empty cell under the playhead still ghosts the neighbors', () {
    // Frame 7 is uncovered: before walks a(5) then b(3); after finds c.
    final plans = planOnionSkin(
      layer: layer,
      frameIndex: 7,
      settings: settings,
    );
    expect(plans.map((p) => p.frameId.value), ['b', 'a', 'c']);
    // Furthest-first paint order on the before side.
    expect(plans[0].opacity, 0.2);
    expect(plans[1].opacity, 0.4);
  });
}
