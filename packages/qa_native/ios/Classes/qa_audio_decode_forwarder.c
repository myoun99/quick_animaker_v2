// Same forwarder pattern as qa_native_forwarder.c: CocoaPods podspecs
// cannot reference files outside their own directory, so this pulls the
// shared decoder translation unit in by relative include.
//
// It stays SEPARATE from the engine forwarder because the two are separate
// translation units everywhere else (see the note in qa_audio_decode.c) —
// folding them together here would compile ~27k lines of vendored dr_libs
// into the same object file as the hot loops on Apple platforms only.
#include "../../src/qa_audio_decode.c"
