import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/cut_metadata.dart';

void main() {
  group('CutMetadata', () {
    test('empty metadata defaults to blank memo fields', () {
      const metadata = CutMetadata.empty();

      expect(metadata.actionMemo, '');
      expect(metadata.dialogueMemo, '');
      expect(metadata.note, '');
    });

    test('supports value equality', () {
      const metadata = CutMetadata(
        actionMemo: 'Character enters.',
        dialogueMemo: 'A: Wait!',
        note: 'Check expression.',
      );
      const sameMetadata = CutMetadata(
        actionMemo: 'Character enters.',
        dialogueMemo: 'A: Wait!',
        note: 'Check expression.',
      );
      const differentMetadata = CutMetadata(
        actionMemo: 'Character exits.',
        dialogueMemo: 'A: Wait!',
        note: 'Check expression.',
      );

      expect(metadata, sameMetadata);
      expect(metadata.hashCode, sameMetadata.hashCode);
      expect(metadata, isNot(differentMetadata));
    });

    test('serializes to JSON', () {
      const metadata = CutMetadata(
        actionMemo: 'Character enters.',
        dialogueMemo: 'A: Wait!',
        note: 'Check expression.',
      );

      expect(metadata.toJson(), {
        'actionMemo': 'Character enters.',
        'dialogueMemo': 'A: Wait!',
        'note': 'Check expression.',
      });
    });

    test('deserializes from JSON', () {
      final metadata = CutMetadata.fromJson({
        'actionMemo': 'Character exits.',
        'dialogueMemo': 'B: Too late.',
        'note': 'Use 3D reference.',
      });

      expect(
        metadata,
        const CutMetadata(
          actionMemo: 'Character exits.',
          dialogueMemo: 'B: Too late.',
          note: 'Use 3D reference.',
        ),
      );
    });

    test('copyWith changes only the requested field', () {
      const metadata = CutMetadata(
        actionMemo: 'Original action',
        dialogueMemo: 'Original dialogue',
        note: 'Original note',
      );

      expect(
        metadata.copyWith(actionMemo: 'Updated action'),
        const CutMetadata(
          actionMemo: 'Updated action',
          dialogueMemo: 'Original dialogue',
          note: 'Original note',
        ),
      );
      expect(
        metadata.copyWith(dialogueMemo: 'Updated dialogue'),
        const CutMetadata(
          actionMemo: 'Original action',
          dialogueMemo: 'Updated dialogue',
          note: 'Original note',
        ),
      );
      expect(
        metadata.copyWith(note: 'Updated note'),
        const CutMetadata(
          actionMemo: 'Original action',
          dialogueMemo: 'Original dialogue',
          note: 'Updated note',
        ),
      );
    });
  });

  group('Cut metadata', () {
    test('defaults to empty metadata', () {
      final cut = _cut();

      expect(cut.metadata, const CutMetadata.empty());
    });

    test('copyWith updates metadata and preserves other fields', () {
      final cut = _cut();
      const metadata = CutMetadata(
        actionMemo: 'Run in from screen right.',
        dialogueMemo: 'A: Wait!',
        note: 'FX-heavy cut.',
      );

      final updatedCut = cut.copyWith(metadata: metadata);

      expect(updatedCut.metadata, metadata);
      expect(updatedCut.id, cut.id);
      expect(updatedCut.name, cut.name);
      expect(updatedCut.layers, cut.layers);
      expect(updatedCut.duration, cut.duration);
      expect(updatedCut.canvasSize, cut.canvasSize);
    });

    test('round-trips non-empty metadata through JSON', () {
      final cut = _cut().copyWith(
        metadata: const CutMetadata(
          actionMemo: 'Run in from screen right.',
          dialogueMemo: 'A: Wait!',
          note: 'FX-heavy cut.',
        ),
      );

      final restoredCut = Cut.fromJson(cut.toJson());

      expect(restoredCut, cut);
      expect(restoredCut.metadata, cut.metadata);
    });

    test('fromJson defaults missing metadata to empty metadata', () {
      final json = _cut().toJson()..remove('metadata');

      final restoredCut = Cut.fromJson(json);

      expect(restoredCut.metadata, const CutMetadata.empty());
    });

    test('equality includes metadata', () {
      final cut = _cut();
      final cutWithMetadata = cut.copyWith(
        metadata: const CutMetadata(actionMemo: 'Camera shakes after impact.'),
      );

      expect(cutWithMetadata, isNot(cut));
      expect(
        cutWithMetadata,
        _cut().copyWith(
          metadata: const CutMetadata(actionMemo: 'Camera shakes after impact.'),
        ),
      );
    });
  });
}

Cut _cut() {
  return Cut(
    id: const CutId('cut-1'),
    name: 'Cut 1',
    layers: const [],
    duration: 24,
    canvasSize: const CanvasSize(width: 1920, height: 1080),
  );
}
