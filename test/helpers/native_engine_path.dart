import 'dart:io';

/// Where a locally built native engine can be found — the ONE resolver
/// every parity/benchmark suite shares.
///
/// The suites used to hardcode `build\native_standalone\Release\
/// qa_engine.dll`, so on macOS and Linux they could only ever skip: the
/// byte-parity pins that exist to catch a compiler disagreeing with the
/// Dart reference never ran on the platforms most likely to disagree
/// (Apple clang on arm64, gcc on x86_64). Resolving per platform — and
/// honoring the `QA_ENGINE_PATH` override CI sets — is what makes them
/// real everywhere.
///
/// Null = no engine built here; callers skip LOUDLY rather than fail.
String? nativeEngineLibraryPathOrNull() {
  final override = Platform.environment['QA_ENGINE_PATH'];
  if (override != null && override.isNotEmpty && File(override).existsSync()) {
    return override;
  }
  final root = Directory.current.path;
  String at(List<String> parts) =>
      [root, ...parts].join(Platform.pathSeparator);
  final candidates = <String>[
    if (Platform.isWindows)
      at(['build', 'native_standalone', 'Release', 'qa_engine.dll']),
    if (Platform.isMacOS) ...[
      // The plain cmake build (Makefile generator: no config subdir).
      at(['build', 'native_standalone', 'libqa_engine.dylib']),
      at(['build', 'ci-apple', 'libqa_engine.dylib']),
    ],
    if (Platform.isLinux) ...[
      at(['build', 'native_standalone', 'libqa_engine.so']),
      at(['build', 'ci-gcc', 'libqa_engine.so']),
    ],
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

/// The message a skipped suite prints, so the reason is never a mystery.
const String nativeEngineMissingSkipReason =
    'no locally built native engine — build it with: '
    'cmake -S packages/qa_native/src -B build/native_standalone && '
    'cmake --build build/native_standalone --config Release '
    '(or set QA_ENGINE_PATH)';
