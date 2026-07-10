import 'package:flutter/foundation.dart';

/// The imperative selection channel (P9): the app-level shortcuts
/// (Ctrl+D deselect, arrow nudges) call in; the mounted selection layer
/// binds the handlers. Unbound calls are no-ops and [hasSelection] is
/// false — the arrow keys then keep their frame-flipping meaning.
class CanvasSelectionCommands {
  bool Function()? _hasSelection;
  void Function(double dx, double dy)? _nudge;
  VoidCallback? _deselect;

  void bind({
    required bool Function() hasSelection,
    required void Function(double dx, double dy) nudge,
    required VoidCallback deselect,
  }) {
    _hasSelection = hasSelection;
    _nudge = nudge;
    _deselect = deselect;
  }

  void unbind() {
    _hasSelection = null;
    _nudge = null;
    _deselect = null;
  }

  /// Whether a live selection exists — arrow keys NUDGE instead of
  /// flipping frames while true (Photoshop arbitration).
  bool get hasSelection => _hasSelection?.call() ?? false;

  /// Moves the selection by canvas pixels (one undo entry per call).
  void nudge(double dx, double dy) => _nudge?.call(dx, dy);

  void deselect() => _deselect?.call();
}
