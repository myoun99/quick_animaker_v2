// The OS video encoder (AUDIO-PRO R7): frames + mixed PCM in, an H.264/AAC
// MP4 out — through the operating system's own codec stack, no ffmpeg.
//
// Why this exists: the export pipeline's last external dependency was an
// ffmpeg binary on PATH, which a tablet does not have and a fresh desktop
// install often does not either. Every target OS ships hardware-backed
// H.264+AAC encoding and an MP4 muxer as system API:
//
//   Windows  — Media Foundation's Sink Writer (pure C COM, like the AAC
//              decoder in qa_audio_decode.c)
//   Apple    — AVAssetWriter (Objective-C; implemented in
//              qa_video_apple.m, this file only forwards)
//   Android  — NDK AMediaCodec + AMediaMuxer, resolved with dlsym like
//              the AAC decoder (a missing symbol = capability answer)
//
// The contract with Dart:
//   - qa_video_export_supported() answers whether THIS build/OS can, so
//     the caller picks the ffmpeg fallback deliberately, never crashes.
//   - open() takes the frame geometry, the fps as an exact fraction, and
//     the audio shape (channels 0 = silent video).
//   - write_frame() takes top-down RGBA (exactly what the renderer's
//     rawRgba hands over); any BGRA/NV12 conversion happens HERE, beside
//     the encoder that wants it.
//   - write_audio() takes interleaved int16 PCM chunks, interleaved with
//     the frames by the caller so no side buffers the whole track.
//   - finish() finalizes the file (a cancelled run finalizes a playable
//     partial, matching the ffmpeg path's behavior); abort() discards.
//
// One export at a time, like the capture device: this is an offline
// render driven by one dialog.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define QA_EXPORT __declspec(dllexport)
#else
#define QA_EXPORT __attribute__((visibility("default")))
#endif

static char g_video_error[256];

static void qa_video_set_error(const char* message) {
  size_t index = 0;
  while (message[index] != '\0' && index < sizeof(g_video_error) - 1) {
    g_video_error[index] = message[index];
    index += 1;
  }
  g_video_error[index] = '\0';
}

// The last failure, UTF-8, for the export dialog to show verbatim.
QA_EXPORT int32_t qa_video_export_error(char* out, int32_t capacity) {
  if (out == NULL || capacity <= 1) {
    return -1;
  }
  int32_t length = 0;
  while (g_video_error[length] != '\0' && length < capacity - 1) {
    out[length] = g_video_error[length];
    length += 1;
  }
  out[length] = '\0';
  return length;
}

#if defined(_WIN32)
// ---------------------------------------------------------------------------
// Windows: Media Foundation Sink Writer. The writer owns the H.264 and AAC
// encoder MFTs AND the MP4 muxing; RGB32 input is converted to the
// encoder's YUV by MF's own color converter. Our only pixel job is
// RGBA → BGRA (MFVideoFormat_RGB32 is BGRA in memory) plus the even-size
// pad H.264 requires.

#define COBJMACROS
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>

typedef struct {
  IMFSinkWriter* writer;
  DWORD video_stream;
  DWORD audio_stream;
  int32_t src_width;
  int32_t src_height;
  int32_t width;   // padded even
  int32_t height;  // padded even
  int64_t fps_num;
  int64_t fps_den;
  int64_t frame_index;
  int64_t audio_samples;
  int32_t sample_rate;
  int32_t channels;
  int32_t open;
  int32_t mf_started;
} qa_video_win_state;

static qa_video_win_state g_win_video;

static void qa_video_win_teardown(void) {
  if (g_win_video.writer != NULL) {
    IMFSinkWriter_Release(g_win_video.writer);
    g_win_video.writer = NULL;
  }
  if (g_win_video.mf_started) {
    MFShutdown();
    g_win_video.mf_started = 0;
  }
  g_win_video.open = 0;
}

QA_EXPORT int32_t qa_video_export_supported(void) { return 1; }

QA_EXPORT int32_t qa_video_export_open(const char* utf8_path,
                                       int32_t width,
                                       int32_t height,
                                       int32_t fps_num,
                                       int32_t fps_den,
                                       int32_t sample_rate,
                                       int32_t channels) {
  if (g_win_video.open || utf8_path == NULL || width <= 0 || height <= 0 ||
      fps_num <= 0 || fps_den <= 0 || channels < 0 ||
      (channels > 0 && sample_rate <= 0)) {
    qa_video_set_error("video export: bad open parameters");
    return 0;
  }
  memset(&g_win_video, 0, sizeof(g_win_video));
  g_win_video.src_width = width;
  g_win_video.src_height = height;
  g_win_video.width = width + (width & 1);
  g_win_video.height = height + (height & 1);
  g_win_video.fps_num = fps_num;
  g_win_video.fps_den = fps_den;
  g_win_video.sample_rate = sample_rate;
  g_win_video.channels = channels;

  if (FAILED(MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
    qa_video_set_error("video export: Media Foundation failed to start");
    return 0;
  }
  g_win_video.mf_started = 1;

  WCHAR wide_path[1024];
  if (MultiByteToWideChar(CP_UTF8, 0, utf8_path, -1, wide_path, 1024) == 0) {
    qa_video_set_error("video export: the output path did not convert");
    qa_video_win_teardown();
    return 0;
  }

  HRESULT hr =
      MFCreateSinkWriterFromURL(wide_path, NULL, NULL, &g_win_video.writer);
  if (FAILED(hr)) {
    qa_video_set_error("video export: the MP4 file could not be created");
    qa_video_win_teardown();
    return 0;
  }

  // Quality: bits per pixel per frame in the range screen content wants.
  // 0.12 bpp lands ~7 Mbit/s at 1080p24 — visually clean for line art —
  // clamped so tiny and huge canvases both stay sane.
  int64_t bitrate = (int64_t)((double)g_win_video.width *
                              (double)g_win_video.height * (double)fps_num /
                              (double)fps_den * 0.12);
  if (bitrate < 2000000) {
    bitrate = 2000000;
  }
  if (bitrate > 50000000) {
    bitrate = 50000000;
  }

  IMFMediaType* video_out = NULL;
  hr = MFCreateMediaType(&video_out);
  if (SUCCEEDED(hr)) {
    IMFMediaType_SetGUID(video_out, &MF_MT_MAJOR_TYPE, &MFMediaType_Video);
    IMFMediaType_SetGUID(video_out, &MF_MT_SUBTYPE, &MFVideoFormat_H264);
    IMFMediaType_SetUINT32(video_out, &MF_MT_AVG_BITRATE, (UINT32)bitrate);
    IMFMediaType_SetUINT64(
        video_out, &MF_MT_FRAME_SIZE,
        ((UINT64)g_win_video.width << 32) | (UINT32)g_win_video.height);
    IMFMediaType_SetUINT64(video_out, &MF_MT_FRAME_RATE,
                           ((UINT64)(UINT32)fps_num << 32) | (UINT32)fps_den);
    IMFMediaType_SetUINT64(video_out, &MF_MT_PIXEL_ASPECT_RATIO,
                           ((UINT64)1 << 32) | 1);
    IMFMediaType_SetUINT32(video_out, &MF_MT_INTERLACE_MODE,
                           MFVideoInterlace_Progressive);
    hr = IMFSinkWriter_AddStream(g_win_video.writer, video_out,
                                 &g_win_video.video_stream);
  }
  if (SUCCEEDED(hr)) {
    IMFMediaType* video_in = NULL;
    hr = MFCreateMediaType(&video_in);
    if (SUCCEEDED(hr)) {
      IMFMediaType_SetGUID(video_in, &MF_MT_MAJOR_TYPE, &MFMediaType_Video);
      IMFMediaType_SetGUID(video_in, &MF_MT_SUBTYPE, &MFVideoFormat_RGB32);
      IMFMediaType_SetUINT64(
          video_in, &MF_MT_FRAME_SIZE,
          ((UINT64)g_win_video.width << 32) | (UINT32)g_win_video.height);
      IMFMediaType_SetUINT64(video_in, &MF_MT_FRAME_RATE,
                             ((UINT64)(UINT32)fps_num << 32) | (UINT32)fps_den);
      IMFMediaType_SetUINT64(video_in, &MF_MT_PIXEL_ASPECT_RATIO,
                             ((UINT64)1 << 32) | 1);
      IMFMediaType_SetUINT32(video_in, &MF_MT_INTERLACE_MODE,
                             MFVideoInterlace_Progressive);
      // Positive default stride = top-down rows, which is what the
      // renderer produces; MF's converter handles the flip to whatever
      // the encoder wants.
      IMFMediaType_SetUINT32(video_in, &MF_MT_DEFAULT_STRIDE,
                             (UINT32)(g_win_video.width * 4));
      hr = IMFSinkWriter_SetInputMediaType(
          g_win_video.writer, g_win_video.video_stream, video_in, NULL);
      IMFMediaType_Release(video_in);
    }
  }
  if (video_out != NULL) {
    IMFMediaType_Release(video_out);
  }
  if (FAILED(hr)) {
    qa_video_set_error("video export: no H.264 encoder accepted the frames");
    qa_video_win_teardown();
    return 0;
  }

  if (channels > 0) {
    IMFMediaType* audio_out = NULL;
    hr = MFCreateMediaType(&audio_out);
    if (SUCCEEDED(hr)) {
      IMFMediaType_SetGUID(audio_out, &MF_MT_MAJOR_TYPE, &MFMediaType_Audio);
      IMFMediaType_SetGUID(audio_out, &MF_MT_SUBTYPE, &MFAudioFormat_AAC);
      IMFMediaType_SetUINT32(audio_out, &MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
      IMFMediaType_SetUINT32(audio_out, &MF_MT_AUDIO_SAMPLES_PER_SECOND,
                             (UINT32)sample_rate);
      IMFMediaType_SetUINT32(audio_out, &MF_MT_AUDIO_NUM_CHANNELS,
                             (UINT32)channels);
      // 24000 bytes/s = 192 kbit/s — the AAC encoder's highest standard
      // step; a mixed master deserves it.
      IMFMediaType_SetUINT32(audio_out, &MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                             24000);
      hr = IMFSinkWriter_AddStream(g_win_video.writer, audio_out,
                                   &g_win_video.audio_stream);
      IMFMediaType_Release(audio_out);
    }
    if (SUCCEEDED(hr)) {
      IMFMediaType* audio_in = NULL;
      hr = MFCreateMediaType(&audio_in);
      if (SUCCEEDED(hr)) {
        IMFMediaType_SetGUID(audio_in, &MF_MT_MAJOR_TYPE, &MFMediaType_Audio);
        IMFMediaType_SetGUID(audio_in, &MF_MT_SUBTYPE, &MFAudioFormat_PCM);
        IMFMediaType_SetUINT32(audio_in, &MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
        IMFMediaType_SetUINT32(audio_in, &MF_MT_AUDIO_SAMPLES_PER_SECOND,
                               (UINT32)sample_rate);
        IMFMediaType_SetUINT32(audio_in, &MF_MT_AUDIO_NUM_CHANNELS,
                               (UINT32)channels);
        IMFMediaType_SetUINT32(audio_in, &MF_MT_AUDIO_BLOCK_ALIGNMENT,
                               (UINT32)(channels * 2));
        IMFMediaType_SetUINT32(
            audio_in, &MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
            (UINT32)(sample_rate * channels * 2));
        hr = IMFSinkWriter_SetInputMediaType(
            g_win_video.writer, g_win_video.audio_stream, audio_in, NULL);
        IMFMediaType_Release(audio_in);
      }
    }
    if (FAILED(hr)) {
      qa_video_set_error("video export: no AAC encoder accepted the mix");
      qa_video_win_teardown();
      return 0;
    }
  }

  if (FAILED(IMFSinkWriter_BeginWriting(g_win_video.writer))) {
    qa_video_set_error("video export: the writer refused to begin");
    qa_video_win_teardown();
    return 0;
  }
  g_win_video.open = 1;
  return 1;
}

// The frame's timestamp in 100 ns units — integer arithmetic on the exact
// fps fraction, the same discipline as every frame/sample conversion.
static int64_t qa_video_win_frame_time(int64_t frame) {
  return frame * 10000000 * g_win_video.fps_den / g_win_video.fps_num;
}

QA_EXPORT int32_t qa_video_export_write_frame(const uint8_t* rgba) {
  if (!g_win_video.open || rgba == NULL) {
    return 0;
  }
  const int32_t width = g_win_video.width;
  const int32_t height = g_win_video.height;
  const DWORD bytes = (DWORD)(width * height * 4);
  IMFMediaBuffer* buffer = NULL;
  if (FAILED(MFCreateMemoryBuffer(bytes, &buffer))) {
    qa_video_set_error("video export: out of memory for a frame");
    return 0;
  }
  BYTE* target = NULL;
  if (FAILED(IMFMediaBuffer_Lock(buffer, &target, NULL, NULL))) {
    IMFMediaBuffer_Release(buffer);
    return 0;
  }
  // RGBA (renderer) → BGRA (MF RGB32), top-down; padding pixels white so
  // an odd canvas gains a hairline of paper, not garbage.
  for (int32_t y = 0; y < height; y += 1) {
    BYTE* out_row = target + (size_t)y * (size_t)width * 4;
    if (y >= g_win_video.src_height) {
      memset(out_row, 0xFF, (size_t)width * 4);
      continue;
    }
    const uint8_t* in_row =
        rgba + (size_t)y * (size_t)g_win_video.src_width * 4;
    for (int32_t x = 0; x < g_win_video.src_width; x += 1) {
      out_row[x * 4 + 0] = in_row[x * 4 + 2];
      out_row[x * 4 + 1] = in_row[x * 4 + 1];
      out_row[x * 4 + 2] = in_row[x * 4 + 0];
      out_row[x * 4 + 3] = 0xFF;
    }
    for (int32_t x = g_win_video.src_width; x < width; x += 1) {
      out_row[x * 4 + 0] = 0xFF;
      out_row[x * 4 + 1] = 0xFF;
      out_row[x * 4 + 2] = 0xFF;
      out_row[x * 4 + 3] = 0xFF;
    }
  }
  IMFMediaBuffer_Unlock(buffer);
  IMFMediaBuffer_SetCurrentLength(buffer, bytes);

  IMFSample* sample = NULL;
  HRESULT hr = MFCreateSample(&sample);
  if (SUCCEEDED(hr)) {
    IMFSample_AddBuffer(sample, buffer);
    const int64_t time = qa_video_win_frame_time(g_win_video.frame_index);
    const int64_t next = qa_video_win_frame_time(g_win_video.frame_index + 1);
    IMFSample_SetSampleTime(sample, time);
    IMFSample_SetSampleDuration(sample, next - time);
    hr = IMFSinkWriter_WriteSample(g_win_video.writer,
                                   g_win_video.video_stream, sample);
    IMFSample_Release(sample);
  }
  IMFMediaBuffer_Release(buffer);
  if (FAILED(hr)) {
    qa_video_set_error("video export: a frame failed to encode");
    return 0;
  }
  g_win_video.frame_index += 1;
  return 1;
}

QA_EXPORT int32_t qa_video_export_write_audio(const int16_t* interleaved,
                                              int32_t frames) {
  if (!g_win_video.open || g_win_video.channels <= 0 ||
      interleaved == NULL || frames <= 0) {
    return 0;
  }
  const DWORD bytes = (DWORD)(frames * g_win_video.channels * 2);
  IMFMediaBuffer* buffer = NULL;
  if (FAILED(MFCreateMemoryBuffer(bytes, &buffer))) {
    return 0;
  }
  BYTE* target = NULL;
  if (FAILED(IMFMediaBuffer_Lock(buffer, &target, NULL, NULL))) {
    IMFMediaBuffer_Release(buffer);
    return 0;
  }
  memcpy(target, interleaved, bytes);
  IMFMediaBuffer_Unlock(buffer);
  IMFMediaBuffer_SetCurrentLength(buffer, bytes);

  IMFSample* sample = NULL;
  HRESULT hr = MFCreateSample(&sample);
  if (SUCCEEDED(hr)) {
    IMFSample_AddBuffer(sample, buffer);
    IMFSample_SetSampleTime(
        sample,
        g_win_video.audio_samples * 10000000 / g_win_video.sample_rate);
    IMFSample_SetSampleDuration(
        sample, (int64_t)frames * 10000000 / g_win_video.sample_rate);
    hr = IMFSinkWriter_WriteSample(g_win_video.writer,
                                   g_win_video.audio_stream, sample);
    IMFSample_Release(sample);
  }
  IMFMediaBuffer_Release(buffer);
  if (FAILED(hr)) {
    qa_video_set_error("video export: an audio chunk failed to encode");
    return 0;
  }
  g_win_video.audio_samples += frames;
  return 1;
}

QA_EXPORT int32_t qa_video_export_finish(void) {
  if (!g_win_video.open) {
    return 0;
  }
  const HRESULT hr = IMFSinkWriter_Finalize(g_win_video.writer);
  qa_video_win_teardown();
  if (FAILED(hr)) {
    qa_video_set_error("video export: the MP4 failed to finalize");
    return 0;
  }
  return 1;
}

QA_EXPORT void qa_video_export_abort(void) {
  if (g_win_video.open) {
    qa_video_win_teardown();
  }
}

#elif defined(__APPLE__)
// ---------------------------------------------------------------------------
// Apple: AVAssetWriter, implemented in qa_video_apple.m (Objective-C —
// the API is). This file only forwards, keeping the export surface in one
// portable TU.

extern int32_t qa_video_apple_open(const char* utf8_path,
                                   int32_t width,
                                   int32_t height,
                                   int32_t fps_num,
                                   int32_t fps_den,
                                   int32_t sample_rate,
                                   int32_t channels,
                                   char* error,
                                   int32_t error_capacity);
extern int32_t qa_video_apple_write_frame(const uint8_t* rgba);
extern int32_t qa_video_apple_write_audio(const int16_t* interleaved,
                                          int32_t frames);
extern int32_t qa_video_apple_finish(void);
extern void qa_video_apple_abort(void);

QA_EXPORT int32_t qa_video_export_supported(void) { return 1; }

QA_EXPORT int32_t qa_video_export_open(const char* utf8_path,
                                       int32_t width,
                                       int32_t height,
                                       int32_t fps_num,
                                       int32_t fps_den,
                                       int32_t sample_rate,
                                       int32_t channels) {
  return qa_video_apple_open(utf8_path, width, height, fps_num, fps_den,
                             sample_rate, channels, g_video_error,
                             (int32_t)sizeof(g_video_error));
}

QA_EXPORT int32_t qa_video_export_write_frame(const uint8_t* rgba) {
  return qa_video_apple_write_frame(rgba);
}

QA_EXPORT int32_t qa_video_export_write_audio(const int16_t* interleaved,
                                              int32_t frames) {
  return qa_video_apple_write_audio(interleaved, frames);
}

QA_EXPORT int32_t qa_video_export_finish(void) {
  return qa_video_apple_finish();
}

QA_EXPORT void qa_video_export_abort(void) { qa_video_apple_abort(); }

#elif defined(__ANDROID__)
// ---------------------------------------------------------------------------
// Android: NDK AMediaCodec (H.264 + AAC) and AMediaMuxer, resolved with
// dlsym exactly like the AAC decoder — libmediandk.so ships on every
// API 21+ device, and a missing symbol is a capability answer, not a
// crash. Color conversion RGBA → NV12 happens here (hardware encoders
// overwhelmingly accept COLOR_FormatYUV420SemiPlanar; the planar variant
// is the fallback).

#include <dlfcn.h>
#include <fcntl.h>
#include <unistd.h>

typedef struct AMediaCodec AMediaCodec;
typedef struct AMediaFormat AMediaFormat;
typedef struct AMediaMuxer AMediaMuxer;

typedef struct {
  int32_t offset;
  int32_t size;
  int64_t presentationTimeUs;
  uint32_t flags;
} qa_codec_buffer_info;

typedef struct {
  void* handle;
  AMediaFormat* (*format_new)(void);
  void (*format_delete)(AMediaFormat*);
  void (*format_set_string)(AMediaFormat*, const char*, const char*);
  void (*format_set_int32)(AMediaFormat*, const char*, int32_t);
  AMediaCodec* (*codec_create_encoder)(const char*);
  int32_t (*codec_configure)(AMediaCodec*, const AMediaFormat*, void*, void*,
                             uint32_t);
  int32_t (*codec_start)(AMediaCodec*);
  int32_t (*codec_stop)(AMediaCodec*);
  int32_t (*codec_delete)(AMediaCodec*);
  ssize_t (*codec_dequeue_input)(AMediaCodec*, int64_t);
  uint8_t* (*codec_get_input)(AMediaCodec*, size_t, size_t*);
  int32_t (*codec_queue_input)(AMediaCodec*, size_t, int64_t, size_t,
                               uint64_t, uint32_t);
  ssize_t (*codec_dequeue_output)(AMediaCodec*, qa_codec_buffer_info*,
                                  int64_t);
  uint8_t* (*codec_get_output)(AMediaCodec*, size_t, size_t*);
  int32_t (*codec_release_output)(AMediaCodec*, size_t, bool);
  AMediaFormat* (*codec_get_output_format)(AMediaCodec*);
  AMediaMuxer* (*muxer_new)(int, int32_t);
  ssize_t (*muxer_add_track)(AMediaMuxer*, const AMediaFormat*);
  int32_t (*muxer_start)(AMediaMuxer*);
  int32_t (*muxer_stop)(AMediaMuxer*);
  int32_t (*muxer_delete)(AMediaMuxer*);
  int32_t (*muxer_write)(AMediaMuxer*, size_t, const uint8_t*,
                         const qa_codec_buffer_info*);
} qa_ndk_media_encode;

static qa_ndk_media_encode g_ndk;

static int qa_ndk_encode_load(void) {
  if (g_ndk.handle != NULL) {
    return 1;
  }
  void* handle = dlopen("libmediandk.so", RTLD_NOW | RTLD_LOCAL);
  if (handle == NULL) {
    return 0;
  }
  g_ndk.format_new = (AMediaFormat * (*)(void)) dlsym(handle, "AMediaFormat_new");
  g_ndk.format_delete =
      (void (*)(AMediaFormat*))dlsym(handle, "AMediaFormat_delete");
  g_ndk.format_set_string = (void (*)(AMediaFormat*, const char*, const char*))
      dlsym(handle, "AMediaFormat_setString");
  g_ndk.format_set_int32 = (void (*)(AMediaFormat*, const char*, int32_t))
      dlsym(handle, "AMediaFormat_setInt32");
  g_ndk.codec_create_encoder = (AMediaCodec * (*)(const char*))
      dlsym(handle, "AMediaCodec_createEncoderByType");
  g_ndk.codec_configure =
      (int32_t (*)(AMediaCodec*, const AMediaFormat*, void*, void*, uint32_t))
          dlsym(handle, "AMediaCodec_configure");
  g_ndk.codec_start = (int32_t (*)(AMediaCodec*))dlsym(handle, "AMediaCodec_start");
  g_ndk.codec_stop = (int32_t (*)(AMediaCodec*))dlsym(handle, "AMediaCodec_stop");
  g_ndk.codec_delete =
      (int32_t (*)(AMediaCodec*))dlsym(handle, "AMediaCodec_delete");
  g_ndk.codec_dequeue_input = (ssize_t (*)(AMediaCodec*, int64_t))dlsym(
      handle, "AMediaCodec_dequeueInputBuffer");
  g_ndk.codec_get_input = (uint8_t * (*)(AMediaCodec*, size_t, size_t*))
      dlsym(handle, "AMediaCodec_getInputBuffer");
  g_ndk.codec_queue_input =
      (int32_t (*)(AMediaCodec*, size_t, int64_t, size_t, uint64_t, uint32_t))
          dlsym(handle, "AMediaCodec_queueInputBuffer");
  g_ndk.codec_dequeue_output =
      (ssize_t (*)(AMediaCodec*, qa_codec_buffer_info*, int64_t))dlsym(
          handle, "AMediaCodec_dequeueOutputBuffer");
  g_ndk.codec_get_output = (uint8_t * (*)(AMediaCodec*, size_t, size_t*))
      dlsym(handle, "AMediaCodec_getOutputBuffer");
  g_ndk.codec_release_output = (int32_t (*)(AMediaCodec*, size_t, bool))dlsym(
      handle, "AMediaCodec_releaseOutputBuffer");
  g_ndk.codec_get_output_format = (AMediaFormat * (*)(AMediaCodec*))
      dlsym(handle, "AMediaCodec_getOutputFormat");
  g_ndk.muxer_new = (AMediaMuxer * (*)(int, int32_t)) dlsym(handle, "AMediaMuxer_new");
  g_ndk.muxer_add_track = (ssize_t (*)(AMediaMuxer*, const AMediaFormat*))
      dlsym(handle, "AMediaMuxer_addTrack");
  g_ndk.muxer_start = (int32_t (*)(AMediaMuxer*))dlsym(handle, "AMediaMuxer_start");
  g_ndk.muxer_stop = (int32_t (*)(AMediaMuxer*))dlsym(handle, "AMediaMuxer_stop");
  g_ndk.muxer_delete =
      (int32_t (*)(AMediaMuxer*))dlsym(handle, "AMediaMuxer_delete");
  g_ndk.muxer_write =
      (int32_t (*)(AMediaMuxer*, size_t, const uint8_t*,
                   const qa_codec_buffer_info*))
          dlsym(handle, "AMediaMuxer_writeSampleData");
  if (g_ndk.format_new == NULL || g_ndk.codec_create_encoder == NULL ||
      g_ndk.muxer_new == NULL || g_ndk.muxer_write == NULL ||
      g_ndk.codec_queue_input == NULL || g_ndk.codec_dequeue_output == NULL) {
    dlclose(handle);
    return 0;
  }
  g_ndk.handle = handle;
  return 1;
}

#define QA_NDK_TRY_AGAIN (-1)
#define QA_NDK_FORMAT_CHANGED (-1012)
#define QA_NDK_BUFFERS_CHANGED (-1014)
#define QA_NDK_FLAG_CODEC_CONFIG 2u
#define QA_NDK_FLAG_END_OF_STREAM 4u

// One deferred encoder sample: output that arrived before the muxer had
// every track and could start.
typedef struct qa_pending_sample {
  struct qa_pending_sample* next;
  int32_t track;  // 0 = video, 1 = audio (muxer indexes resolve at start)
  qa_codec_buffer_info info;
  uint8_t data[];
} qa_pending_sample;

typedef struct {
  AMediaCodec* video_codec;
  AMediaCodec* audio_codec;
  AMediaMuxer* muxer;
  int fd;
  int32_t muxer_started;
  ssize_t video_track;
  ssize_t audio_track;
  qa_pending_sample* pending_head;
  qa_pending_sample* pending_tail;
  uint8_t* nv12;  // reused conversion buffer
  int32_t src_width;
  int32_t src_height;
  int32_t width;
  int32_t height;
  int64_t fps_num;
  int64_t fps_den;
  int64_t frame_index;
  int64_t audio_samples;
  int32_t sample_rate;
  int32_t channels;
  int32_t open;
} qa_video_android_state;

static qa_video_android_state g_droid;

QA_EXPORT int32_t qa_video_export_supported(void) {
  return qa_ndk_encode_load();
}

static void qa_droid_teardown(void) {
  qa_pending_sample* pending = g_droid.pending_head;
  while (pending != NULL) {
    qa_pending_sample* next = pending->next;
    free(pending);
    pending = next;
  }
  if (g_droid.video_codec != NULL) {
    g_ndk.codec_stop(g_droid.video_codec);
    g_ndk.codec_delete(g_droid.video_codec);
  }
  if (g_droid.audio_codec != NULL) {
    g_ndk.codec_stop(g_droid.audio_codec);
    g_ndk.codec_delete(g_droid.audio_codec);
  }
  if (g_droid.muxer != NULL) {
    if (g_droid.muxer_started) {
      g_ndk.muxer_stop(g_droid.muxer);
    }
    g_ndk.muxer_delete(g_droid.muxer);
  }
  if (g_droid.fd >= 0) {
    close(g_droid.fd);
  }
  free(g_droid.nv12);
  memset(&g_droid, 0, sizeof(g_droid));
  g_droid.fd = -1;
  g_droid.video_track = -1;
  g_droid.audio_track = -1;
}

// Queues [info]+[data] for the muxer, writing immediately once started.
static int qa_droid_emit(int32_t track,
                         const uint8_t* data,
                         const qa_codec_buffer_info* info) {
  const int32_t want_tracks = g_droid.channels > 0 ? 2 : 1;
  const int32_t have_tracks =
      (g_droid.video_track >= 0 ? 1 : 0) + (g_droid.audio_track >= 0 ? 1 : 0);
  if (!g_droid.muxer_started && have_tracks == want_tracks) {
    if (g_ndk.muxer_start(g_droid.muxer) != 0) {
      qa_video_set_error("video export: the MP4 muxer refused to start");
      return 0;
    }
    g_droid.muxer_started = 1;
    // Flush everything that queued while tracks were still being added.
    qa_pending_sample* pending = g_droid.pending_head;
    while (pending != NULL) {
      const size_t muxer_track = (size_t)(pending->track == 0
                                              ? g_droid.video_track
                                              : g_droid.audio_track);
      g_ndk.muxer_write(g_droid.muxer, muxer_track, pending->data,
                        &pending->info);
      qa_pending_sample* next = pending->next;
      free(pending);
      pending = next;
    }
    g_droid.pending_head = NULL;
    g_droid.pending_tail = NULL;
  }
  if (g_droid.muxer_started) {
    const size_t muxer_track =
        (size_t)(track == 0 ? g_droid.video_track : g_droid.audio_track);
    qa_codec_buffer_info adjusted = *info;
    adjusted.offset = 0;
    return g_ndk.muxer_write(g_droid.muxer, muxer_track, data, &adjusted) == 0;
  }
  qa_pending_sample* copy =
      (qa_pending_sample*)malloc(sizeof(qa_pending_sample) + (size_t)info->size);
  if (copy == NULL) {
    return 0;
  }
  copy->next = NULL;
  copy->track = track;
  copy->info = *info;
  copy->info.offset = 0;
  memcpy(copy->data, data, (size_t)info->size);
  if (g_droid.pending_tail == NULL) {
    g_droid.pending_head = copy;
  } else {
    g_droid.pending_tail->next = copy;
  }
  g_droid.pending_tail = copy;
  return 1;
}

// Drains one codec's ready output into the muxer (or the pending queue).
static int qa_droid_drain(AMediaCodec* codec, int32_t track) {
  while (1) {
    qa_codec_buffer_info info;
    const ssize_t index = g_ndk.codec_dequeue_output(codec, &info, 0);
    if (index == QA_NDK_TRY_AGAIN) {
      return 1;
    }
    if (index == QA_NDK_FORMAT_CHANGED) {
      AMediaFormat* format = g_ndk.codec_get_output_format(codec);
      const ssize_t added = g_ndk.muxer_add_track(g_droid.muxer, format);
      g_ndk.format_delete(format);
      if (added < 0) {
        qa_video_set_error("video export: the muxer rejected a track");
        return 0;
      }
      if (track == 0) {
        g_droid.video_track = added;
      } else {
        g_droid.audio_track = added;
      }
      continue;
    }
    if (index == QA_NDK_BUFFERS_CHANGED || index < 0) {
      continue;
    }
    size_t capacity = 0;
    uint8_t* data = g_ndk.codec_get_output(codec, (size_t)index, &capacity);
    int ok = 1;
    if (data != NULL && info.size > 0 &&
        (info.flags & QA_NDK_FLAG_CODEC_CONFIG) == 0) {
      ok = qa_droid_emit(track, data + info.offset, &info);
    }
    g_ndk.codec_release_output(codec, (size_t)index, false);
    if (!ok) {
      return 0;
    }
  }
}

static AMediaCodec* qa_droid_open_video_codec(int32_t color_format) {
  AMediaCodec* codec = g_ndk.codec_create_encoder("video/avc");
  if (codec == NULL) {
    return NULL;
  }
  AMediaFormat* format = g_ndk.format_new();
  g_ndk.format_set_string(format, "mime", "video/avc");
  g_ndk.format_set_int32(format, "width", g_droid.width);
  g_ndk.format_set_int32(format, "height", g_droid.height);
  int64_t bitrate = (int64_t)((double)g_droid.width * (double)g_droid.height *
                              (double)g_droid.fps_num /
                              (double)g_droid.fps_den * 0.12);
  if (bitrate < 2000000) {
    bitrate = 2000000;
  }
  if (bitrate > 50000000) {
    bitrate = 50000000;
  }
  g_ndk.format_set_int32(format, "bitrate", (int32_t)bitrate);
  g_ndk.format_set_int32(
      format, "frame-rate",
      (int32_t)((g_droid.fps_num + g_droid.fps_den / 2) / g_droid.fps_den));
  g_ndk.format_set_int32(format, "i-frame-interval", 1);
  g_ndk.format_set_int32(format, "color-format", color_format);
  const int32_t configured =
      g_ndk.codec_configure(codec, format, NULL, NULL, 1 /* encode */);
  g_ndk.format_delete(format);
  if (configured != 0 || g_ndk.codec_start(codec) != 0) {
    g_ndk.codec_delete(codec);
    return NULL;
  }
  return codec;
}

QA_EXPORT int32_t qa_video_export_open(const char* utf8_path,
                                       int32_t width,
                                       int32_t height,
                                       int32_t fps_num,
                                       int32_t fps_den,
                                       int32_t sample_rate,
                                       int32_t channels) {
  if (g_droid.open || utf8_path == NULL || width <= 0 || height <= 0 ||
      fps_num <= 0 || fps_den <= 0 || channels < 0 || !qa_ndk_encode_load()) {
    qa_video_set_error("video export: unsupported or bad parameters");
    return 0;
  }
  memset(&g_droid, 0, sizeof(g_droid));
  g_droid.fd = -1;
  g_droid.video_track = -1;
  g_droid.audio_track = -1;
  g_droid.src_width = width;
  g_droid.src_height = height;
  g_droid.width = width + (width & 1);
  g_droid.height = height + (height & 1);
  g_droid.fps_num = fps_num;
  g_droid.fps_den = fps_den;
  g_droid.sample_rate = sample_rate;
  g_droid.channels = channels;

  g_droid.fd = open(utf8_path, O_CREAT | O_TRUNC | O_RDWR, 0644);
  if (g_droid.fd < 0) {
    qa_video_set_error("video export: the output file could not be created");
    return 0;
  }
  g_droid.muxer = g_ndk.muxer_new(g_droid.fd, 0 /* MPEG_4 */);
  if (g_droid.muxer == NULL) {
    qa_video_set_error("video export: the MP4 muxer could not be created");
    qa_droid_teardown();
    return 0;
  }

  // 21 = COLOR_FormatYUV420SemiPlanar (NV12) — what hardware encoders
  // overwhelmingly take; 19 (planar I420) is the fallback.
  g_droid.video_codec = qa_droid_open_video_codec(21);
  int32_t semi_planar = 1;
  if (g_droid.video_codec == NULL) {
    g_droid.video_codec = qa_droid_open_video_codec(19);
    semi_planar = 0;
  }
  if (g_droid.video_codec == NULL) {
    qa_video_set_error("video export: no H.264 encoder accepted the frames");
    qa_droid_teardown();
    return 0;
  }
  // The NV12 buffer doubles as the flag for which layout to fill.
  g_droid.nv12 = (uint8_t*)malloc(
      (size_t)g_droid.width * (size_t)g_droid.height * 3 / 2 + 1);
  if (g_droid.nv12 == NULL) {
    qa_droid_teardown();
    return 0;
  }
  g_droid.nv12[(size_t)g_droid.width * (size_t)g_droid.height * 3 / 2] =
      (uint8_t)semi_planar;

  if (channels > 0) {
    g_droid.audio_codec = g_ndk.codec_create_encoder("audio/mp4a-latm");
    if (g_droid.audio_codec != NULL) {
      AMediaFormat* format = g_ndk.format_new();
      g_ndk.format_set_string(format, "mime", "audio/mp4a-latm");
      g_ndk.format_set_int32(format, "sample-rate", sample_rate);
      g_ndk.format_set_int32(format, "channel-count", channels);
      g_ndk.format_set_int32(format, "bitrate", 192000);
      g_ndk.format_set_int32(format, "aac-profile", 2 /* AAC LC */);
      const int32_t configured =
          g_ndk.codec_configure(g_droid.audio_codec, format, NULL, NULL, 1);
      g_ndk.format_delete(format);
      if (configured != 0 || g_ndk.codec_start(g_droid.audio_codec) != 0) {
        g_ndk.codec_delete(g_droid.audio_codec);
        g_droid.audio_codec = NULL;
      }
    }
    if (g_droid.audio_codec == NULL) {
      qa_video_set_error("video export: no AAC encoder accepted the mix");
      qa_droid_teardown();
      return 0;
    }
  }
  g_droid.open = 1;
  return 1;
}

QA_EXPORT int32_t qa_video_export_write_frame(const uint8_t* rgba) {
  if (!g_droid.open || rgba == NULL) {
    return 0;
  }
  const int32_t width = g_droid.width;
  const int32_t height = g_droid.height;
  const size_t luma_size = (size_t)width * (size_t)height;
  const int semi_planar = g_droid.nv12[luma_size * 3 / 2] != 0;
  // RGBA → YUV420 (BT.601 studio range — the convention H.264 players
  // assume for unflagged content). Pad pixels render white.
  for (int32_t y = 0; y < height; y += 1) {
    for (int32_t x = 0; x < width; x += 1) {
      int32_t r = 255;
      int32_t g = 255;
      int32_t b = 255;
      if (x < g_droid.src_width && y < g_droid.src_height) {
        const uint8_t* pixel =
            rgba + ((size_t)y * (size_t)g_droid.src_width + (size_t)x) * 4;
        r = pixel[0];
        g = pixel[1];
        b = pixel[2];
      }
      g_droid.nv12[(size_t)y * (size_t)width + (size_t)x] =
          (uint8_t)(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16);
      if ((x & 1) == 0 && (y & 1) == 0) {
        const uint8_t u = (uint8_t)(((-38 * r - 74 * g + 112 * b + 128) >> 8) +
                                    128);
        const uint8_t v = (uint8_t)(((112 * r - 94 * g - 18 * b + 128) >> 8) +
                                    128);
        const size_t chroma_index =
            (size_t)(y / 2) * (size_t)(width / 2) + (size_t)(x / 2);
        if (semi_planar) {
          g_droid.nv12[luma_size + chroma_index * 2] = u;
          g_droid.nv12[luma_size + chroma_index * 2 + 1] = v;
        } else {
          g_droid.nv12[luma_size + chroma_index] = u;
          g_droid.nv12[luma_size + luma_size / 4 + chroma_index] = v;
        }
      }
    }
  }

  const ssize_t input =
      g_ndk.codec_dequeue_input(g_droid.video_codec, 100000);
  if (input < 0) {
    qa_video_set_error("video export: the encoder stopped taking frames");
    return 0;
  }
  size_t capacity = 0;
  uint8_t* target =
      g_ndk.codec_get_input(g_droid.video_codec, (size_t)input, &capacity);
  const size_t frame_bytes = luma_size * 3 / 2;
  if (target == NULL || capacity < frame_bytes) {
    return 0;
  }
  memcpy(target, g_droid.nv12, frame_bytes);
  const int64_t time_us = g_droid.frame_index * 1000000 * g_droid.fps_den /
                          g_droid.fps_num;
  if (g_ndk.codec_queue_input(g_droid.video_codec, (size_t)input, 0,
                              frame_bytes, (uint64_t)time_us, 0) != 0) {
    return 0;
  }
  g_droid.frame_index += 1;
  return qa_droid_drain(g_droid.video_codec, 0);
}

QA_EXPORT int32_t qa_video_export_write_audio(const int16_t* interleaved,
                                              int32_t frames) {
  if (!g_droid.open || g_droid.audio_codec == NULL || interleaved == NULL ||
      frames <= 0) {
    return 0;
  }
  size_t remaining = (size_t)frames * (size_t)g_droid.channels * 2;
  const uint8_t* cursor = (const uint8_t*)interleaved;
  while (remaining > 0) {
    const ssize_t input =
        g_ndk.codec_dequeue_input(g_droid.audio_codec, 100000);
    if (input < 0) {
      qa_video_set_error("video export: the AAC encoder stopped taking audio");
      return 0;
    }
    size_t capacity = 0;
    uint8_t* target =
        g_ndk.codec_get_input(g_droid.audio_codec, (size_t)input, &capacity);
    if (target == NULL || capacity == 0) {
      return 0;
    }
    size_t chunk = remaining < capacity ? remaining : capacity;
    // Whole PCM frames only, so channel alignment never shifts.
    chunk -= chunk % ((size_t)g_droid.channels * 2);
    memcpy(target, cursor, chunk);
    const int64_t time_us =
        g_droid.audio_samples * 1000000 / g_droid.sample_rate;
    if (g_ndk.codec_queue_input(g_droid.audio_codec, (size_t)input, 0, chunk,
                                (uint64_t)time_us, 0) != 0) {
      return 0;
    }
    g_droid.audio_samples +=
        (int64_t)(chunk / ((size_t)g_droid.channels * 2));
    cursor += chunk;
    remaining -= chunk;
    if (!qa_droid_drain(g_droid.audio_codec, 1)) {
      return 0;
    }
  }
  return 1;
}

static void qa_droid_signal_end(AMediaCodec* codec) {
  const ssize_t input = g_ndk.codec_dequeue_input(codec, 100000);
  if (input >= 0) {
    g_ndk.codec_queue_input(codec, (size_t)input, 0, 0, 0,
                            QA_NDK_FLAG_END_OF_STREAM);
  }
}

QA_EXPORT int32_t qa_video_export_finish(void) {
  if (!g_droid.open) {
    return 0;
  }
  qa_droid_signal_end(g_droid.video_codec);
  if (g_droid.audio_codec != NULL) {
    qa_droid_signal_end(g_droid.audio_codec);
  }
  // Bounded drain of both tails: encoders flush within a few dequeues
  // once end-of-stream is queued.
  for (int spin = 0; spin < 1000; spin += 1) {
    if (!qa_droid_drain(g_droid.video_codec, 0)) {
      break;
    }
    if (g_droid.audio_codec != NULL && !qa_droid_drain(g_droid.audio_codec, 1)) {
      break;
    }
    qa_codec_buffer_info info;
    const ssize_t index =
        g_ndk.codec_dequeue_output(g_droid.video_codec, &info, 10000);
    if (index >= 0) {
      size_t capacity = 0;
      uint8_t* data =
          g_ndk.codec_get_output(g_droid.video_codec, (size_t)index, &capacity);
      if (data != NULL && info.size > 0 &&
          (info.flags & QA_NDK_FLAG_CODEC_CONFIG) == 0) {
        qa_droid_emit(0, data + info.offset, &info);
      }
      g_ndk.codec_release_output(g_droid.video_codec, (size_t)index, false);
      if ((info.flags & QA_NDK_FLAG_END_OF_STREAM) != 0) {
        break;
      }
      continue;
    }
    if (index == QA_NDK_TRY_AGAIN) {
      break;
    }
  }
  const int started = g_droid.muxer_started;
  qa_droid_teardown();
  if (!started) {
    qa_video_set_error("video export: the encoders never produced a stream");
    return 0;
  }
  return 1;
}

QA_EXPORT void qa_video_export_abort(void) {
  if (g_droid.open) {
    qa_droid_teardown();
  }
}

#else
// ---------------------------------------------------------------------------
// Linux (and anything else): no OS encoder story yet — the ffmpeg path
// remains, chosen by the caller because supported() said so.

QA_EXPORT int32_t qa_video_export_supported(void) { return 0; }

QA_EXPORT int32_t qa_video_export_open(const char* utf8_path,
                                       int32_t width,
                                       int32_t height,
                                       int32_t fps_num,
                                       int32_t fps_den,
                                       int32_t sample_rate,
                                       int32_t channels) {
  (void)utf8_path;
  (void)width;
  (void)height;
  (void)fps_num;
  (void)fps_den;
  (void)sample_rate;
  (void)channels;
  qa_video_set_error("video export: no OS encoder on this platform");
  return 0;
}

QA_EXPORT int32_t qa_video_export_write_frame(const uint8_t* rgba) {
  (void)rgba;
  return 0;
}

QA_EXPORT int32_t qa_video_export_write_audio(const int16_t* interleaved,
                                              int32_t frames) {
  (void)interleaved;
  (void)frames;
  return 0;
}

QA_EXPORT int32_t qa_video_export_finish(void) { return 0; }

QA_EXPORT void qa_video_export_abort(void) {}

#endif
