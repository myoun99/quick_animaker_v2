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
    this.canvasRightClick = const CanvasPointerMapping(
      action: CanvasPointerAction.eyedropper,
    ),
    this.canvasWheelClick = const CanvasPointerMapping(
      action: CanvasPointerAction.pan,
    ),
  });

  /// The canvas mapping for the RIGHT-CLICK bit (PEN-7a): pen side/
  /// barrel button, S-Pen button, mouse right button — one row for all.
  final CanvasPointerMapping canvasRightClick;

  /// The canvas mapping for the WHEEL/MIDDLE bit: pen upper button,
  /// mouse wheel click.
  final CanvasPointerMapping canvasWheelClick;

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
    CanvasPointerMapping? canvasRightClick,
    CanvasPointerMapping? canvasWheelClick,
  }) => AppInputSettings(
    touchTimelineScroll: touchTimelineScroll ?? this.touchTimelineScroll,
    tabletService: tabletService ?? this.tabletService,
    pressureCurveGamma: pressureCurveGamma ?? this.pressureCurveGamma,
    canvasRightClick: canvasRightClick ?? this.canvasRightClick,
    canvasWheelClick: canvasWheelClick ?? this.canvasWheelClick,
  );

  Map<String, dynamic> toJson() => {
    'touchTimelineScroll': touchTimelineScroll,
    'tabletService': tabletService.name,
    'pressureCurveGamma': pressureCurveGamma,
    'canvasRightClick': canvasRightClick.toJson(),
    'canvasWheelClick': canvasWheelClick.toJson(),
  };

  static AppInputSettings fromJson(Map<String, dynamic> json) =>
      AppInputSettings(
        touchTimelineScroll: json['touchTimelineScroll'] as bool? ?? true,
        tabletService:
            TabletService.values.asNameMap()[json['tabletService']] ??
            TabletService.standard,
        pressureCurveGamma:
            (json['pressureCurveGamma'] as num?)?.toDouble() ?? 1.0,
        canvasRightClick: CanvasPointerMapping.fromJson(
          json['canvasRightClick'],
          fallback: const CanvasPointerMapping(
            action: CanvasPointerAction.eyedropper,
          ),
        ),
        canvasWheelClick: CanvasPointerMapping.fromJson(
          json['canvasWheelClick'],
          fallback: const CanvasPointerMapping(action: CanvasPointerAction.pan),
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is AppInputSettings &&
      other.touchTimelineScroll == touchTimelineScroll &&
      other.tabletService == tabletService &&
      other.pressureCurveGamma == pressureCurveGamma &&
      other.canvasRightClick == canvasRightClick &&
      other.canvasWheelClick == canvasWheelClick;

  @override
  int get hashCode => Object.hash(
    touchTimelineScroll,
    tabletService,
    pressureCurveGamma,
    canvasRightClick,
    canvasWheelClick,
  );
}

/// The tablet backend choice (PEN-2). CSP's '사용할 태블릿 서비스'
/// analogue: standard = the OS pointer path ('Tablet PC'), wintab = the
/// driver-direct sidecar.
enum TabletService { standard, wintab }

/// What a STANDARD secondary input does on the CANVAS (PEN-7a) — the
/// app's one in-house mapping layer. Everywhere else follows the
/// driver/OS meaning of the input untouched; on canvas the user assigns
/// it. Pen side/barrel buttons, the S-Pen button and the mouse right
/// button all arrive as the SAME right-click bit, so one row governs
/// them all (and the wheel/upper-button bit gets its own row).
enum CanvasPointerAction { eyedropper, eraser, pan, none }

/// What happens when the held mapping ends (PEN-7a): the hold
/// temporarily SWITCHES THE TOOL (the shared tool-switch path — cursor,
/// panels and per-tool settings all follow for free); release either
/// springs back to the original tool (the default) or keeps the
/// switched tool armed.
enum CanvasPointerRelease { returnToTool, keep }

/// One canvas mapping row: the action plus its release behavior.
class CanvasPointerMapping {
  const CanvasPointerMapping({
    required this.action,
    this.release = CanvasPointerRelease.returnToTool,
  });

  final CanvasPointerAction action;
  final CanvasPointerRelease release;

  CanvasPointerMapping copyWith({
    CanvasPointerAction? action,
    CanvasPointerRelease? release,
  }) => CanvasPointerMapping(
    action: action ?? this.action,
    release: release ?? this.release,
  );

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'release': release.name,
  };

  static CanvasPointerMapping fromJson(
    Object? json, {
    required CanvasPointerMapping fallback,
  }) {
    if (json is! Map) {
      return fallback;
    }
    return CanvasPointerMapping(
      action:
          CanvasPointerAction.values.asNameMap()[json['action']] ??
          fallback.action,
      release:
          CanvasPointerRelease.values.asNameMap()[json['release']] ??
          fallback.release,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CanvasPointerMapping &&
      other.action == action &&
      other.release == release;

  @override
  int get hashCode => Object.hash(action, release);
}

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

  /// Whether a CELL press of [kind] may SEEK the playhead (UI-R23
  /// feedback #2): with touch-scroll ON a finger on the grid is pure
  /// scroll — its press-down must not move the frame index (the first
  /// scroll touch kept re-seeking). Pen/mouse always seek; with the
  /// toggle OFF touch seeks like a pen (the R17-⑥ contract).
  static bool timelineCellPressSeeks(PointerDeviceKind kind) =>
      kind != PointerDeviceKind.touch || !touchTimelineScroll;
}
