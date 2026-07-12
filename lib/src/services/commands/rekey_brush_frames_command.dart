import '../../models/brush_frame_key.dart';
import '../brush_frame_store.dart';
import '../command.dart';

/// Re-homes brush drawings to new store keys — the brush-store half of a
/// cross-layer block move (R10-④b), composed with the layer timeline
/// updates into one undo step. Undo replays the pairs reversed, so the
/// drawings land back under their original keys.
class RekeyBrushFramesCommand implements Command {
  RekeyBrushFramesCommand({required this.store, required this.pairs});

  final BrushFrameStore store;
  final List<(BrushFrameKey from, BrushFrameKey to)> pairs;

  @override
  String get description => 'Rekey ${pairs.length} brush frame(s)';

  @override
  void execute() {
    store.rekeyFrames(pairs);
  }

  @override
  void undo() {
    store.rekeyFrames([for (final (from, to) in pairs) (to, from)]);
  }
}
