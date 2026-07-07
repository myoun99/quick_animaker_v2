import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/camera_instruction.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';

void main() {
  group('CameraInstructionDef', () {
    test('round-trips through json, color optional', () {
      const plain = CameraInstructionDef(
        id: 'fi',
        name: 'FI',
        iconKey: 'fade-in',
      );
      const colored = CameraInstructionDef(
        id: 'custom',
        name: 'ブレ',
        iconKey: 'shake',
        colorValue: 0xFFE05A4E,
      );

      expect(CameraInstructionDef.fromJson(plain.toJson()), plain);
      expect(CameraInstructionDef.fromJson(colored.toJson()), colored);
      expect(plain.toJson().containsKey('color'), isFalse);
    });

    test('copyWith keeps the id and can clear the color', () {
      const def = CameraInstructionDef(
        id: 'fi',
        name: 'FI',
        iconKey: 'fade-in',
        colorValue: 0xFF112233,
      );

      final renamed = def.copyWith(name: 'FADE IN');
      expect(renamed.id, 'fi');
      expect(renamed.name, 'FADE IN');
      expect(renamed.colorValue, 0xFF112233);

      final cleared = def.copyWith(colorValue: () => null);
      expect(cleared.colorValue, isNull);
    });
  });

  group('CameraInstructionSet', () {
    test('rejects duplicate ids', () {
      expect(
        () => CameraInstructionSet(
          defs: const [
            CameraInstructionDef(id: 'fi', name: 'FI', iconKey: 'fade-in'),
            CameraInstructionDef(id: 'fi', name: 'FI 2', iconKey: 'fade-in'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('standard seed carries the 撮ま! vocabulary', () {
      final ids = CameraInstructionSet.standard.defs
          .map((def) => def.id)
          .toList();
      expect(
        ids,
        containsAll([
          'fix', 'pan', 'pan-up', 'pan-down', 'sl', 'follow', //
          'tu', 'tb', 'qtu', 'qtb', //
          'fi', 'fo', 'wi', 'wo', 'ol', 'wipe', //
          'si', 'df', 'fog',
        ]),
      );
      expect(CameraInstructionSet.standard.defById('ol')!.name, 'O.L');
      expect(CameraInstructionSet.standard.defById('missing'), isNull);
    });

    test('round-trips through json', () {
      final set = CameraInstructionSet(
        defs: const [
          CameraInstructionDef(id: 'fi', name: 'FI', iconKey: 'fade-in'),
          CameraInstructionDef(
            id: 'custom',
            name: 'メモリPAN',
            iconKey: 'pan',
            colorValue: 0xFF5B8DD9,
          ),
        ],
      );

      expect(CameraInstructionSet.fromJson(set.toJson()), set);
    });
  });

  group('InstructionEvent + coverage', () {
    test('round-trips through json, endpoint values optional', () {
      const bare = InstructionEvent(instructionId: 'fi', length: 12);
      const full = InstructionEvent(
        instructionId: 'pan',
        length: 24,
        valueA: 'A',
        valueB: 'B',
      );

      expect(InstructionEvent.fromJson(bare.toJson()), bare);
      expect(InstructionEvent.fromJson(full.toJson()), full);
      expect(bare.toJson().containsKey('valueA'), isFalse);
    });

    test('coverage validation rejects overlap and bad spans', () {
      expect(
        () => validateInstructionCoverage(
          SplayTreeMap.of({
            0: const InstructionEvent(instructionId: 'fi', length: 4),
            3: const InstructionEvent(instructionId: 'pan', length: 2),
          }),
        ),
        throwsArgumentError,
      );
      expect(
        () => validateInstructionCoverage(
          SplayTreeMap.of({
            0: const InstructionEvent(instructionId: 'fi', length: 0),
          }),
        ),
        throwsArgumentError,
      );
      expect(
        () => validateInstructionCoverage(
          SplayTreeMap.of({
            -1: const InstructionEvent(instructionId: 'fi', length: 1),
          }),
        ),
        throwsArgumentError,
      );

      // Adjacent spans are fine.
      validateInstructionCoverage(
        SplayTreeMap.of({
          0: const InstructionEvent(instructionId: 'fi', length: 4),
          4: const InstructionEvent(instructionId: 'pan', length: 2),
        }),
      );
    });
  });

  group('Layer.instructions', () {
    Layer instructionLayer(Map<int, InstructionEvent> instructions) {
      return Layer(
        id: const LayerId('cam-1'),
        name: 'CAM 1',
        kind: LayerKind.instruction,
        frames: const [],
        timeline: const {},
        instructions: instructions,
      );
    }

    test('serializes only when present and round-trips', () {
      final empty = instructionLayer(const {});
      expect(empty.toJson().containsKey('instructions'), isFalse);
      expect(Layer.fromJson(empty.toJson()), empty);

      final withSpans = instructionLayer({
        2: const InstructionEvent(
          instructionId: 'pan',
          length: 10,
          valueA: 'A',
          valueB: 'B',
        ),
        14: const InstructionEvent(instructionId: 'fo', length: 6),
      });
      final restored = Layer.fromJson(withSpans.toJson());
      expect(restored, withSpans);
      expect(restored.instructions[2]!.valueB, 'B');
    });

    test('instructions never leak into cel layer json or equality', () {
      final cel = Layer(
        id: const LayerId('cel'),
        name: 'A',
        frames: [
          Frame(id: const FrameId('f1'), duration: 1, strokes: const []),
        ],
        timeline: {0: const TimelineExposure.drawing(FrameId('f1'), length: 1)},
      );
      expect(cel.instructions, isEmpty);
      expect(cel.toJson().containsKey('instructions'), isFalse);
    });
  });

  group('Project.cameraInstructions', () {
    Project project({CameraInstructionSet? instructions}) {
      return Project(
        id: const ProjectId('p1'),
        name: 'P',
        tracks: const [],
        createdAt: DateTime.utc(2026, 7, 8),
        cameraInstructions: instructions,
      );
    }

    test('defaults to the standard seed, including json without the field', () {
      expect(project().cameraInstructions, CameraInstructionSet.standard);

      final json = project().toJson()..remove('cameraInstructions');
      expect(
        Project.fromJson(json).cameraInstructions,
        CameraInstructionSet.standard,
      );
    });

    test('a customized set round-trips', () {
      final custom = CameraInstructionSet(
        defs: [
          ...CameraInstructionSet.standard.defs,
          const CameraInstructionDef(
            id: 'custom-blur',
            name: 'ブレ',
            iconKey: 'shake',
          ),
        ],
      );
      final restored = Project.fromJson(project(instructions: custom).toJson());
      expect(restored.cameraInstructions, custom);
    });
  });
}
