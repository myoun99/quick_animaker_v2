import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';

/// PEN-8 #2: drawing navigation walks BLOCKS where blocks exist and
/// falls back to ONE-FRAME steps through empty space — the plain-arrow/
/// 파라파라 unit never dead-ends.
void main() {
  EditorSessionManager sessionWithBlock() {
    final session = EditorSessionManager(
      initialProject: createDefaultProject(),
    );
    final cut = session.requireActiveCut;
    final layer = cut.layers.first;
    session.repository.replaceLayer(
      layer: layer.copyWith(
        frames: [
          Frame(id: const FrameId('nav-f1'), duration: 1, strokes: const []),
        ],
        timeline: {
          2: TimelineExposure.drawing(const FrameId('nav-f1'), length: 3),
        },
      ),
    );
    session.selectLayer(layer.id);
    return session;
  }

  test('next: jumps to the block start, then steps frames past the last '
      'block', () {
    final session = sessionWithBlock();
    addTearDown(session.dispose);

    session.selectFrameIndex(0);
    session.selectNextDrawing();
    expect(session.currentFrameIndex, 2, reason: 'jumps to the block');

    // Past the block there is no next drawing — empty space walks one
    // frame at a time.
    session.selectNextDrawing();
    expect(session.currentFrameIndex, 3);
    session.selectNextDrawing();
    expect(session.currentFrameIndex, 4);
  });

  test('previous: steps frames through empty space, then jumps to the '
      'block start', () {
    final session = sessionWithBlock();
    addTearDown(session.dispose);

    session.selectFrameIndex(7);
    session.selectPreviousDrawing();
    expect(session.currentFrameIndex, 2, reason: 'jumps back to the block');

    // Before the block there is no earlier drawing — empty space walks
    // one frame at a time (and clamps at 0).
    session.selectPreviousDrawing();
    expect(session.currentFrameIndex, 1);
    session.selectPreviousDrawing();
    expect(session.currentFrameIndex, 0);
    session.selectPreviousDrawing();
    expect(session.currentFrameIndex, 0, reason: 'clamped at the start');
  });
}
