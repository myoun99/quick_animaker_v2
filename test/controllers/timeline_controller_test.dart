import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/timeline_controller.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure_type.dart';
import 'package:quick_animaker_v2/src/models/timeline_mark.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('TimelineController', () {
    test('starts at initial frame index', () {
      final fixture = _createFixture();

      expect(fixture.controller.currentFrameIndex, 0);
    });

    test('select frame index', () {
      final fixture = _createFixture();

      fixture.controller.selectFrameIndex(10);

      expect(fixture.controller.currentFrameIndex, 10);
    });

    test('reject negative frame index', () {
      final fixture = _createFixture();

      expect(
        () => fixture.controller.selectFrameIndex(-1),
        throwsArgumentError,
      );
    });

    test(
      'creating drawing outside cut duration stores data without extending duration',
      () {
        final fixture = _createFixture();

        fixture.controller.selectFrameIndex(45);
        fixture.controller.createDrawingFrameForLayer(
          layerId: const LayerId('empty-layer'),
          frameId: const FrameId('outside-duration-frame'),
        );

        final project = fixture.repository.requireProject();
        final cut = project.tracks.single.cuts.single;
        final layer = _findLayer(
          fixture.repository,
          const LayerId('empty-layer'),
        );

        expect(cut.duration, 1);
        expect(
          layer.timeline[45]?.frameId,
          const FrameId('outside-duration-frame'),
        );
        expect(
          fixture.controller.resolveFrameIdForLayer(
            layer: layer,
            frameIndex: 45,
          ),
          const FrameId('outside-duration-frame'),
        );
      },
    );

    test('last frame holds to visible timeline end', () {
      final fixture = _createFixture();
      final layer = _findLayer(
        fixture.repository,
        const LayerId('one-frame-layer'),
      );

      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 0),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 1),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 2),
        isTrue,
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 10),
        const FrameId('one-frame'),
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 10),
        isTrue,
      );
    });

    test('frame holds until next frame starts', () {
      final fixture = _createFixture();
      final layer = _findLayer(fixture.repository, const LayerId('layer-1'));

      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 0),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 2),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 3),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 4),
        const FrameId('frame-b'),
      );
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 4),
        isTrue,
      );
    });

    test('empty before first frame remains empty', () {
      final fixture = _createFixture();
      _createSparseFrame(
        fixture.controller,
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('late-frame'),
        startIndex: 5,
      );
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 0),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 1),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 4),
        isNull,
      );
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 5),
        isTrue,
      );
    });

    test('empty layer resolves null', () {
      final fixture = _createFixture();
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 0),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 10),
        isNull,
      );
    });

    test(
      'authored timeline extent uses max authored exposure length across layers',
      () {
        final fixture = _createFixture();

        expect(fixture.controller.authoredTimelineExtentFrameCount, 7);
      },
    );

    test('create drawing frame creates one sparse frame and holds forward', () {
      final fixture = _createFixture();
      fixture.controller.selectFrameIndex(10);

      fixture.controller.createDrawingFrameForLayer(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('new-frame'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(layer.frames, hasLength(1));
      expect(layer.frames.single.id, const FrameId('new-frame'));
      expect(layer.frames.single.duration, 1);
      for (var frameIndex = 0; frameIndex < 10; frameIndex += 1) {
        expect(
          fixture.controller.resolveFrameForLayer(
            layer: layer,
            frameIndex: frameIndex,
          ),
          isNull,
        );
      }
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 10),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 11),
        isTrue,
      );
    });

    test('create drawing frame replaces a blank head exposure', () {
      final fixture = _createFixture(
        extraLayers: [
          Layer(
            id: const LayerId('blank-layer'),
            name: 'Blank Layer',
            frames: const [],
            timeline: const {0: TimelineExposure.blank()},
          ),
        ],
      );

      fixture.controller.createDrawingFrameForLayer(
        layerId: const LayerId('blank-layer'),
        frameId: const FrameId('blank-replacement'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('blank-layer'),
      );
      expect(layer.frames, hasLength(1));
      expect(layer.timeline, hasLength(1));
      expect(layer.timeline[0]?.type, TimelineExposureType.drawing);
      expect(layer.timeline[0]?.frameId, const FrameId('blank-replacement'));
    });

    test(
      'create drawing frame inside blank hold adds sparse drawing entry',
      () {
        final fixture = _createFixture(
          extraLayers: [
            Layer(
              id: const LayerId('blank-layer'),
              name: 'Blank Layer',
              frames: const [],
              timeline: const {0: TimelineExposure.blank()},
            ),
          ],
        );
        fixture.controller.selectFrameIndex(5);

        fixture.controller.createDrawingFrameForLayer(
          layerId: const LayerId('blank-layer'),
          frameId: const FrameId('inside-blank-hold'),
        );

        final layer = _findLayer(
          fixture.repository,
          const LayerId('blank-layer'),
        );
        expect(layer.frames, hasLength(1));
        expect(layer.timeline.keys, orderedEquals([0, 5]));
        expect(layer.timeline[0]?.type, TimelineExposureType.blank);
        expect(layer.timeline[5]?.frameId, const FrameId('inside-blank-hold'));
      },
    );

    test('blank creation is disabled for null and blank regions', () {
      final fixture = _createFixture();
      final emptyLayer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(
        fixture.controller.canCreateBlankAt(layer: emptyLayer, frameIndex: 0),
        isFalse,
      );

      final blankLayer = Layer(
        id: const LayerId('blank-layer'),
        name: 'Blank Layer',
        frames: const [],
        timeline: const {5: TimelineExposure.blank()},
      );
      expect(
        fixture.controller.canCreateBlankAt(layer: blankLayer, frameIndex: 5),
        isFalse,
      );
      expect(
        fixture.controller.canCreateBlankAt(layer: blankLayer, frameIndex: 6),
        isFalse,
      );
    });

    test('detects drawing starts and held exposures', () {
      final fixture = _createFixture();
      final layer = _findLayer(
        fixture.repository,
        const LayerId('exposure-layer'),
      );

      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 0),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 1),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 2),
        isTrue,
      );
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 3),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 4),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 5),
        isTrue,
      );
    });

    test('held exposure is false for drawing starts and empty cells', () {
      final fixture = _createFixture();
      _createSparseFrame(
        fixture.controller,
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('late-frame'),
        startIndex: 5,
      );
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 0),
        isFalse,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 4),
        isFalse,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 5),
        isFalse,
      );
    });

    test('effective duration spans to the next drawing frame start', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [_FrameSpec(FrameId('a'), 0, 1), _FrameSpec(FrameId('b'), 6, 1)],
      );
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.effectiveDurationForLayerFrame(
          layer: layer,
          frameId: const FrameId('a'),
        ),
        6,
      );
    });

    test('increase exposure uses effective duration immediately', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [_FrameSpec(FrameId('a'), 0, 1), _FrameSpec(FrameId('b'), 6, 1)],
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        7,
      );
    });

    test('decrease exposure uses effective duration immediately', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [_FrameSpec(FrameId('a'), 0, 1), _FrameSpec(FrameId('b'), 6, 1)],
      );

      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(_findFrame(layer, const FrameId('a')).duration, 1);
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        5,
      );
    });

    test('decrease exposure does not go below effective duration one', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [_FrameSpec(FrameId('a'), 0, 1), _FrameSpec(FrameId('b'), 1, 1)],
      );

      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        1,
      );
      expect(
        fixture.controller.effectiveDurationForLayerFrame(
          layer: layer,
          frameId: const FrameId('a'),
        ),
        1,
      );
    });

    test('increase exposure pushes directly adjacent following blocks', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 2),
          _FrameSpec(FrameId('b'), 2, 2),
          _FrameSpec(FrameId('c'), 4, 1),
        ],
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(_findFrame(layer, const FrameId('a')).duration, 3);
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        3,
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('c'),
        ),
        5,
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 0),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 2),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 3),
        const FrameId('b'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 5),
        const FrameId('c'),
      );
    });

    test(
      'increase exposure does not move authored gaps after the next block',
      () {
        final fixture = _createFixture();
        _createSparseBlock(
          fixture.controller,
          const LayerId('empty-layer'),
          const [
            _FrameSpec(FrameId('a'), 0, 1),
            _FrameSpec(FrameId('b'), 6, 1),
            _FrameSpec(FrameId('c'), 10, 1),
          ],
        );

        fixture.controller.increaseExposure(
          layerId: const LayerId('empty-layer'),
          frameId: const FrameId('a'),
        );

        final layer = _findLayer(
          fixture.repository,
          const LayerId('empty-layer'),
        );
        expect(
          fixture.controller.exposureStartIndexForLayer(
            layer: layer,
            frameId: const FrameId('b'),
          ),
          7,
        );
        expect(
          fixture.controller.exposureStartIndexForLayer(
            layer: layer,
            frameId: const FrameId('c'),
          ),
          10,
        );
      },
    );

    test('decrease exposure pulls directly adjacent following blocks', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 3),
          _FrameSpec(FrameId('b'), 3, 2),
          _FrameSpec(FrameId('c'), 5, 1),
        ],
      );

      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(_findFrame(layer, const FrameId('a')).duration, 2);
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        2,
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('c'),
        ),
        4,
      );
    });

    test(
      'decrease exposure does not move authored gaps after the next block',
      () {
        final fixture = _createFixture();
        _createSparseBlock(
          fixture.controller,
          const LayerId('empty-layer'),
          const [
            _FrameSpec(FrameId('a'), 0, 1),
            _FrameSpec(FrameId('b'), 6, 1),
            _FrameSpec(FrameId('c'), 10, 1),
          ],
        );

        fixture.controller.decreaseExposure(
          layerId: const LayerId('empty-layer'),
          frameId: const FrameId('a'),
        );

        final layer = _findLayer(
          fixture.repository,
          const LayerId('empty-layer'),
        );
        expect(
          fixture.controller.exposureStartIndexForLayer(
            layer: layer,
            frameId: const FrameId('b'),
          ),
          5,
        );
        expect(
          fixture.controller.exposureStartIndexForLayer(
            layer: layer,
            frameId: const FrameId('c'),
          ),
          10,
        );
      },
    );

    test(
      'decrease exposure does not go below one or move following frames',
      () {
        final fixture = _createFixture();
        _createSparseBlock(
          fixture.controller,
          const LayerId('empty-layer'),
          const [
            _FrameSpec(FrameId('a'), 0, 1),
            _FrameSpec(FrameId('b'), 1, 2),
          ],
        );

        fixture.controller.decreaseExposure(
          layerId: const LayerId('empty-layer'),
          frameId: const FrameId('a'),
        );

        final layer = _findLayer(
          fixture.repository,
          const LayerId('empty-layer'),
        );
        expect(_findFrame(layer, const FrameId('a')).duration, 1);
        expect(
          fixture.controller.exposureStartIndexForLayer(
            layer: layer,
            frameId: const FrameId('b'),
          ),
          1,
        );
      },
    );

    test(
      'linked exposure increase targets selected authored entry by frame index',
      () {
        final fixture = _createFixture(
          extraLayers: [
            Layer(
              id: const LayerId('linked-layer'),
              name: 'Linked Layer',
              frames: [
                Frame(id: const FrameId('a'), duration: 4, strokes: const []),
              ],
              timeline: {
                0: TimelineExposure.drawing(const FrameId('a')),
                4: const TimelineExposure.blank(),
                8: TimelineExposure.drawing(const FrameId('a')),
              },
            ),
          ],
        );
        fixture.controller.selectFrameIndex(8);

        fixture.controller.increaseExposure(
          layerId: const LayerId('linked-layer'),
        );

        final layer = _findLayer(
          fixture.repository,
          const LayerId('linked-layer'),
        );
        expect(layer.timeline.keys, orderedEquals([0, 4, 8]));
        expect(
          fixture.controller.effectiveDurationForLayerFrame(
            layer: layer,
            frameId: const FrameId('a'),
          ),
          4,
        );
        expect(
          fixture.controller.effectiveDurationForLayerAt(
            layer: layer,
            frameIndex: 8,
          ),
          4,
        );
        expect(_findFrame(layer, const FrameId('a')).duration, 4);
        expect(
          fixture.controller.linkedUseCountForLayerFrame(
            layer: layer,
            frameId: const FrameId('a'),
          ),
          2,
        );
      },
    );

    test(
      'linked exposure duration display resolves selected authored entry',
      () {
        final fixture = _createFixture(
          extraLayers: [
            Layer(
              id: const LayerId('linked-duration-layer'),
              name: 'Linked Duration Layer',
              frames: [
                Frame(id: const FrameId('a'), duration: 4, strokes: const []),
                Frame(id: const FrameId('b'), duration: 1, strokes: const []),
              ],
              timeline: {
                0: TimelineExposure.drawing(const FrameId('a')),
                4: const TimelineExposure.blank(),
                8: TimelineExposure.drawing(const FrameId('a')),
                10: TimelineExposure.drawing(const FrameId('b')),
              },
            ),
          ],
        );
        final layer = _findLayer(
          fixture.repository,
          const LayerId('linked-duration-layer'),
        );

        expect(
          fixture.controller.effectiveDurationForLayerFrame(
            layer: layer,
            frameId: const FrameId('a'),
          ),
          4,
        );
        expect(
          fixture.controller.effectiveDurationForLayerAt(
            layer: layer,
            frameIndex: 8,
          ),
          2,
        );
      },
    );

    test('dense frame duplication is not introduced', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 2),
          _FrameSpec(FrameId('b'), 2, 2),
          _FrameSpec(FrameId('c'), 4, 1),
        ],
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );
      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );
      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('b'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(layer.frames, hasLength(3));
    });

    test('increase exposure updates duration without creating frames', () {
      final fixture = _createFixture();

      fixture.controller.increaseExposure(
        layerId: const LayerId('one-frame-layer'),
        frameId: const FrameId('one-frame'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('one-frame-layer'),
      );
      expect(layer.frames, hasLength(1));
      expect(layer.frames.single.duration, 2);
    });

    test('decrease exposure lowers duration', () {
      final fixture = _createFixture();

      fixture.controller.decreaseExposure(
        layerId: const LayerId('layer-1'),
        frameId: const FrameId('frame-a'),
      );

      final layer = _findLayer(fixture.repository, const LayerId('layer-1'));
      expect(layer.frames.first.duration, 3);
    });

    test('exposure editing throws clear errors for missing layer or frame', () {
      final fixture = _createFixture();

      expect(
        () => fixture.controller.increaseExposure(
          layerId: const LayerId('missing-layer'),
          frameId: const FrameId('frame-a'),
        ),
        throwsStateError,
      );
      expect(
        () => fixture.controller.decreaseExposure(
          layerId: const LayerId('layer-1'),
          frameId: const FrameId('missing-frame'),
        ),
        throwsStateError,
      );
    });

    test('duration less than one is treated as one for resolution', () {
      final layer = Layer(
        id: const LayerId('duration-layer'),
        name: 'Duration Layer',
        frames: [
          Frame(id: const FrameId('zero'), duration: 0, strokes: const []),
        ],
      );
      final fixture = _createFixture();

      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 0),
        const FrameId('zero'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('zero'),
      );
    });

    test('create drawing frame rejects invalid duration', () {
      final fixture = _createFixture();

      expect(
        () => fixture.controller.createDrawingFrameForLayer(
          layerId: const LayerId('layer-1'),
          frameId: const FrameId('invalid'),
          duration: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rename to unique name and empty name update selected material', () {
      final fixture = _createFixture();

      fixture.controller.renameFrameForLayer(
        layerId: const LayerId('layer-1'),
        frameId: const FrameId('frame-a'),
        name: '  A1  ',
      );
      var layer = _findLayer(fixture.repository, const LayerId('layer-1'));
      expect(_findFrame(layer, const FrameId('frame-a')).name, 'A1');

      fixture.controller.renameFrameForLayer(
        layerId: const LayerId('layer-1'),
        frameId: const FrameId('frame-a'),
        name: '   ',
      );
      layer = _findLayer(fixture.repository, const LayerId('layer-1'));
      expect(_findFrame(layer, const FrameId('frame-a')).name, isNull);
    });

    test('same-name rename on same FrameId has no conflict', () {
      final fixture = _createFixture();

      fixture.controller.renameFrameForLayer(
        layerId: const LayerId('layer-1'),
        frameId: const FrameId('frame-a'),
        name: 'A1',
      );
      final layer = _findLayer(fixture.repository, const LayerId('layer-1'));

      expect(
        fixture.controller.conflictingFrameIdForRename(
          layer: layer,
          frameId: const FrameId('frame-a'),
          name: 'A1',
        ),
        isNull,
      );
    });

    test(
      'rename to existing same-layer name is detected and not duplicated',
      () {
        final fixture = _createFixture();

        fixture.controller.renameFrameForLayer(
          layerId: const LayerId('layer-1'),
          frameId: const FrameId('frame-a'),
          name: 'A1',
        );
        fixture.controller.renameFrameForLayer(
          layerId: const LayerId('layer-1'),
          frameId: const FrameId('frame-b'),
          name: 'A1',
        );

        final layer = _findLayer(fixture.repository, const LayerId('layer-1'));
        expect(
          fixture.controller.conflictingFrameIdForRename(
            layer: layer,
            frameId: const FrameId('frame-b'),
            name: 'A1',
          ),
          const FrameId('frame-a'),
        );
        expect(_findFrame(layer, const FrameId('frame-a')).name, 'A1');
        expect(_findFrame(layer, const FrameId('frame-b')).name, isNull);
      },
    );

    test(
      'link frame replaces source timeline references and preserves marks',
      () {
        final fixture = _createFixture(
          extraLayers: [
            Layer(
              id: const LayerId('link-layer'),
              name: 'Link Layer',
              frames: [
                Frame(
                  id: const FrameId('target'),
                  duration: 2,
                  strokes: const [],
                  name: 'A1',
                ),
                Frame(
                  id: const FrameId('source'),
                  duration: 3,
                  strokes: const [],
                  name: 'B1',
                ),
              ],
              timeline: {
                0: TimelineExposure.drawing(const FrameId('target')),
                2: const TimelineExposure.blank(),
                5: TimelineExposure.drawing(const FrameId('source')),
                9: TimelineExposure.drawing(const FrameId('source')),
              },
              marks: const {
                2: TimelineMark.inbetween(),
                5: TimelineMark.inbetween(),
              },
            ),
          ],
        );

        fixture.controller.linkFrameForLayer(
          layerId: const LayerId('link-layer'),
          sourceFrameId: const FrameId('source'),
          targetFrameId: const FrameId('target'),
        );

        final layer = _findLayer(
          fixture.repository,
          const LayerId('link-layer'),
        );
        expect(layer.timeline.keys, orderedEquals([0, 2, 5, 9]));
        expect(layer.timeline[0]?.frameId, const FrameId('target'));
        expect(layer.timeline[2]?.type, TimelineExposureType.blank);
        expect(layer.timeline[5]?.frameId, const FrameId('target'));
        expect(layer.timeline[9]?.frameId, const FrameId('target'));
        expect(layer.marks.keys, orderedEquals([2, 5]));
        expect(layer.frames.map((frame) => frame.id), [
          const FrameId('target'),
        ]);
        expect(layer.frames.single.strokes, isEmpty);
        expect(
          fixture.controller.linkedUseCountForLayerFrame(
            layer: layer,
            frameId: const FrameId('target'),
          ),
          3,
        );
      },
    );

    test('link frame is undo and redo-able', () {
      final historyManager = HistoryManager();
      final fixture = _createFixture(
        historyManager: historyManager,
        extraLayers: [
          Layer(
            id: const LayerId('undo-link-layer'),
            name: 'Undo Link Layer',
            frames: [
              Frame(
                id: const FrameId('target'),
                duration: 1,
                strokes: const [],
              ),
              Frame(
                id: const FrameId('source'),
                duration: 1,
                strokes: const [],
              ),
            ],
            timeline: {
              0: TimelineExposure.drawing(const FrameId('target')),
              1: TimelineExposure.drawing(const FrameId('source')),
            },
          ),
        ],
      );

      fixture.controller.linkFrameForLayer(
        layerId: const LayerId('undo-link-layer'),
        sourceFrameId: const FrameId('source'),
        targetFrameId: const FrameId('target'),
      );
      var layer = _findLayer(
        fixture.repository,
        const LayerId('undo-link-layer'),
      );
      expect(layer.timeline[1]?.frameId, const FrameId('target'));
      expect(layer.frames.map((frame) => frame.id), [const FrameId('target')]);

      historyManager.undo();
      layer = _findLayer(fixture.repository, const LayerId('undo-link-layer'));
      expect(layer.timeline[1]?.frameId, const FrameId('source'));
      expect(layer.frames.map((frame) => frame.id), [
        const FrameId('target'),
        const FrameId('source'),
      ]);

      historyManager.redo();
      layer = _findLayer(fixture.repository, const LayerId('undo-link-layer'));
      expect(layer.timeline[1]?.frameId, const FrameId('target'));
      expect(layer.frames.map((frame) => frame.id), [const FrameId('target')]);
    });

    group('active cut isolation', () {
      test('cut-a controller resolves timeline state from Cut A', () {
        final fixture = _createTwoCutFixture(const CutId('cut-a'));
        final layerA = _findLayerInCut(
          fixture.repository,
          const CutId('cut-a'),
          const LayerId('layer-a'),
        );

        expect(fixture.controller.authoredTimelineExtentFrameCount, 4);
        expect(
          fixture.controller.resolveFrameIdForLayer(
            layer: layerA,
            frameIndex: 0,
          ),
          const FrameId('frame-a'),
        );
        expect(
          fixture.controller
              .resolveFrameForLayer(layer: layerA, frameIndex: 0)
              ?.name,
          'Frame A',
        );
      });

      test('cut-b controller resolves timeline state from Cut B', () {
        final fixture = _createTwoCutFixture(const CutId('cut-b'));
        final layerB = _findLayerInCut(
          fixture.repository,
          const CutId('cut-b'),
          const LayerId('layer-b'),
        );

        expect(fixture.controller.authoredTimelineExtentFrameCount, 2);
        expect(
          fixture.controller.resolveFrameIdForLayer(
            layer: layerB,
            frameIndex: 0,
          ),
          const FrameId('frame-b'),
        );
        expect(
          fixture.controller
              .resolveFrameForLayer(layer: layerB, frameIndex: 0)
              ?.name,
          'Frame B',
        );
      });

      test('creating a drawing frame through cut-a updates Cut A only', () {
        final fixture = _createTwoCutFixture(const CutId('cut-a'));

        fixture.controller.selectFrameIndex(5);
        fixture.controller.createDrawingFrameForLayer(
          layerId: const LayerId('layer-a'),
          frameId: const FrameId('frame-a-new'),
        );

        final layerA = _findLayerInCut(
          fixture.repository,
          const CutId('cut-a'),
          const LayerId('layer-a'),
        );
        final layerB = _findLayerInCut(
          fixture.repository,
          const CutId('cut-b'),
          const LayerId('layer-b'),
        );
        expect(layerA.frames.map((frame) => frame.id), [
          const FrameId('frame-a'),
          const FrameId('frame-a-new'),
        ]);
        expect(layerA.timeline[5]?.frameId, const FrameId('frame-a-new'));
        expect(layerB.frames.map((frame) => frame.id), [
          const FrameId('frame-b'),
        ]);
        expect(layerB.timeline.keys, orderedEquals([0]));
      });

      test('creating a blank exposure through cut-b updates Cut B only', () {
        final fixture = _createTwoCutFixture(const CutId('cut-b'));

        fixture.controller.selectFrameIndex(1);
        fixture.controller.createBlankExposureForLayer(
          layerId: const LayerId('layer-b'),
        );

        final layerA = _findLayerInCut(
          fixture.repository,
          const CutId('cut-a'),
          const LayerId('layer-a'),
        );
        final layerB = _findLayerInCut(
          fixture.repository,
          const CutId('cut-b'),
          const LayerId('layer-b'),
        );
        expect(layerA.timeline.keys, orderedEquals([0]));
        expect(layerA.timeline[0]?.frameId, const FrameId('frame-a'));
        expect(layerB.timeline.keys, orderedEquals([0, 1]));
        expect(layerB.timeline[1]?.type, TimelineExposureType.blank);
      });
    });
  });
}

const _cutId = CutId('cut-1');

_TimelineFixture _createFixture({
  List<Layer> extraLayers = const [],
  HistoryManager? historyManager,
}) {
  final repository = ProjectRepository(
    initialProject: _createSampleProject(extraLayers: extraLayers),
  );
  final controller = TimelineController(
    repository: repository,
    historyManager: historyManager,
    cutId: _cutId,
  );
  return _TimelineFixture(repository: repository, controller: controller);
}

void _createSparseBlock(
  TimelineController controller,
  LayerId layerId,
  List<_FrameSpec> specs,
) {
  for (final spec in specs) {
    _createSparseFrame(
      controller,
      layerId: layerId,
      frameId: spec.frameId,
      startIndex: spec.startIndex,
      duration: spec.duration,
    );
  }
}

void _createSparseFrame(
  TimelineController controller, {
  required LayerId layerId,
  required FrameId frameId,
  required int startIndex,
  int duration = 1,
}) {
  controller.selectFrameIndex(startIndex);
  controller.createDrawingFrameForLayer(
    layerId: layerId,
    frameId: frameId,
    duration: duration,
  );
}

Project _createSampleProject({List<Layer> extraLayers = const []}) {
  return Project(
    id: const ProjectId('project-1'),
    name: 'Test Project',
    createdAt: DateTime.utc(2026),
    tracks: [
      Track(
        id: const TrackId('track-1'),
        name: 'Track 1',
        cuts: [
          Cut(
            id: _cutId,
            name: 'Cut 1',
            duration: 1,
            canvasSize: const CanvasSize(width: 100, height: 100),
            layers: [
              Layer(
                id: const LayerId('layer-1'),
                name: 'Layer 1',
                frames: [
                  Frame(
                    id: const FrameId('frame-a'),
                    duration: 4,
                    strokes: const [],
                  ),
                  Frame(
                    id: const FrameId('frame-b'),
                    duration: 3,
                    strokes: const [],
                  ),
                ],
              ),
              Layer(
                id: const LayerId('exposure-layer'),
                name: 'Exposure Layer',
                frames: [
                  Frame(
                    id: const FrameId('exposure-a'),
                    duration: 3,
                    strokes: const [],
                  ),
                  Frame(
                    id: const FrameId('exposure-b'),
                    duration: 2,
                    strokes: const [],
                  ),
                ],
              ),
              Layer(
                id: const LayerId('empty-layer'),
                name: 'Empty Layer',
                frames: const [],
              ),
              Layer(
                id: const LayerId('short-layer'),
                name: 'Short Layer',
                frames: [
                  Frame(
                    id: const FrameId('short-frame'),
                    duration: 2,
                    strokes: const [],
                  ),
                ],
              ),
              Layer(
                id: const LayerId('one-frame-layer'),
                name: 'One Frame Layer',
                frames: [
                  Frame(
                    id: const FrameId('one-frame'),
                    duration: 1,
                    strokes: const [],
                  ),
                ],
              ),
              ...extraLayers,
            ],
          ),
        ],
      ),
    ],
  );
}

Layer _findLayer(ProjectRepository repository, LayerId layerId) {
  for (final track in repository.requireProject().tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        if (layer.id == layerId) {
          return layer;
        }
      }
    }
  }

  throw StateError('Layer not found.');
}

Frame _findFrame(Layer layer, FrameId frameId) {
  for (final frame in layer.frames) {
    if (frame.id == frameId) {
      return frame;
    }
  }

  throw StateError('Frame not found.');
}

class _FrameSpec {
  const _FrameSpec(this.frameId, this.startIndex, this.duration);

  final FrameId frameId;
  final int startIndex;
  final int duration;
}

class _TimelineFixture {
  const _TimelineFixture({required this.repository, required this.controller});

  final ProjectRepository repository;
  final TimelineController controller;
}

_TimelineFixture _createTwoCutFixture(CutId cutId) {
  final repository = ProjectRepository(initialProject: _createTwoCutProject());
  final controller = TimelineController(repository: repository, cutId: cutId);
  return _TimelineFixture(repository: repository, controller: controller);
}

Project _createTwoCutProject() {
  return Project(
    id: const ProjectId('two-cut-project'),
    name: 'Two Cut Test Project',
    createdAt: DateTime.utc(2026),
    tracks: [
      Track(
        id: const TrackId('track-1'),
        name: 'Track 1',
        cuts: [
          Cut(
            id: const CutId('cut-a'),
            name: 'Cut A',
            duration: 12,
            canvasSize: const CanvasSize(width: 100, height: 100),
            layers: [
              Layer(
                id: const LayerId('layer-a'),
                name: 'Layer A',
                frames: [
                  Frame(
                    id: const FrameId('frame-a'),
                    duration: 4,
                    strokes: const [],
                    name: 'Frame A',
                  ),
                ],
                timeline: {
                  0: TimelineExposure.drawing(const FrameId('frame-a')),
                },
              ),
            ],
          ),
          Cut(
            id: const CutId('cut-b'),
            name: 'Cut B',
            duration: 8,
            canvasSize: const CanvasSize(width: 100, height: 100),
            layers: [
              Layer(
                id: const LayerId('layer-b'),
                name: 'Layer B',
                frames: [
                  Frame(
                    id: const FrameId('frame-b'),
                    duration: 2,
                    strokes: const [],
                    name: 'Frame B',
                  ),
                ],
                timeline: {
                  0: TimelineExposure.drawing(const FrameId('frame-b')),
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Layer _findLayerInCut(
  ProjectRepository repository,
  CutId cutId,
  LayerId layerId,
) {
  for (final track in repository.requireProject().tracks) {
    for (final cut in track.cuts) {
      if (cut.id != cutId) {
        continue;
      }
      for (final layer in cut.layers) {
        if (layer.id == layerId) {
          return layer;
        }
      }
    }
  }

  throw StateError('Layer not found in cut.');
}
