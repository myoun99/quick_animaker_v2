// The Apple half of the OS video encoder (AUDIO-PRO R7): AVAssetWriter.
//
// Objective-C on purpose — AVAssetWriter IS the OS's MP4 writer on both
// macOS and iOS (hardware H.264 through VideoToolbox, AAC through
// AudioToolbox, muxing included), and it has no C surface. The portable
// export API stays in qa_video_encode.c; this file implements the
// qa_video_apple_* functions it forwards to on __APPLE__.
//
// Compiled two ways, like the other Apple sources: CMake adds it to the
// standalone dylib (CI parity builds), and the ios/macos pods pick it up
// through a Classes/ forwarder.

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#include <stdint.h>
#include <string.h>

typedef struct {
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
} qa_video_apple_state;

static qa_video_apple_state g_apple;
static AVAssetWriter* g_writer;
static AVAssetWriterInput* g_video_input;
static AVAssetWriterInput* g_audio_input;
static AVAssetWriterInputPixelBufferAdaptor* g_adaptor;
static CMAudioFormatDescriptionRef g_audio_format;

static void qa_apple_set_error(char* error,
                               int32_t capacity,
                               const char* message) {
  if (error == NULL || capacity <= 1) {
    return;
  }
  int32_t index = 0;
  while (message[index] != '\0' && index < capacity - 1) {
    error[index] = message[index];
    index += 1;
  }
  error[index] = '\0';
}

static void qa_apple_teardown(void) {
  g_writer = nil;
  g_video_input = nil;
  g_audio_input = nil;
  g_adaptor = nil;
  if (g_audio_format != NULL) {
    CFRelease(g_audio_format);
    g_audio_format = NULL;
  }
  memset(&g_apple, 0, sizeof(g_apple));
}

int32_t qa_video_apple_open(const char* utf8_path,
                            int32_t width,
                            int32_t height,
                            int32_t fps_num,
                            int32_t fps_den,
                            int32_t sample_rate,
                            int32_t channels,
                            char* error,
                            int32_t error_capacity) {
  if (g_apple.open || utf8_path == NULL || width <= 0 || height <= 0 ||
      fps_num <= 0 || fps_den <= 0 || channels < 0) {
    qa_apple_set_error(error, error_capacity,
                       "video export: bad open parameters");
    return 0;
  }
  @autoreleasepool {
    memset(&g_apple, 0, sizeof(g_apple));
    g_apple.src_width = width;
    g_apple.src_height = height;
    g_apple.width = width + (width & 1);
    g_apple.height = height + (height & 1);
    g_apple.fps_num = fps_num;
    g_apple.fps_den = fps_den;
    g_apple.sample_rate = sample_rate;
    g_apple.channels = channels;

    NSString* path = [NSString stringWithUTF8String:utf8_path];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSError* writer_error = nil;
    g_writer = [[AVAssetWriter alloc]
        initWithURL:[NSURL fileURLWithPath:path]
           fileType:AVFileTypeMPEG4
              error:&writer_error];
    if (g_writer == nil) {
      qa_apple_set_error(error, error_capacity,
                         "video export: the MP4 file could not be created");
      qa_apple_teardown();
      return 0;
    }

    g_video_input = [[AVAssetWriterInput alloc]
        initWithMediaType:AVMediaTypeVideo
           outputSettings:@{
             AVVideoCodecKey : AVVideoCodecTypeH264,
             AVVideoWidthKey : @(g_apple.width),
             AVVideoHeightKey : @(g_apple.height),
           }];
    g_video_input.expectsMediaDataInRealTime = NO;
    g_adaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc]
        initWithAssetWriterInput:g_video_input
     sourcePixelBufferAttributes:@{
       (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
       (id)kCVPixelBufferWidthKey : @(g_apple.width),
       (id)kCVPixelBufferHeightKey : @(g_apple.height),
     }];
    if (![g_writer canAddInput:g_video_input]) {
      qa_apple_set_error(error, error_capacity,
                         "video export: no H.264 encoder accepted the frames");
      qa_apple_teardown();
      return 0;
    }
    [g_writer addInput:g_video_input];

    if (channels > 0) {
      g_audio_input = [[AVAssetWriterInput alloc]
          initWithMediaType:AVMediaTypeAudio
             outputSettings:@{
               AVFormatIDKey : @(kAudioFormatMPEG4AAC),
               AVSampleRateKey : @(sample_rate),
               AVNumberOfChannelsKey : @(channels),
               AVEncoderBitRateKey : @192000,
             }];
      g_audio_input.expectsMediaDataInRealTime = NO;
      if (![g_writer canAddInput:g_audio_input]) {
        qa_apple_set_error(error, error_capacity,
                           "video export: no AAC encoder accepted the mix");
        qa_apple_teardown();
        return 0;
      }
      [g_writer addInput:g_audio_input];

      AudioStreamBasicDescription pcm;
      memset(&pcm, 0, sizeof(pcm));
      pcm.mSampleRate = (Float64)sample_rate;
      pcm.mFormatID = kAudioFormatLinearPCM;
      pcm.mFormatFlags =
          kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
      pcm.mBytesPerPacket = (UInt32)(channels * 2);
      pcm.mFramesPerPacket = 1;
      pcm.mBytesPerFrame = (UInt32)(channels * 2);
      pcm.mChannelsPerFrame = (UInt32)channels;
      pcm.mBitsPerChannel = 16;
      if (CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &pcm, 0, NULL, 0,
                                         NULL, NULL,
                                         &g_audio_format) != noErr) {
        qa_apple_set_error(error, error_capacity,
                           "video export: the PCM description failed");
        qa_apple_teardown();
        return 0;
      }
    }

    if (![g_writer startWriting]) {
      qa_apple_set_error(error, error_capacity,
                         "video export: the writer refused to begin");
      qa_apple_teardown();
      return 0;
    }
    [g_writer startSessionAtSourceTime:kCMTimeZero];
    g_apple.open = 1;
    return 1;
  }
}

int32_t qa_video_apple_write_frame(const uint8_t* rgba) {
  if (!g_apple.open || rgba == NULL) {
    return 0;
  }
  @autoreleasepool {
    // Offline render: waiting for the writer is correct, and bounded in
    // practice by the encoder draining.
    int spins = 0;
    while (!g_video_input.readyForMoreMediaData) {
      usleep(1000);
      if (++spins > 10000) {
        return 0;
      }
    }
    CVPixelBufferRef pixel_buffer = NULL;
    CVPixelBufferPoolRef pool = g_adaptor.pixelBufferPool;
    if (pool == NULL ||
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool,
                                           &pixel_buffer) != kCVReturnSuccess) {
      return 0;
    }
    CVPixelBufferLockBaseAddress(pixel_buffer, 0);
    uint8_t* base = (uint8_t*)CVPixelBufferGetBaseAddress(pixel_buffer);
    const size_t stride = CVPixelBufferGetBytesPerRow(pixel_buffer);
    for (int32_t y = 0; y < g_apple.height; y += 1) {
      uint8_t* out_row = base + (size_t)y * stride;
      if (y >= g_apple.src_height) {
        memset(out_row, 0xFF, (size_t)g_apple.width * 4);
        continue;
      }
      const uint8_t* in_row =
          rgba + (size_t)y * (size_t)g_apple.src_width * 4;
      for (int32_t x = 0; x < g_apple.src_width; x += 1) {
        out_row[x * 4 + 0] = in_row[x * 4 + 2];  // B
        out_row[x * 4 + 1] = in_row[x * 4 + 1];  // G
        out_row[x * 4 + 2] = in_row[x * 4 + 0];  // R
        out_row[x * 4 + 3] = 0xFF;
      }
      for (int32_t x = g_apple.src_width; x < g_apple.width; x += 1) {
        out_row[x * 4 + 0] = 0xFF;
        out_row[x * 4 + 1] = 0xFF;
        out_row[x * 4 + 2] = 0xFF;
        out_row[x * 4 + 3] = 0xFF;
      }
    }
    CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);

    // frame i shows at i * den / num seconds — exact fraction, like every
    // other timing conversion in this program.
    const CMTime time = CMTimeMake(g_apple.frame_index * g_apple.fps_den,
                                   (int32_t)g_apple.fps_num);
    const BOOL appended = [g_adaptor appendPixelBuffer:pixel_buffer
                                  withPresentationTime:time];
    CVPixelBufferRelease(pixel_buffer);
    if (!appended) {
      return 0;
    }
    g_apple.frame_index += 1;
    return 1;
  }
}

int32_t qa_video_apple_write_audio(const int16_t* interleaved,
                                   int32_t frames) {
  if (!g_apple.open || g_audio_input == nil || interleaved == NULL ||
      frames <= 0) {
    return 0;
  }
  @autoreleasepool {
    int spins = 0;
    while (!g_audio_input.readyForMoreMediaData) {
      usleep(1000);
      if (++spins > 10000) {
        return 0;
      }
    }
    const size_t bytes = (size_t)frames * (size_t)g_apple.channels * 2;
    CMBlockBufferRef block = NULL;
    if (CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, NULL, bytes,
                                           kCFAllocatorDefault, NULL, 0, bytes,
                                           0, &block) != noErr) {
      return 0;
    }
    CMBlockBufferReplaceDataBytes(interleaved, block, 0, bytes);
    CMSampleBufferRef sample = NULL;
    const CMTime pts =
        CMTimeMake(g_apple.audio_samples, g_apple.sample_rate);
    const OSStatus status = CMAudioSampleBufferCreateWithPacketDescriptions(
        kCFAllocatorDefault, block, true, NULL, NULL, g_audio_format,
        (CMItemCount)frames, pts, NULL, &sample);
    CFRelease(block);
    if (status != noErr || sample == NULL) {
      return 0;
    }
    const BOOL appended = [g_audio_input appendSampleBuffer:sample];
    CFRelease(sample);
    if (!appended) {
      return 0;
    }
    g_apple.audio_samples += frames;
    return 1;
  }
}

int32_t qa_video_apple_finish(void) {
  if (!g_apple.open) {
    return 0;
  }
  @autoreleasepool {
    [g_video_input markAsFinished];
    if (g_audio_input != nil) {
      [g_audio_input markAsFinished];
    }
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block BOOL completed = NO;
    [g_writer finishWritingWithCompletionHandler:^{
      completed = (g_writer.status == AVAssetWriterStatusCompleted);
      dispatch_semaphore_signal(done);
    }];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    qa_apple_teardown();
    return completed ? 1 : 0;
  }
}

void qa_video_apple_abort(void) {
  if (!g_apple.open) {
    return;
  }
  @autoreleasepool {
    [g_writer cancelWriting];
    qa_apple_teardown();
  }
}
