// The output device and the transport (audio program 2C).
//
// This is where "audio is the master clock" becomes literal. The device
// pulls buffers on its own realtime thread; each pull mixes the next span
// of samples and advances a counter. The playback position IS that counter
// — the number of samples handed to the device — so it cannot drift from
// what is being heard. A free-running timer can; that is the defect this
// program started from.
//
// NON-NEGOTIABLE: no Dart runs in the callback. Dart uploads the schedule
// and the PCM, starts and stops the transport, and polls the position.
// Everything the callback touches is already resident C memory.
//
// The schedule is only replaced while the transport is STOPPED. That makes
// the handoff trivially safe without lock-free machinery, and it matches
// how playback already works — the schedule is built when playback starts.
// Editing sound during playback would need a double-buffered swap; that is
// a later problem, and pretending otherwise would put a data race on the
// realtime thread.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define QA_EXPORT __declspec(dllexport)
#else
#define QA_EXPORT __attribute__((visibility("default")))
#endif

// Playback only: no capture, no decoding (conforms are already PCM), no
// resampling (imports already landed at the project rate), no generation.
// Each of those is code we would ship and never run.
#define MA_NO_ENCODING
#define MA_NO_DECODING
#define MA_NO_GENERATION
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
#define MA_IMPLEMENTATION
#include "third_party/miniaudio/miniaudio.h"

// The mixer's types live in qa_engine.c; declared here rather than shared
// through a header because the project keeps one portable C file per
// concern and no headers of its own.
typedef struct {
  double gain;
  int64_t start_sample;
  int64_t end_sample;
  int64_t source_offset;
  int64_t fade_in_samples;
  int64_t fade_out_samples;
  int32_t source_index;
  int32_t reserved;
} qa_audio_clip;

typedef struct {
  int64_t source_start;
  int64_t length;
  int32_t channels;
  int32_t reserved;
  const float* samples;
} qa_audio_source;

extern void qa_audio_mix(const qa_audio_clip* clips,
                         int32_t clip_count,
                         const qa_audio_source* sources,
                         int32_t source_count,
                         int64_t start_sample,
                         int32_t sample_count,
                         int32_t out_channels,
                         double* out);

#define QA_DEVICE_MAX_BLOCK 8192

typedef struct {
  ma_device device;
  int32_t device_open;
  int32_t playing;

  // The transport. `position` counts samples HANDED TO THE DEVICE, which
  // is what makes it the clock: it advances only when audio actually
  // leaves, so it cannot run ahead of what is heard.
  int64_t position;
  int64_t start_position;
  int64_t stop_position;  // exclusive; <= start means "no end"
  int32_t looping;

  qa_audio_clip* clips;
  int32_t clip_count;
  qa_audio_source* sources;
  int32_t source_count;
  float* source_pcm;  // one owned block holding every source's samples
  int64_t source_pcm_floats;

  int32_t channels;
  int32_t sample_rate;
  double* scratch;  // the mix bus, sized once at open
} qa_audio_device_state;

static qa_audio_device_state g_audio;

// The realtime callback. memcpy and a weighted sum, nothing else: no
// allocation, no locks, no I/O, no Dart.
static void qa_audio_data_callback(ma_device* device,
                                   void* output,
                                   const void* input,
                                   ma_uint32 frame_count) {
  (void)device;
  (void)input;
  float* out = (float*)output;
  const int32_t channels = g_audio.channels;
  const size_t total = (size_t)frame_count * (size_t)channels;
  memset(out, 0, total * sizeof(float));

  if (!g_audio.playing || g_audio.scratch == NULL) {
    return;
  }

  ma_uint32 done = 0;
  while (done < frame_count) {
    ma_uint32 block = frame_count - done;
    if (block > QA_DEVICE_MAX_BLOCK) {
      block = QA_DEVICE_MAX_BLOCK;
    }

    int64_t position = g_audio.position;
    if (g_audio.stop_position > g_audio.start_position &&
        position >= g_audio.stop_position) {
      if (g_audio.looping) {
        position = g_audio.start_position;
        g_audio.position = position;
      } else {
        g_audio.playing = 0;
        return;
      }
    }
    // Never mix past the stop point in one block; the wrap has to land on
    // the sample, not the buffer boundary.
    if (g_audio.stop_position > g_audio.start_position) {
      const int64_t remaining = g_audio.stop_position - position;
      if ((int64_t)block > remaining) {
        block = (ma_uint32)remaining;
      }
    }
    if (block == 0) {
      return;
    }

    qa_audio_mix(g_audio.clips, g_audio.clip_count, g_audio.sources,
                 g_audio.source_count, position, (int32_t)block, channels,
                 g_audio.scratch);

    const size_t written = (size_t)block * (size_t)channels;
    float* target = out + (size_t)done * (size_t)channels;
    for (size_t index = 0; index < written; index += 1) {
      double value = g_audio.scratch[index];
      // The bus has headroom; the DEVICE does not. Clipping belongs here,
      // at the boundary, exactly as it does for the int16 path.
      if (value > 1.0) {
        value = 1.0;
      } else if (value < -1.0) {
        value = -1.0;
      }
      target[index] = (float)value;
    }

    g_audio.position = position + (int64_t)block;
    done += block;
  }
}

static void qa_audio_free_schedule(void) {
  free(g_audio.clips);
  free(g_audio.sources);
  free(g_audio.source_pcm);
  g_audio.clips = NULL;
  g_audio.sources = NULL;
  g_audio.source_pcm = NULL;
  g_audio.clip_count = 0;
  g_audio.source_count = 0;
  g_audio.source_pcm_floats = 0;
}

// Opens the output device. [backend] 0 = let miniaudio choose, 1 = the
// NULL backend, which runs the real callback on a real thread with no
// hardware — how the transport is tested on a CI runner with no sound card.
//
// Returns the device's actual sample rate, or 0 on failure. The rate is
// returned rather than assumed because a device may refuse the one asked
// for, and conforming to the wrong rate would put every sound at the wrong
// speed.
QA_EXPORT int32_t qa_audio_device_open(int32_t sample_rate,
                                       int32_t channels,
                                       int32_t backend) {
  if (g_audio.device_open) {
    return g_audio.sample_rate;
  }
  if (sample_rate <= 0 || channels <= 0 || channels > 8) {
    return 0;
  }

  ma_device_config config = ma_device_config_init(ma_device_type_playback);
  config.playback.format = ma_format_f32;
  config.playback.channels = (ma_uint32)channels;
  config.sampleRate = (ma_uint32)sample_rate;
  config.dataCallback = qa_audio_data_callback;

  ma_result result;
  if (backend == 1) {
    ma_backend backends[1];
    backends[0] = ma_backend_null;
    static ma_context context;
    if (ma_context_init(backends, 1, NULL, &context) != MA_SUCCESS) {
      return 0;
    }
    result = ma_device_init(&context, &config, &g_audio.device);
  } else {
    result = ma_device_init(NULL, &config, &g_audio.device);
  }
  if (result != MA_SUCCESS) {
    return 0;
  }

  g_audio.channels = (int32_t)g_audio.device.playback.channels;
  g_audio.sample_rate = (int32_t)g_audio.device.sampleRate;
  g_audio.scratch = (double*)malloc((size_t)QA_DEVICE_MAX_BLOCK *
                                    (size_t)g_audio.channels * sizeof(double));
  if (g_audio.scratch == NULL) {
    ma_device_uninit(&g_audio.device);
    return 0;
  }
  g_audio.device_open = 1;
  g_audio.playing = 0;
  g_audio.position = 0;

  if (ma_device_start(&g_audio.device) != MA_SUCCESS) {
    free(g_audio.scratch);
    g_audio.scratch = NULL;
    ma_device_uninit(&g_audio.device);
    g_audio.device_open = 0;
    return 0;
  }
  return g_audio.sample_rate;
}

QA_EXPORT void qa_audio_device_close(void) {
  if (!g_audio.device_open) {
    return;
  }
  g_audio.playing = 0;
  ma_device_uninit(&g_audio.device);
  free(g_audio.scratch);
  g_audio.scratch = NULL;
  qa_audio_free_schedule();
  g_audio.device_open = 0;
}

QA_EXPORT int32_t qa_audio_device_is_open(void) { return g_audio.device_open; }
QA_EXPORT int32_t qa_audio_device_sample_rate(void) { return g_audio.sample_rate; }
QA_EXPORT int32_t qa_audio_device_channels(void) { return g_audio.channels; }

// The device's own reported output latency in samples — what the picture
// has to be pulled forward by so it matches what is being heard. Whatever
// this cannot account for is the residual the user's A/V offset removes.
QA_EXPORT int64_t qa_audio_device_latency_samples(void) {
  if (!g_audio.device_open) {
    return 0;
  }
  return (int64_t)g_audio.device.playback.internalPeriodSizeInFrames *
         (int64_t)g_audio.device.playback.internalPeriods;
}

// Replaces the schedule. Only legal while STOPPED (see the file header) —
// returns 0 and changes nothing otherwise, rather than racing the
// realtime thread.
//
// The PCM is COPIED into one owned block: the callback must never chase a
// pointer into Dart-managed memory that could move or be collected.
QA_EXPORT int32_t qa_audio_device_set_schedule(
    const qa_audio_clip* clips,
    int32_t clip_count,
    const qa_audio_source* sources,
    int32_t source_count,
    const float* pcm,
    int64_t pcm_floats,
    const int64_t* source_offsets) {
  if (g_audio.playing) {
    return 0;
  }
  qa_audio_free_schedule();
  if (clip_count < 0 || source_count < 0 || pcm_floats < 0) {
    return 0;
  }

  if (clip_count > 0) {
    g_audio.clips =
        (qa_audio_clip*)malloc((size_t)clip_count * sizeof(qa_audio_clip));
    if (g_audio.clips == NULL) {
      return 0;
    }
    memcpy(g_audio.clips, clips, (size_t)clip_count * sizeof(qa_audio_clip));
    g_audio.clip_count = clip_count;
  }

  if (pcm_floats > 0) {
    g_audio.source_pcm = (float*)malloc((size_t)pcm_floats * sizeof(float));
    if (g_audio.source_pcm == NULL) {
      qa_audio_free_schedule();
      return 0;
    }
    memcpy(g_audio.source_pcm, pcm, (size_t)pcm_floats * sizeof(float));
    g_audio.source_pcm_floats = pcm_floats;
  }

  if (source_count > 0) {
    g_audio.sources =
        (qa_audio_source*)malloc((size_t)source_count * sizeof(qa_audio_source));
    if (g_audio.sources == NULL) {
      qa_audio_free_schedule();
      return 0;
    }
    memcpy(g_audio.sources, sources,
           (size_t)source_count * sizeof(qa_audio_source));
    // Repoint every source at our copy: the caller's `samples` pointers
    // describe ITS memory, and the offsets say where each block landed in
    // the flattened PCM.
    for (int32_t index = 0; index < source_count; index += 1) {
      const int64_t offset = source_offsets == NULL ? 0 : source_offsets[index];
      g_audio.sources[index].samples =
          (offset >= 0 && offset < pcm_floats) ? g_audio.source_pcm + offset
                                               : NULL;
    }
    g_audio.source_count = source_count;
  }
  return 1;
}

// Starts playback at [start_sample]. [stop_sample] is exclusive; pass a
// value at or below the start for "no end".
QA_EXPORT int32_t qa_audio_device_play(int64_t start_sample,
                                       int64_t stop_sample,
                                       int32_t looping) {
  if (!g_audio.device_open) {
    return 0;
  }
  g_audio.position = start_sample;
  g_audio.start_position = start_sample;
  g_audio.stop_position = stop_sample;
  g_audio.looping = looping ? 1 : 0;
  g_audio.playing = 1;
  return 1;
}

QA_EXPORT void qa_audio_device_stop(void) { g_audio.playing = 0; }

QA_EXPORT int32_t qa_audio_device_is_playing(void) { return g_audio.playing; }

// Samples handed to the device so far — THE clock. The picture reads this
// and shows whatever frame it lands in; if rendering fell behind, frames
// are dropped rather than the sound being made to wait.
QA_EXPORT int64_t qa_audio_device_position(void) { return g_audio.position; }

// Moves the transport without restarting anything: because the mixer
// builds a mix rather than starting clips, seeking is just changing where
// the next block is read from.
QA_EXPORT void qa_audio_device_seek(int64_t sample) {
  g_audio.position = sample;
}
