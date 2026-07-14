import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/canvas_selection.dart';

/// The live transform box's numeric state (R17-U tool settings inputs).
typedef SelectionTransformValues = ({
  double tx,
  double ty,
  double rotationDegrees,
  double scale,
});

/// The imperative selection channel (P9): the app-level shortcuts
/// (Ctrl+D deselect, arrow nudges) call in; the mounted selection layer
/// binds the handlers. Unbound calls are no-ops and [hasSelection] is
/// false — the arrow keys then keep their frame-flipping meaning.
///
/// R17-U: also a [ChangeNotifier] — the layer pings [notifySessionChanged]
/// on selection/transform mutations so the tool settings panel's numeric
/// fields track handle drags live (notification is coalesced and deferred
/// a microtask: mutations fire inside build/gesture phases).
class CanvasSelectionCommands extends ChangeNotifier {
  bool Function()? _hasSelection;
  void Function(double dx, double dy)? _nudge;
  VoidCallback? _deselect;
  bool Function()? _transformActive;
  VoidCallback? _beginTransform;
  VoidCallback? _commitTransform;
  VoidCallback? _cancelTransform;
  void Function(CanvasSelectionShape? shape)? _applyShape;
  bool Function()? _movePending;
  VoidCallback? _confirmPendingMove;
  VoidCallback? _revertPendingMove;
  SelectionTransformValues? Function()? _transformValues;
  void Function({
    required double tx,
    required double ty,
    required double rotationDegrees,
    required double scale,
  })?
  _setTransformValues;

  bool _notifyScheduled = false;

  void bind({
    required bool Function() hasSelection,
    required void Function(double dx, double dy) nudge,
    required VoidCallback deselect,
    bool Function()? transformActive,
    VoidCallback? beginTransform,
    VoidCallback? commitTransform,
    VoidCallback? cancelTransform,
    void Function(CanvasSelectionShape? shape)? applyShape,
    bool Function()? movePending,
    VoidCallback? confirmPendingMove,
    VoidCallback? revertPendingMove,
    SelectionTransformValues? Function()? transformValues,
    void Function({
      required double tx,
      required double ty,
      required double rotationDegrees,
      required double scale,
    })?
    setTransformValues,
  }) {
    _hasSelection = hasSelection;
    _nudge = nudge;
    _deselect = deselect;
    _transformActive = transformActive;
    _beginTransform = beginTransform;
    _commitTransform = commitTransform;
    _cancelTransform = cancelTransform;
    _applyShape = applyShape;
    _movePending = movePending;
    _confirmPendingMove = confirmPendingMove;
    _revertPendingMove = revertPendingMove;
    _transformValues = transformValues;
    _setTransformValues = setTransformValues;
    notifySessionChanged();
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
    _movePending = null;
    _confirmPendingMove = null;
    _revertPendingMove = null;
    _transformValues = null;
    _setTransformValues = null;
    notifySessionChanged();
  }

  /// Coalesced, microtask-deferred change ping — safe to call from any
  /// phase (the layer mutates state inside builds and gesture handlers,
  /// where a synchronous notifyListeners could re-enter the build).
  void notifySessionChanged() {
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
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

  /// Whether a free-transform session is open (Enter/Escape then
  /// commit/cancel it instead of their usual meanings).
  bool get transformActive => _transformActive?.call() ?? false;

  /// Ctrl+T: opens the free-transform box on the live selection.
  void beginTransform() => _beginTransform?.call();

  /// Enter: commits the open transform as one undo entry.
  void commitTransform() => _commitTransform?.call();

  /// Escape: discards the open transform.
  void cancelTransform() => _cancelTransform?.call();

  /// Whether a TVP-style move session awaits its confirm (R16-①).
  bool get movePending => _movePending?.call() ?? false;

  /// Adopts the pending move into history as ONE undo entry — called by
  /// the confirm button, Enter, tool switches, and the history manager's
  /// pre-undo/redo hook. No-op without a pending session.
  void confirmPendingMove() => _confirmPendingMove?.call();

  /// Reverts the pending move: the pixels return EXACTLY to where the
  /// session found them (a fresh lift disappears entirely), no history
  /// entry. The "되돌리기" choice in the R17-① confirm prompt.
  void revertPendingMove() => _revertPendingMove?.call();

  /// The open transform box's numeric state, or null when no box is up
  /// (the settings fields then show the identity).
  SelectionTransformValues? get transformValues => _transformValues?.call();

  /// Applies numeric transform values to the live selection (R17-U): the
  /// layer opens a session if none is up, sets the affine, and shows the
  /// result on the float — Enter confirms, Escape reverts, as always.
  void setTransformValues({
    required double tx,
    required double ty,
    required double rotationDegrees,
    required double scale,
  }) => _setTransformValues?.call(
    tx: tx,
    ty: ty,
    rotationDegrees: rotationDegrees,
    scale: scale,
  );
}
