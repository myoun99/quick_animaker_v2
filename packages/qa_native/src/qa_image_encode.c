// The still-image encoder (EX4): baseline JPEG through vendored
// stb_image_write, memory to memory.
//
// Why native: Flutter's engine encodes PNG only, and the pub 'image'
// package would drag a large pure-Dart dependency for one codec. stb is
// the house pattern (dr_libs, stb_vorbis, miniaudio beside it): public
// domain, one file, byte-deterministic output — the encoder can be
// pinned by hash in tests like the rest of the engine.
//
// The contract with Dart:
//   - input is TOP-DOWN RGB24 (the caller flattens RGBA over the chosen
//     background — JPG carries no alpha, and the flatten is three lines
//     of Dart against a background color the spec owns).
//   - output is a malloc'd buffer handed to Dart, released with
//     qa_image_encode_free (never with Dart's allocator).

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define QA_EXPORT __declspec(dllexport)
#else
#define QA_EXPORT __attribute__((visibility("default")))
#endif

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STBI_WRITE_NO_STDIO
#include "third_party/stb/stb_image_write.h"

typedef struct {
  uint8_t* data;
  size_t size;
  size_t capacity;
  int failed;
} qa_jpg_sink;

static void qa_jpg_sink_write(void* context, void* data, int size) {
  qa_jpg_sink* sink = (qa_jpg_sink*)context;
  if (sink->failed || size <= 0) {
    return;
  }
  if (sink->size + (size_t)size > sink->capacity) {
    size_t next = sink->capacity == 0 ? 65536 : sink->capacity * 2;
    while (next < sink->size + (size_t)size) {
      next *= 2;
    }
    uint8_t* grown = (uint8_t*)realloc(sink->data, next);
    if (grown == NULL) {
      sink->failed = 1;
      return;
    }
    sink->data = grown;
    sink->capacity = next;
  }
  memcpy(sink->data + sink->size, data, (size_t)size);
  sink->size += (size_t)size;
}

// Encodes top-down RGB24 into a baseline JPEG. [quality] clamps to
// 1..100. On success *out_data/*out_size carry the malloc'd file bytes
// (caller frees via qa_image_encode_free) and 1 returns.
QA_EXPORT int32_t qa_image_encode_jpg(const uint8_t* rgb,
                                      int32_t width,
                                      int32_t height,
                                      int32_t quality,
                                      uint8_t** out_data,
                                      int32_t* out_size) {
  if (rgb == NULL || out_data == NULL || out_size == NULL || width <= 0 ||
      height <= 0) {
    return 0;
  }
  *out_data = NULL;
  *out_size = 0;
  if (quality < 1) {
    quality = 1;
  }
  if (quality > 100) {
    quality = 100;
  }
  qa_jpg_sink sink;
  memset(&sink, 0, sizeof(sink));
  const int ok = stbi_write_jpg_to_func(qa_jpg_sink_write, &sink, (int)width,
                                        (int)height, 3, rgb, (int)quality);
  if (!ok || sink.failed || sink.size == 0 ||
      sink.size > (size_t)INT32_MAX) {
    free(sink.data);
    return 0;
  }
  *out_data = sink.data;
  *out_size = (int32_t)sink.size;
  return 1;
}

QA_EXPORT void qa_image_encode_free(uint8_t* data) { free(data); }
