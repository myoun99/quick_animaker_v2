// Audio file decoding (audio program 2B) — WAV, FLAC and MP3 through the
// vendored dr_libs.
//
// A SEPARATE translation unit from qa_engine.c on purpose: the dr_libs
// implementations are ~27k lines between them, and folding that into the
// engine would slow every build of the hot loops and mix third-party
// warnings into ours.
//
// This decodes from MEMORY, never from a path. Dart already opens files
// correctly on every platform; handing C a `const char*` would drag in the
// whole Windows question of whether that path is UTF-8 or the local
// codepage, and a Korean filename would decide it the hard way.
//
// Nothing here is realtime. Decoding happens ONCE at import, which is the
// entire point of conforming — a variable-length codec cannot promise to
// finish inside an audio callback, and the callback cannot wait.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define QA_EXPORT __declspec(dllexport)
#else
#define QA_EXPORT __attribute__((visibility("default")))
#endif

// One implementation of each, here and nowhere else.
#define DR_WAV_IMPLEMENTATION
#define DR_FLAC_IMPLEMENTATION
#define DR_MP3_IMPLEMENTATION

// We never decode from a path (see the note above), so drop the stdio
// backends entirely — less code, and no way to accidentally reintroduce
// the encoding problem.
#define DR_WAV_NO_STDIO
#define DR_FLAC_NO_STDIO
#define DR_MP3_NO_STDIO

#include "third_party/dr_libs/dr_flac.h"
#include "third_party/dr_libs/dr_mp3.h"
#include "third_party/dr_libs/dr_wav.h"

// Which decoder produced the samples — reported back so the caller can say
// so in a log, and so a test can prove the right one was chosen.
#define QA_AUDIO_FORMAT_UNKNOWN 0
#define QA_AUDIO_FORMAT_WAV 1
#define QA_AUDIO_FORMAT_FLAC 2
#define QA_AUDIO_FORMAT_MP3 3

// Decodes a whole audio file held in memory to interleaved float32 at its
// OWN sample rate. Resampling to the project rate is a separate step: it
// is a quality decision, and burying it here would make it invisible.
//
// Format is detected by TRYING each decoder rather than sniffing magic
// bytes — a WAV with a junk chunk before `fmt `, or an MP3 with a fat ID3
// tag, defeats a naive sniff, and each library already knows how to
// recognize its own container.
//
// Returns the QA_AUDIO_FORMAT_* that succeeded, or 0 when nothing could
// read it. On success the caller owns *out_samples and must release it
// with qa_audio_decode_free.
QA_EXPORT int32_t qa_audio_decode_memory(
    const uint8_t* data,
    int64_t size,
    float** out_samples,
    int64_t* out_frame_count,
    int32_t* out_channels,
    int32_t* out_sample_rate) {
  if (out_samples == NULL || out_frame_count == NULL || out_channels == NULL ||
      out_sample_rate == NULL) {
    return QA_AUDIO_FORMAT_UNKNOWN;
  }
  *out_samples = NULL;
  *out_frame_count = 0;
  *out_channels = 0;
  *out_sample_rate = 0;
  if (data == NULL || size <= 0) {
    return QA_AUDIO_FORMAT_UNKNOWN;
  }

  const size_t byte_count = (size_t)size;
  unsigned int channels = 0;
  unsigned int sample_rate = 0;

  {
    drwav_uint64 frames = 0;
    float* samples = drwav_open_memory_and_read_pcm_frames_f32(
        data, byte_count, &channels, &sample_rate, &frames, NULL);
    if (samples != NULL) {
      *out_samples = samples;
      *out_frame_count = (int64_t)frames;
      *out_channels = (int32_t)channels;
      *out_sample_rate = (int32_t)sample_rate;
      return QA_AUDIO_FORMAT_WAV;
    }
  }
  {
    drflac_uint64 frames = 0;
    float* samples = drflac_open_memory_and_read_pcm_frames_f32(
        data, byte_count, &channels, &sample_rate, &frames, NULL);
    if (samples != NULL) {
      *out_samples = samples;
      *out_frame_count = (int64_t)frames;
      *out_channels = (int32_t)channels;
      *out_sample_rate = (int32_t)sample_rate;
      return QA_AUDIO_FORMAT_FLAC;
    }
  }
  {
    drmp3_config config;
    memset(&config, 0, sizeof(config));
    drmp3_uint64 frames = 0;
    float* samples = drmp3_open_memory_and_read_pcm_frames_f32(
        data, byte_count, &config, &frames, NULL);
    if (samples != NULL) {
      *out_samples = samples;
      *out_frame_count = (int64_t)frames;
      *out_channels = (int32_t)config.channels;
      *out_sample_rate = (int32_t)config.sampleRate;
      return QA_AUDIO_FORMAT_MP3;
    }
  }
  return QA_AUDIO_FORMAT_UNKNOWN;
}

// Releases a buffer from qa_audio_decode_memory. All three libraries route
// their frees through the same default allocator, so drwav_free is correct
// for any of them — but going through one named entry point keeps the
// caller from having to know that.
QA_EXPORT void qa_audio_decode_free(float* samples) {
  if (samples != NULL) {
    drwav_free(samples, NULL);
  }
}

// The decoders the build actually carries — the loader can report what a
// given binary supports instead of failing mysteriously on a format that
// was compiled out.
QA_EXPORT int32_t qa_audio_decode_formats(void) {
  return (1 << QA_AUDIO_FORMAT_WAV) | (1 << QA_AUDIO_FORMAT_FLAC) |
         (1 << QA_AUDIO_FORMAT_MP3);
}
