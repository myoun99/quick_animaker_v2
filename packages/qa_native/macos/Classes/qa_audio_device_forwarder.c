// Forwarder for the device layer — same pattern as the others: CocoaPods
// podspecs cannot reference files outside their own directory.
//
// Separate from the engine and decoder forwarders because all three are
// separate translation units everywhere else; miniaudio alone is ~96k
// lines and has no business sharing an object file with the hot loops.
#include "../../src/qa_audio_device.c"
