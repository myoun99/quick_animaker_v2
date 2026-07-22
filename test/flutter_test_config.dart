import 'dart:async';
import 'dart:io';

import 'package:quick_animaker_v2/src/services/persistence/app_documents.dart';
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
/// baseline (`AppInputSettings.testCorpusBaseline`), not to the
/// product default `AppInputSettings()`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppInput.settings.value = AppInputSettings.testCorpusBaseline;
  // REC1-B2: the app documents home — and with it the Recordings take
  // shelf — resolves through the channel override, pointed at a per-run
  // temp sandbox so no test ever writes into the REAL user Documents.
  // Tests that override the path themselves must tearDown-restore the
  // previous value, never null (null falls back to the real home).
  final sandbox = Directory.systemTemp.createTempSync('qa_test_docs_');
  AppStorage.channelDocumentsPath = sandbox.path.replaceAll('\\', '/');
  try {
    await testMain();
  } finally {
    try {
      sandbox.deleteSync(recursive: true);
    } on Object {
      // A leaked handle on Windows must not fail the suite.
    }
  }
}
