import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/storyboard_frame_metadata.dart';

void main() {
  group('Frame storyboardMetadata', () {
    test('defaults to empty metadata', () {
      final frame = _frame();

      expect(frame.storyboardMetadata, const StoryboardFrameMetadata.empty());
    });

    test('copyWith updates storyboardMetadata and preserves other fields', () {
      final frame = _frame(name: 'A');
      const metadata = StoryboardFrameMetadata(
        actionMemo: 'Open door.',
        dialogueMemo: 'A: Hello?',
        note: 'Slow movement.',
      );

      final updatedFrame = frame.copyWith(storyboardMetadata: metadata);

      expect(updatedFrame.storyboardMetadata, metadata);
      expect(updatedFrame.id, frame.id);
      expect(updatedFrame.duration, frame.duration);
      expect(updatedFrame.strokes, frame.strokes);
      expect(updatedFrame.name, frame.name);
    });

    test('equality and hashCode include storyboardMetadata', () {
      final frame = _frame();
      final frameWithMetadata = frame.copyWith(
        storyboardMetadata: const StoryboardFrameMetadata(
          actionMemo: 'Look right.',
        ),
      );
      final sameFrameWithMetadata = _frame().copyWith(
        storyboardMetadata: const StoryboardFrameMetadata(
          actionMemo: 'Look right.',
        ),
      );

      expect(frameWithMetadata, isNot(frame));
      expect(frameWithMetadata, sameFrameWithMetadata);
      expect(frameWithMetadata.hashCode, sameFrameWithMetadata.hashCode);
    });

    test('round-trips JSON with storyboardMetadata', () {
      final frame = _frame(name: 'A').copyWith(
        storyboardMetadata: const StoryboardFrameMetadata(
          actionMemo: 'Character sits down.',
          dialogueMemo: 'A: Finally.',
          note: 'Hold on chair creak.',
        ),
      );

      final restoredFrame = Frame.fromJson(frame.toJson());

      expect(restoredFrame, frame);
      expect(restoredFrame.storyboardMetadata, frame.storyboardMetadata);
    });

    test('fromJson defaults missing storyboardMetadata to empty metadata', () {
      final json = _frame().toJson()..remove('storyboardMetadata');

      final restoredFrame = Frame.fromJson(json);

      expect(
        restoredFrame.storyboardMetadata,
        const StoryboardFrameMetadata.empty(),
      );
    });
  });
}

Frame _frame({String? name}) {
  return Frame(
    id: const FrameId('frame-1'),
    duration: 3,
    strokes: const [],
    name: name,
  );
}
