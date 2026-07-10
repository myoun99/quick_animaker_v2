import 'package:flutter/foundation.dart';

/// The imperative view-control channel for the editor canvas (P8): the
/// app-level shortcut dispatch (R/Shift+R rotate, H flip) calls in, and
/// the mounted [BrushCanvasPanel] binds the handlers — the panel owns the
/// viewport interaction math and the viewport-center anchor. Unbound
/// calls are no-ops (no canvas panel on screen).
class CanvasViewCommands {
  void Function(double degrees)? _rotateBy;
  VoidCallback? _toggleFlipHorizontal;

  void bind({
    required void Function(double degrees) rotateBy,
    required VoidCallback toggleFlipHorizontal,
  }) {
    _rotateBy = rotateBy;
    _toggleFlipHorizontal = toggleFlipHorizontal;
  }

  void unbind() {
    _rotateBy = null;
    _toggleFlipHorizontal = null;
  }

  /// Rotates the canvas VIEW by [degrees] (clockwise positive) around the
  /// viewport center.
  void rotateBy(double degrees) => _rotateBy?.call(degrees);

  /// Toggles the horizontal view mirror around the viewport center.
  void toggleFlipHorizontal() => _toggleFlipHorizontal?.call();
}
