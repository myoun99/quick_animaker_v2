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
  const AppInputSettings({this.touchTimelineScroll = true});

  final bool touchTimelineScroll;

  AppInputSettings copyWith({bool? touchTimelineScroll}) => AppInputSettings(
    touchTimelineScroll: touchTimelineScroll ?? this.touchTimelineScroll,
  );

  Map<String, dynamic> toJson() => {'touchTimelineScroll': touchTimelineScroll};

  static AppInputSettings fromJson(Map<String, dynamic> json) =>
      AppInputSettings(
        touchTimelineScroll: json['touchTimelineScroll'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is AppInputSettings &&
      other.touchTimelineScroll == touchTimelineScroll;

  @override
  int get hashCode => touchTimelineScroll.hashCode;
}

/// The LIVE input policy (the accent-settings pattern): the app root
/// rebuilds off the notifier; the session restores/persists it.
abstract final class AppInput {
  static final ValueNotifier<AppInputSettings> settings =
      ValueNotifier<AppInputSettings>(const AppInputSettings());

  static bool get touchTimelineScroll => settings.value.touchTimelineScroll;

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
