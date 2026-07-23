import 'dart:async';

import 'package:flutter/foundation.dart';


import '../../services/canvas_selection_region.dart';

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
  /// R28-S (R26 #18 / R27 #19): the live selection REGION lives here, not
  /// inside the selection layer's State.
  ///
  /// The layer only mounts for the selection tools, so a layer-owned
  /// region evaporated the moment the user picked the brush — which is
  /// why "선택하고 다른 툴" had nothing to act on and the selection tool
  /// read as doing nothing at all. Owning it at the app level makes the
  /// region a DOCUMENT-level fact: it survives tool switches, the ants
  /// keep showing under every tool, and painting can clip to it.
  CanvasSelectionRegion? _region;

  /// The mode a fresh marquee/lasso combines with [region] (R26 #16).
  /// Default = 추가 (the user's stated default).
  SelectionCombineMode _combineMode = SelectionCombineMode.defaultMode;

  CanvasSelectionRegion? get region => _region;

  /// True when a region is selected — the single truth the shortcuts, the
  /// paint clip and the ants all read.
  bool get hasRegion => _region != null;

  SelectionCombineMode get combineMode => _combineMode;

  set combineMode(SelectionCombineMode mode) {
    if (_combineMode == mode) {
      return;
    }
    _combineMode = mode;
    notifySessionChanged();
  }

  /// Installs [region] as the live selection. The mounted layer pushes
  /// every committed change through here, and the history command's
  /// execute/undo does the same — one write path, one truth.
  void setRegion(CanvasSelectionRegion? region) {
    if (_region == region) {
      return;
    }
    _region = region;
    notifySessionChanged();
  }

  bool Function()? _hasSelection;
  void Function(double dx, double dy)? _nudge;
  VoidCallback? _deselect;
  bool Function()? _transformActive;
  VoidCallback? _beginTransform;
  VoidCallback? _beginMeshTransform;
  VoidCallback? _commitTransform;
  VoidCallback? _cancelTransform;
  void Function(CanvasSelectionRegion? region)? _applyRegion;
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
    VoidCallback? beginMeshTransform,
    VoidCallback? commitTransform,
    VoidCallback? cancelTransform,
    void Function(CanvasSelectionRegion? region)? applyRegion,
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
    _beginMeshTransform = beginMeshTransform;
    _commitTransform = commitTransform;
    _cancelTransform = cancelTransform;
    _applyRegion = applyRegion;
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
    _beginMeshTransform = null;
    _commitTransform = null;
    _cancelTransform = null;
    _applyRegion = null;
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

  /// Adopts a committed region — the selection history command's
  /// execute/undo path (R11-⑧), and the layer's own commit path.
  ///
  /// The region lands here FIRST (so it holds even with no layer
  /// mounted — R28-S), then reaches the mounted layer so an open
  /// move/transform session can react.
  void applyRegion(CanvasSelectionRegion? region) {
    setRegion(region);
    _applyRegion?.call(region);
  }

  /// Whether a live selection exists — arrow keys NUDGE instead of
  /// flipping frames while true (Photoshop arbitration).
  bool get hasSelection => _hasSelection?.call() ?? false;

  /// Moves the selection by canvas pixels (one undo entry per call).
  void nudge(double dx, double dy) => _nudge?.call(dx, dy);

  /// Records a region change as ONE undoable step. Set by the canvas
  /// panel (it owns the history manager); null applies changes directly.
  void Function(CanvasSelectionRegion? before, CanvasSelectionRegion? after)?
  regionHistoryRecorder;

  /// Ctrl+D. With a selection layer mounted it runs the layer's own
  /// deselect (which also ends any pending move session); with none —
  /// the brush is armed and the region is just showing its ants — the
  /// channel clears the region itself, through the same history recorder
  /// the layer uses. Ctrl+D never becomes a dead key just because the
  /// active tool is not a selection tool (R28-S).
  void deselect() {
    final layerDeselect = _deselect;
    if (layerDeselect != null) {
      layerDeselect();
      return;
    }
    final before = _region;
    if (before == null) {
      return;
    }
    final record = regionHistoryRecorder;
    if (record != null) {
      record(before, null);
      return;
    }
    setRegion(null);
  }

  /// Whether a free-transform session is open (Enter/Escape then
  /// commit/cancel it instead of their usual meanings).
  bool get transformActive => _transformActive?.call() ?? false;

  /// Ctrl+T: opens the free-transform box on the live selection.
  void beginTransform() => _beginTransform?.call();

  /// Opens the MESH-warp session (R20-D3) on the live selection: a 3×3
  /// control grid over the lifted pixels; Enter commits the triangulated
  /// warp as one undo entry.
  void beginMeshTransform() => _beginMeshTransform?.call();

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
