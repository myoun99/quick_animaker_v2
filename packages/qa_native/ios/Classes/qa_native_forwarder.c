// CocoaPods podspecs cannot reference files outside their own directory,
// so this forwarder pulls the shared C in by relative include — the
// pattern Flutter's own FFI plugin template uses. ONE copy of the source
// stays in packages/qa_native/src for every platform.
#include "../../src/qa_engine.c"
