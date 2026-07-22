// Same forwarder pattern as qa_audio_decode_forwarder.c: CocoaPods
// podspecs cannot reference files outside their own directory, so this
// pulls the shared denoise translation unit in by relative include.
//
// It stays SEPARATE from the engine forwarder because the vendored
// RNNoise bundle (model table included) belongs in its own object file
// everywhere else too.
#include "../../src/qa_audio_denoise.c"
