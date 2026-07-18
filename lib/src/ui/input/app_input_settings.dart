import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

/// Pointer-input policy (UI-R22 #6).
///
/// What a TOUCH contact means on the timeline grids:
///
/// - [touchTimelineScroll] OFF (the DEFAULT) — touch EDITS exactly like
///   the pen (the shipped R17-⑥ contract: some Windows/tablet drivers
///   report styluses as touch, so touch keeps full editing power —
///   select, move, drag grips). This is byte-for-byte today's behavior.
/// - ON — the timeline's edit gestures (range select/move, comma grips,
///   run handles, block moves) release touch entirely, so a finger pan
///   reaches the scroll viewports uncontested: touch becomes the
///   timeline's SCROLL device. The pen (stylus) edits either way.
class AppInputSettings {
  const AppInputSettings({this.touchTimelineScroll = false});

  final bool touchTimelineScroll;

  AppInputSettings copyWith({bool? touchTimelineScroll}) => AppInputSettings(
    touchTimelineScroll: touchTimelineScroll ?? this.touchTimelineScroll,
  );

  Map<String, dynamic> toJson() => {'touchTimelineScroll': touchTimelineScroll};

  static AppInputSettings fromJson(Map<String, dynamic> json) =>
      AppInputSettings(
        touchTimelineScroll: json['touchTimelineScroll'] as bool? ?? false,
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
