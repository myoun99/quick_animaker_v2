import 'package:flutter/foundation.dart';

import '../../services/canvas_selection.dart';

/// The imperative selection channel (P9): the app-level shortcuts
/// (Ctrl+D deselect, arrow nudges) call in; the mounted selection layer
/// binds the handlers. Unbound calls are no-ops and [hasSelection] is
/// false — the arrow keys then keep their frame-flipping meaning.
class CanvasSelectionCommands {
  bool Function()? _hasSelection;
  void Function(double dx, double dy)? _nudge;
  VoidCallback? _deselect;
  bool Function()? _transformActive;
  VoidCallback? _beginTransform;
  VoidCallback? _commitTransform;
  VoidCallback? _cancelTransform;
  void Function(CanvasSelectionShape? shape)? _applyShape;

  void bind({
    required bool Function() hasSelection,
    required void Function(double dx, double dy) nudge,
    required VoidCallback deselect,
    bool Function()? transformActive,
    VoidCallback? beginTransform,
    VoidCallback? commitTransform,
    VoidCallback? cancelTransform,
    void Function(CanvasSelectionShape? shape)? applyShape,
  }) {
    _hasSelection = hasSelection;
    _nudge = nudge;
    _deselect = deselect;
    _transformActive = transformActive;
    _beginTransform = beginTransform;
    _commitTransform = commitTransform;
    _cancelTransform = cancelTransform;
    _applyShape = applyShape;
  }

  void unbind() {
    _hasSelection = null;
    _nudge = null;
    _deselect = null;
    _transformActive = null;
    _beginTransform = null;
    _commitTransform = null;
    _cancelTransform = null;
    _applyShape = null;
  }

  /// Pushes a committed region into the mounted layer — the
  /// selection-shape history command's execute/undo path (R11-⑧). A no-op
  /// while no selection layer is mounted (view state simply skips).
  void applyShape(CanvasSelectionShape? shape) => _applyShape?.call(shape);

  /// Whether a live selection exists — arrow keys NUDGE instead of
  /// flipping frames while true (Photoshop arbitration).
  bool get hasSelection => _hasSelection?.call() ?? false;

  /// Moves the selection by canvas pixels (one undo entry per call).
  void nudge(double dx, double dy) => _nudge?.call(dx, dy);

  void deselect() => _deselect?.call();

  /// Whether a Ctrl+T free-transform session is open (Enter/Escape then
  /// commit/cancel it instead of their usual meanings).
  bool get transformActive => _transformActive?.call() ?? false;

  /// Ctrl+T: opens the free-transform box on the live selection.
  void beginTransform() => _beginTransform?.call();

  /// Enter: commits the open transform as one undo entry.
  void commitTransform() => _commitTransform?.call();

  /// Escape: discards the open transform.
  void cancelTransform() => _cancelTransform?.call();
}
