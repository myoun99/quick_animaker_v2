import 'package:flutter_test/flutter_test.dart';

import '../helpers/native_engine_path.dart';

/// The guard that makes every OTHER parity suite trustworthy.
///
/// Byte-parity pins skip when no native binary is around, which is right
/// for a laptop without cmake — but in a CI summary a skipped suite and a
/// passing one look exactly the same. This project has been bitten by that
/// twice:
///
///  - #614: the pins hardcoded a Windows path, so on macOS and Linux they
///    could only ever skip. The first run that actually executed on Apple
///    silicon immediately found the engine rendering 182 where the
///    reference says 181.
///  - The Linux job built no engine at all — the gcc build lives in a
///    different job whose artifacts were never in that workspace — so every
///    pin had been skipping there since it was written.
///
/// Both were invisible because nothing asserted that the pins RAN. Every CI
/// job that builds a binary now sets `QA_REQUIRE_NATIVE=1`, and this test
/// turns a missing engine into a failure that names itself.
void main() {
  test('CI has a native engine, so the parity suites actually ran', () {
    final path = nativeEngineLibraryPathOrNull();
    expect(
      path,
      isNotNull,
      reason:
          'QA_REQUIRE_NATIVE=1 says this job builds a native engine, but no '
          'binary was found. Every byte-parity suite in this run therefore '
          'SKIPPED, and a skipped parity suite proves nothing. Check that '
          'the cmake build step ran and put its output where '
          'nativeEngineLibraryPathOrNull() looks.',
    );
  }, skip: nativeEngineRequired
      ? false
      : 'only enforced where CI builds an engine (QA_REQUIRE_NATIVE=1)');
}
