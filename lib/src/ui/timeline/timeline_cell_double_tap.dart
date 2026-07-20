import '../../models/layer_id.dart';

/// R26 #37: the cell editor opens only when BOTH taps land on the SAME
/// cell.
///
/// Flutter's double-tap recognizer accepts a second tap anywhere within
/// ~100 logical pixels of the first, so tapping two neighbouring frames of
/// the same block (a normal "seek along the block" gesture) opened the
/// rename dialog. The recognizer cannot tell us where the FIRST tap was —
/// so the cell rows record it here and the activation gate compares.
///
/// Process-wide single slot on purpose: only one pointer sequence is ever
/// mid-double-tap, and the state must survive the widget rebuild the first
/// tap's own selection triggers (build-local capture would be wiped).
class TimelineCellDoubleTapGate {
  TimelineCellDoubleTapGate._();

  static LayerId? _layerId;
  static int? _frameIndex;

  /// Records a tap-down on ([layerId], [frameIndex]).
  static void recordTapDown(LayerId layerId, int frameIndex) {
    _layerId = layerId;
    _frameIndex = frameIndex;
  }

  /// Whether a double tap ending on ([layerId], [frameIndex]) may open the
  /// cell editor — true only when the PREVIOUS tap hit the same cell.
  ///
  /// Timing is deliberately NOT re-checked here: the double-tap recognizer
  /// already enforces its 300ms window, and a wall-clock guard would go
  /// flaky under load (a widget test's fake-clock pump can take seconds of
  /// real time). This gate answers "where", never "when". Consumes the
  /// record either way.
  static bool acceptsActivation(LayerId layerId, int frameIndex) {
    final sameCell = _layerId == layerId && _frameIndex == frameIndex;
    _layerId = null;
    _frameIndex = null;
    return sameCell;
  }

  /// Test seam: forgets any recorded tap.
  static void reset() {
    _layerId = null;
    _frameIndex = null;
  }
}
