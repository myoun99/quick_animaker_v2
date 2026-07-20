import 'package:flutter/foundation.dart';

import 'brush_tool_state.dart';

/// The app's active-tool notifier with PER-PAINT-TOOL memory (R11-④):
/// the brush and the eraser each keep their own stroke settings (size,
/// tip, preset payload…) — switching tools stashes the outgoing paint
/// tool's state and restores the incoming one's, CSP-style. COLOR and the
/// stabilizer stay shared across tools (the color panel and the hand-feel
/// setting are global).
///
/// Non-paint tools (eyedropper, fill, selections) carry the current
/// settings through unchanged — they never stroke, and the shared color
/// keeps working for fill/eyedropper.
class PaintToolStateNotifier extends ValueNotifier<BrushToolState> {
  PaintToolStateNotifier(super.value);

  final Map<CanvasTool, BrushToolState> _paintToolBank =
      <CanvasTool, BrushToolState>{};

  /// The tool-switch GUARD (R26 #13): returns a refusal MESSAGE to block
  /// the switch, null to allow it. Installed once by the shell — every
  /// entrance (toolbar, library panel, shortcut, Ctrl+T, mapped pen
  /// button) writes through this one setter, so a refusal cannot be
  /// routed around.
  String? Function(CanvasTool tool)? switchGuard;

  /// Where a refusal is announced (the shared cursor notice).
  void Function(String message)? onSwitchRefused;

  @override
  set value(BrushToolState next) {
    final previous = value;
    if (next.tool != previous.tool) {
      final refusal = switchGuard?.call(next.tool);
      if (refusal != null) {
        onSwitchRefused?.call(refusal);
        // The refusal blocks the TOOL only — settings carried in the
        // same write still apply (a preset landing while blocked).
        final kept = next.copyWith(tool: previous.tool);
        if (kept != previous) {
          super.value = kept;
        }
        return;
      }
    }
    if (next.tool != previous.tool) {
      if (canvasToolPaints(previous.tool)) {
        _paintToolBank[previous.tool] = previous;
      }
      // Restore ONLY on a pure tool switch (the caller changed nothing but
      // the tool) — an assignment that also carries new settings (a preset
      // application landing on the brush) must win over the bank.
      final pureToolSwitch = next.copyWith(tool: previous.tool) == previous;
      final stored = pureToolSwitch && canvasToolPaints(next.tool)
          ? _paintToolBank[next.tool]
          : null;
      if (stored != null) {
        next = stored.copyWith(
          tool: next.tool,
          color: next.color,
          stabilizerStrength: next.stabilizerStrength,
        );
      }
    }
    super.value = next;
  }
}
