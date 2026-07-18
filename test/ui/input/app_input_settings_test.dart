import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/persistence/app_input_settings_store.dart';
import 'package:quick_animaker_v2/src/ui/input/app_input_settings.dart';

/// UI-R22 #6: ONE owner decides what a touch contact means on the
/// timeline — edit (default, the R17-⑥ pen-as-touch contract) or scroll.
void main() {
  tearDown(() {
    AppInput.settings.value = const AppInputSettings();
  });

  test('the edit device set releases touch exactly when the timeline '
      'scroll owns it', () {
    // Default OFF: touch EDITS like the pen (the R17-⑥ shipped
    // behavior, unchanged).
    expect(AppInput.touchTimelineScroll, isFalse);
    expect(AppInput.timelineEditPanDevices, contains(PointerDeviceKind.touch));

    // ON: the edit gestures ignore touch — finger pans reach the scroll
    // viewports uncontested.
    AppInput.settings.value = const AppInputSettings(touchTimelineScroll: true);
    expect(
      AppInput.timelineEditPanDevices,
      isNot(contains(PointerDeviceKind.touch)),
    );
    // The pen never leaves the edit set either way.
    expect(AppInput.timelineEditPanDevices, contains(PointerDeviceKind.stylus));
  });

  test('json + store round-trips', () async {
    const settings = AppInputSettings(touchTimelineScroll: true);
    expect(AppInputSettings.fromJson(settings.toJson()), settings);

    final dir = await Directory.systemTemp.createTemp('input');
    addTearDown(() => dir.delete(recursive: true));
    final store = AppInputSettingsStore(
      filePath: '${dir.path}/input_settings.json',
    );
    expect(await store.load(), isNull);
    await store.save(settings);
    expect(await store.load(), settings);
  });
}
