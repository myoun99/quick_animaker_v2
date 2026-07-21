// Objective-C (.m), NOT .c — deliberately.
//
// miniaudio's Apple backend includes <AVFoundation/AVFoundation.h> on iOS
// (it drives AVAudioSession there). AVFoundation is an Objective-C module,
// so a plain .c translation unit fails to build it outright:
//
//   Parse Issue (Xcode): Could not build module 'AVFoundation'
//
// The file is otherwise the same forwarder pattern as the others —
// CocoaPods podspecs cannot reference files outside their own directory.
// `s.source_files = 'Classes/**/*'` picks up .m as readily as .c, and
// OTHER_CFLAGS (including the -ffp-contract=off parity flag) applies to
// Objective-C exactly as it does to C.
#include "../../src/qa_audio_device.c"
