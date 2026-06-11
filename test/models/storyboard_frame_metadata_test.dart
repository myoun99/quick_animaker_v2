import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/storyboard_frame_metadata.dart';

void main() {
  group('StoryboardFrameMetadata', () {
    test('empty metadata defaults all text fields to blank', () {
      const metadata = StoryboardFrameMetadata.empty();

      expect(metadata.actionMemo, '');
      expect(metadata.dialogueMemo, '');
      expect(metadata.note, '');
    });

    test('constructor defaults all text fields to blank', () {
      const metadata = StoryboardFrameMetadata();

      expect(metadata.actionMemo, '');
      expect(metadata.dialogueMemo, '');
      expect(metadata.note, '');
    });

    test('copyWith updates specified fields only', () {
      const metadata = StoryboardFrameMetadata(
        actionMemo: 'Run to the door.',
        dialogueMemo: 'A: Wait!',
        note: 'Hold for timing.',
      );

      expect(
        metadata.copyWith(actionMemo: 'Look back.'),
        const StoryboardFrameMetadata(
          actionMemo: 'Look back.',
          dialogueMemo: 'A: Wait!',
          note: 'Hold for timing.',
        ),
      );
      expect(
        metadata.copyWith(dialogueMemo: 'B: No time.', note: 'Add wind.'),
        const StoryboardFrameMetadata(
          actionMemo: 'Run to the door.',
          dialogueMemo: 'B: No time.',
          note: 'Add wind.',
        ),
      );
    });

    test('implements equality and hashCode', () {
      const metadata = StoryboardFrameMetadata(
        actionMemo: 'Run.',
        dialogueMemo: 'A: Go!',
        note: 'Fast pan.',
      );
      const sameMetadata = StoryboardFrameMetadata(
        actionMemo: 'Run.',
        dialogueMemo: 'A: Go!',
        note: 'Fast pan.',
      );

      expect(metadata, sameMetadata);
      expect(metadata.hashCode, sameMetadata.hashCode);
      expect(metadata, isNot(metadata.copyWith(actionMemo: 'Stop.')));
      expect(metadata, isNot(metadata.copyWith(dialogueMemo: 'B: Stop!')));
      expect(metadata, isNot(metadata.copyWith(note: 'Slow pan.')));
    });

    test('round-trips JSON', () {
      const metadata = StoryboardFrameMetadata(
        actionMemo: 'Character opens the box.',
        dialogueMemo: 'A: What is this?',
        note: 'Emphasize expression.',
      );

      expect(StoryboardFrameMetadata.fromJson(metadata.toJson()), metadata);
      expect(metadata.toJson(), {
        'actionMemo': 'Character opens the box.',
        'dialogueMemo': 'A: What is this?',
        'note': 'Emphasize expression.',
      });
    });

    test('fromJson defaults missing fields to blank', () {
      expect(
        StoryboardFrameMetadata.fromJson({'actionMemo': 'Look up.'}),
        const StoryboardFrameMetadata(actionMemo: 'Look up.'),
      );
      expect(
        StoryboardFrameMetadata.fromJson({'dialogueMemo': 'A: Huh?'}),
        const StoryboardFrameMetadata(dialogueMemo: 'A: Huh?'),
      );
      expect(
        StoryboardFrameMetadata.fromJson({'note': 'Quiet beat.'}),
        const StoryboardFrameMetadata(note: 'Quiet beat.'),
      );
      expect(
        StoryboardFrameMetadata.fromJson(const {}),
        const StoryboardFrameMetadata.empty(),
      );
    });
  });
}
