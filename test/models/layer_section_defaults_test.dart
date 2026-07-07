import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/layer_section_defaults.dart';

const _cutId = CutId('cut-a');

Layer _layer(String id, LayerKind kind, {String? name}) {
  return Layer(
    id: LayerId(id),
    name: name ?? id,
    frames: const [],
    timeline: const {},
    kind: kind,
  );
}

Cut _cut(List<Layer> layers) {
  return Cut(
    id: _cutId,
    name: 'Cut A',
    layers: layers,
    duration: 24,
    canvasSize: const CanvasSize(width: 100, height: 100),
  );
}

void main() {
  group('withEnsuredSectionLayers', () {
    test('backfills S1, S2 and CAM 1 before the camera layer', () {
      final layers = [
        _layer('cel', LayerKind.animation),
        _layer('cam', LayerKind.camera),
      ];

      final ensured = withEnsuredSectionLayers(_cutId, layers);

      expect(ensured.map((layer) => layer.kind), [
        LayerKind.animation,
        LayerKind.se,
        LayerKind.se,
        LayerKind.instruction,
        LayerKind.camera,
      ]);
      expect(ensured.map((layer) => layer.name), [
        'cel',
        'S1',
        'S2',
        'CAM 1',
        'cam',
      ]);
      expect(ensured[1].id, seLayerIdForCut(_cutId, 1));
      expect(ensured[3].id, instructionLayerIdForCut(_cutId));
    });

    test('tops up a single existing SE row to the floor of two', () {
      final layers = [
        _layer('cel', LayerKind.animation),
        _layer('voice', LayerKind.se),
        _layer('inst', LayerKind.instruction),
        _layer('cam', LayerKind.camera),
      ];

      final ensured = withEnsuredSectionLayers(_cutId, layers);

      expect(
        ensured.where((layer) => layer.kind == LayerKind.se),
        hasLength(2),
      );
      // Existing layers are untouched, in place.
      expect(ensured[1].id, const LayerId('voice'));
      expect(
        ensured.where((layer) => layer.kind == LayerKind.instruction),
        hasLength(1),
      );
    });

    test('returns the same list when floors are already met', () {
      final layers = [
        _layer('cel', LayerKind.animation),
        _layer('s1', LayerKind.se),
        _layer('s2', LayerKind.se),
        _layer('inst', LayerKind.instruction),
        _layer('cam', LayerKind.camera),
      ];

      expect(identical(withEnsuredSectionLayers(_cutId, layers), layers), true);
    });

    test('skips derived ids already taken and appends without a camera', () {
      final layers = [
        // A hostile file using the derived SE id for a plain cel.
        _layer('${_cutId.value}-se-1', LayerKind.animation),
      ];

      final ensured = withEnsuredSectionLayers(_cutId, layers);

      expect(
        ensured.where((layer) => layer.kind == LayerKind.se),
        hasLength(2),
      );
      expect(
        ensured.where((layer) => layer.kind == LayerKind.instruction),
        hasLength(1),
      );
      expect(ensured.map((layer) => layer.id).toSet(), hasLength(4));
    });
  });

  group('Cut.fromJson section fixtures', () {
    test('backfills missing SE/instruction rows on load', () {
      final legacy = _cut([
        _layer('cel', LayerKind.animation),
        _layer('cam', LayerKind.camera),
      ]);
      // Simulate a pre-fixture file: strip what the constructor would keep.
      final json = legacy.toJson();

      final loaded = Cut.fromJson(json);

      expect(loaded.layers.map((layer) => layer.kind), [
        LayerKind.animation,
        LayerKind.se,
        LayerKind.se,
        LayerKind.instruction,
        LayerKind.camera,
      ]);
    });

    test('round-trips unchanged once the fixtures exist', () {
      final loaded = Cut.fromJson(
        _cut([
          _layer('cel', LayerKind.animation),
          _layer('cam', LayerKind.camera),
        ]).toJson(),
      );

      final reloaded = Cut.fromJson(loaded.toJson());

      expect(reloaded, loaded);
    });
  });

  group('nextInstructionLayerName', () {
    test('skips names the cut already uses', () {
      expect(nextInstructionLayerName([]), 'CAM 1');
      expect(
        nextInstructionLayerName([
          _layer('a', LayerKind.instruction, name: 'CAM 1'),
          _layer('b', LayerKind.instruction, name: 'CAM 2'),
        ]),
        'CAM 3',
      );
    });
  });
}
