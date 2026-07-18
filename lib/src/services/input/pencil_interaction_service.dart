import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Apple Pencil double-tap, as the SYSTEM prefers it (PEN-5): the
/// iOS runner forwards UIPencilInteraction taps with the user's global
/// Pencil setting.
enum PencilTapAction {
  switchEraser,
  switchPrevious,
  showColorPalette,
  showInkAttributes,
  ignore,
}

/// Consumes the iPad runner's 'qa_pen/ios' channel (PEN-5): Pencil
/// double-taps arrive here; the shell (HomePage) maps them onto the tool
/// notifier. Everything else about the Pencil (classification, pressure,
/// hover on M2/Pro) already flows through Flutter's pointer stream.
class PencilInteractionService {
  PencilInteractionService._();

  static final PencilInteractionService instance = PencilInteractionService._();

  static const MethodChannel channel = MethodChannel('qa_pen/ios');

  /// The shell's handler; null taps fall on the floor (headless tests).
  void Function(PencilTapAction action)? onPencilTap;

  bool _bound = false;

  /// One-time wiring (from [PenSidecars.bind]); iOS-only unless [force]
  /// (tests).
  void bind({bool force = false}) {
    if (_bound || (!force && !Platform.isIOS)) {
      return;
    }
    _bound = true;
    channel.setMethodCallHandler(_handleCall);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'pencilTap') {
      return;
    }
    final arguments = call.arguments;
    final raw = arguments is Map ? arguments['action'] : null;
    // Unknown actions read as ignore — a future action name must never
    // surprise-toggle a tool.
    final action =
        PencilTapAction.values.asNameMap()[raw] ?? PencilTapAction.ignore;
    onPencilTap?.call(action);
  }

  @visibleForTesting
  void debugReset() {
    if (_bound) {
      channel.setMethodCallHandler(null);
    }
    _bound = false;
    onPencilTap = null;
  }
}
