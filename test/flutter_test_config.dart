import 'dart:async';

import 'package:quick_animaker_v2/src/ui/input/app_input_settings.dart';

/// Corpus-wide input baseline (UI-R22F #1).
///
/// The PRODUCT default is touch-scrolls-ON (finger pans scroll the
/// timeline; the edit gestures release touch). The test corpus, though,
/// was written under the R17-⑥ touch-as-pen contract — `tester.drag`
/// and `startGesture` default to [PointerDeviceKind.touch] — so every
/// file starts from OFF here and suites that assert the ON behavior
/// (touch scrolling, touch released by edit gestures) opt in explicitly.
///
/// Tests that flip the value themselves must tearDown-reset to THIS
/// baseline (`AppInputSettings(touchTimelineScroll: false)`), not to the
/// product default `AppInputSettings()`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppInput.settings.value = const AppInputSettings(touchTimelineScroll: false);
  await testMain();
}
