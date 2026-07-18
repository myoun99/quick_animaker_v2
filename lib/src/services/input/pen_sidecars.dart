import 'dart:io';

import 'package:flutter/foundation.dart';

import 'platform_pen_channel_service.dart';
import 'wintab_pen_service.dart';

/// The pen program's sidecar FACADE (PEN-4): one question — "does a
/// driver-side stream know the pen's pressure right now?" — answered
/// across every platform's sidecar:
///
/// - Windows: the Wintab service (user-switched, PEN-2). Consulted
///   FIRST and unconditionally (it self-gates on its setting).
/// - macOS / Linux: the platform channel services (PEN-4), started
///   unconditionally on their platform by [bind] — they only restore
///   data the embedder drops today.
///
/// The brush canvas asks [freshContactPressure] per pointer sample; the
/// input inspector lists [channelServices] readouts beside the Wintab
/// line.
abstract final class PenSidecars {
  static final List<PlatformPenChannelService> channelServices =
      <PlatformPenChannelService>[];

  static bool _bound = false;

  /// One-time wiring from main(); FLUTTER_TEST-inert by construction
  /// (tests never call it — they drive services directly).
  static void bind() {
    if (_bound) {
      return;
    }
    _bound = true;
    WintabPenService.instance.bind();
    if (Platform.isMacOS) {
      channelServices.add(PlatformPenChannelService.macos()..start());
    } else if (Platform.isLinux) {
      channelServices.add(PlatformPenChannelService.linux()..start());
    }
  }

  /// The freshest driver-side contact pressure across every live
  /// sidecar; null = no sidecar speaks for this moment (use the pointer
  /// event's own pressure).
  static double? freshContactPressure() {
    final wintab = WintabPenService.instance.freshContactPressure();
    if (wintab != null) {
      return wintab;
    }
    for (final service in channelServices) {
      final pressure = service.freshContactPressure();
      if (pressure != null) {
        return pressure;
      }
    }
    return null;
  }

  @visibleForTesting
  static void debugReset() {
    for (final service in channelServices) {
      service.stop();
    }
    channelServices.clear();
    _bound = false;
  }
}
