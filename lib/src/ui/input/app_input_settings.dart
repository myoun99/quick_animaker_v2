import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

/// Pointer-input policy (UI-R22 #6, default flipped in UI-R22F #1).
///
/// What a TOUCH contact means on the timeline grids:
///
/// - [touchTimelineScroll] ON (the DEFAULT) — the timeline's edit
///   gestures (range select/move, comma grips, run handles, block
///   moves) release touch entirely, so a finger pan reaches the scroll
///   viewports uncontested: touch is the timeline's SCROLL device. The
///   pen (stylus) edits either way.
/// - OFF — touch EDITS exactly like the pen (the R17-⑥ contract: some
///   Windows/tablet drivers report styluses as touch, so touch keeps
///   full editing power — select, move, drag grips). The safety net for
///   pens that misreport as touch.
///
/// NOTE for tests: `test/flutter_test_config.dart` pins the corpus to
/// OFF (the touch-as-pen contract `tester.drag` was written under);
/// scroll-behavior suites opt into ON explicitly.
class AppInputSettings {
  const AppInputSettings({
    this.touchTimelineScroll = true,
    this.tabletService = TabletService.standard,
    this.pressureCurveGamma = 1.0,
  });

  final bool touchTimelineScroll;

  /// The pen pressure RESPONSE curve (PEN-3, cross-platform): output =
  /// input^gamma. 1.0 = linear (the default, byte-identical to before);
  /// below 1 = SOFTER feel (a light touch already reads strong), above
  /// 1 = HARDER (full pressure takes a firm press). Applied wherever
  /// normalized pressure enters the brush pipeline — OS pointer and
  /// Wintab sidecar alike.
  final double pressureCurveGamma;

  /// Which tablet backend feeds pen data (PEN-2, the CSP-style dual
  /// service — Windows only; other platforms ignore it):
  /// - [TabletService.standard] (the DEFAULT): the OS pointer pipeline
  ///   exactly as today.
  /// - [TabletService.wintab]: the Wintab sidecar additionally streams
  ///   the DRIVER's pressure/tilt and overrides brush pressure — the
  ///   escape hatch for drivers whose OS path misreports the pen.
  final TabletService tabletService;

  AppInputSettings copyWith({
    bool? touchTimelineScroll,
    TabletService? tabletService,
    double? pressureCurveGamma,
  }) => AppInputSettings(
    touchTimelineScroll: touchTimelineScroll ?? this.touchTimelineScroll,
    tabletService: tabletService ?? this.tabletService,
    pressureCurveGamma: pressureCurveGamma ?? this.pressureCurveGamma,
  );

  Map<String, dynamic> toJson() => {
    'touchTimelineScroll': touchTimelineScroll,
    'tabletService': tabletService.name,
    'pressureCurveGamma': pressureCurveGamma,
  };

  static AppInputSettings fromJson(Map<String, dynamic> json) =>
      AppInputSettings(
        touchTimelineScroll: json['touchTimelineScroll'] as bool? ?? true,
        tabletService:
            TabletService.values.asNameMap()[json['tabletService']] ??
            TabletService.standard,
        pressureCurveGamma:
            (json['pressureCurveGamma'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  bool operator ==(Object other) =>
      other is AppInputSettings &&
      other.touchTimelineScroll == touchTimelineScroll &&
      other.tabletService == tabletService &&
      other.pressureCurveGamma == pressureCurveGamma;

  @override
  int get hashCode =>
      Object.hash(touchTimelineScroll, tabletService, pressureCurveGamma);
}

/// The tablet backend choice (PEN-2). CSP's '사용할 태블릿 서비스'
/// analogue: standard = the OS pointer path ('Tablet PC'), wintab = the
/// driver-direct sidecar.
enum TabletService { standard, wintab }

/// The LIVE input policy (the accent-settings pattern): the app root
/// rebuilds off the notifier; the session restores/persists it.
abstract final class AppInput {
  static final ValueNotifier<AppInputSettings> settings =
      ValueNotifier<AppInputSettings>(const AppInputSettings());

  static bool get touchTimelineScroll => settings.value.touchTimelineScroll;

  /// The pen pressure response curve (PEN-3): output = input^gamma.
  /// Gamma 1 short-circuits so the default path costs nothing.
  static double applyPressureCurve(double pressure) {
    final gamma = settings.value.pressureCurveGamma;
    if (gamma == 1.0) {
      return pressure;
    }
    return math.pow(pressure.clamp(0.0, 1.0), gamma).toDouble();
  }

  /// The device set every timeline EDIT pan uses (range select/move,
  /// comma grips, run handles, block moves): touch joins exactly while
  /// the timeline scroll does NOT own it.
  static Set<PointerDeviceKind> get timelineEditPanDevices => {
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
    if (!touchTimelineScroll) PointerDeviceKind.touch,
  };
}
