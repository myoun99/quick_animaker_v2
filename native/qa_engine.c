// QuickAnimaker native engine core (R18 A-track).
//
// ONE portable C source, cross-compiled per platform (Windows DLL, macOS
// dylib, Android .so, ...). Every function here has a Dart REFERENCE
// implementation that stays in the tree forever; byte-parity between the
// two is pinned by tests, so the native core can never silently diverge.
//
// Arithmetic contract: Dart's double.round() rounds half AWAY FROM ZERO,
// exactly like C llround(); both sides run IEEE-754 doubles, so identical
// expressions produce identical bytes.

#include <math.h>
#include <stdint.h>

#if defined(_WIN32)
#define QA_EXPORT __declspec(dllexport)
#else
#define QA_EXPORT __attribute__((visibility("default")))
#endif

// Blends one stamp row span into a tile row (straight-alpha RGBA both
// sides) - the inner loop of the stamp dab path
// (materializeBrushDabSequenceOnBitmapSurface._blendStampDab).
//
//   tile_row:   tile pixels at the span start (4 bytes per pixel)
//   stamp_row:  stamp pixels at the span start (4 bytes per pixel)
//   count:      pixels in the span
//   opacity:    dab opacity in [0, 1]
//   erase:      nonzero = destination-out from stamp alpha
//
// Returns nonzero when any destination byte changed (the caller marks the
// tile dirty).
QA_EXPORT int32_t qa_stamp_blend_row(
    uint8_t* tile_row,
    const uint8_t* stamp_row,
    int32_t count,
    double opacity,
    int32_t erase) {
  int32_t changed = 0;
  for (int32_t i = 0; i < count; i += 1) {
    const uint8_t* src = stamp_row + (ptrdiff_t)i * 4;
    uint8_t* dst = tile_row + (ptrdiff_t)i * 4;
    const uint8_t stamp_a = src[3];
    if (stamp_a == 0) {
      continue;
    }

    // Opaque full-coverage fast paths (byte copy / byte zero) - must stay
    // semantically identical to the general math below at alpha 255,
    // opacity 1.
    if (stamp_a == 255 && opacity == 1.0) {
      if (erase) {
        if (dst[0] != 0 || dst[1] != 0 || dst[2] != 0 || dst[3] != 0) {
          dst[0] = 0;
          dst[1] = 0;
          dst[2] = 0;
          dst[3] = 0;
          changed = 1;
        }
      } else {
        if (dst[0] != src[0] || dst[1] != src[1] || dst[2] != src[2] ||
            dst[3] != 255) {
          dst[0] = src[0];
          dst[1] = src[1];
          dst[2] = src[2];
          dst[3] = 255;
          changed = 1;
        }
      }
      continue;
    }

    const double source_alpha = ((double)stamp_a / 255.0) * opacity;
    const uint8_t dest_r = dst[0];
    const uint8_t dest_g = dst[1];
    const uint8_t dest_b = dst[2];
    const uint8_t dest_a = dst[3];
    const double destination_alpha = (double)dest_a / 255.0;

    int64_t out_r;
    int64_t out_g;
    int64_t out_b;
    int64_t out_a;
    if (erase) {
      const double out_alpha = destination_alpha * (1.0 - source_alpha);
      if (out_alpha == 0.0) {
        out_r = 0;
        out_g = 0;
        out_b = 0;
        out_a = 0;
      } else {
        out_r = dest_r;
        out_g = dest_g;
        out_b = dest_b;
        out_a = llround(out_alpha * 255.0);
        if (out_a < 0) out_a = 0;
        if (out_a > 255) out_a = 255;
      }
    } else {
      const double out_alpha =
          source_alpha + destination_alpha * (1.0 - source_alpha);
      if (out_alpha == 0.0) {
        out_r = 0;
        out_g = 0;
        out_b = 0;
        out_a = 0;
      } else {
        const double inverse_source_alpha = 1.0 - source_alpha;
        out_r = llround(((double)src[0] * source_alpha +
                         (double)dest_r * destination_alpha *
                             inverse_source_alpha) /
                        out_alpha);
        out_g = llround(((double)src[1] * source_alpha +
                         (double)dest_g * destination_alpha *
                             inverse_source_alpha) /
                        out_alpha);
        out_b = llround(((double)src[2] * source_alpha +
                         (double)dest_b * destination_alpha *
                             inverse_source_alpha) /
                        out_alpha);
        out_a = llround(out_alpha * 255.0);
        if (out_r < 0) out_r = 0;
        if (out_r > 255) out_r = 255;
        if (out_g < 0) out_g = 0;
        if (out_g > 255) out_g = 255;
        if (out_b < 0) out_b = 0;
        if (out_b > 255) out_b = 255;
        if (out_a < 0) out_a = 0;
        if (out_a > 255) out_a = 255;
      }
    }

    if ((uint8_t)out_r != dest_r || (uint8_t)out_g != dest_g ||
        (uint8_t)out_b != dest_b || (uint8_t)out_a != dest_a) {
      dst[0] = (uint8_t)out_r;
      dst[1] = (uint8_t)out_g;
      dst[2] = (uint8_t)out_b;
      dst[3] = (uint8_t)out_a;
      changed = 1;
    }
  }
  return changed;
}

// Engine ABI version - the Dart loader refuses a mismatched binary.
QA_EXPORT int32_t qa_engine_abi_version(void) { return 1; }
