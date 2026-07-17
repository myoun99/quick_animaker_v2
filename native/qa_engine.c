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
#include <string.h>

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

// ---------------------------------------------------------------------------
// Generic dab blend (R18 A-1): the per-pixel section of
// materializeBrushDabSequenceOnBitmapSurface ported verbatim. All per-dab
// setup (trig, axis lattices, mask normalization) stays in Dart - this
// kernel only consumes precomputed data, so the float expressions here are
// EXACT transcriptions of the Dart reference (same grouping, same clamps,
// llround == double.round()). The Dart loop remains the reference oracle;
// the parity suite pins byte-identity.

enum {
  QA_DAB_FLAG_ERASE = 1,
  QA_DAB_FLAG_ROUND = 2,
  QA_DAB_FLAG_ELLIPSE = 4,
  QA_DAB_FLAG_ROTATED_RECT = 8,
  QA_DAB_FLAG_TIP_UNROTATED = 16,
};

// Field order/types MUST match the Dart QaDabSpecStruct exactly; the
// loader cross-checks qa_dab_spec_sizeof() against Dart's sizeOf<>().
// Layout: doubles, then an even number of int32s, then pointers - natural
// alignment with no implicit padding on every supported ABI.
typedef struct {
  double center_x;
  double center_y;
  double radius;
  double hard_radius;
  double edge_span;
  double minor_radius;
  double tip_cos;
  double tip_sin;
  double inverse_roundness;
  double dab_opacity;
  double dab_flow;
  double source_alpha_norm;
  double radius_sq_skip;
  double texture_density;
  double texture_one_minus_density;
  int32_t source_r;
  int32_t source_g;
  int32_t source_b;
  int32_t flags;
  int32_t region_left;
  int32_t region_top;
  int32_t tip_size;
  int32_t dual_size;
  int32_t tex_size;
  int32_t reserved;
  // Tip mask (alpha pre-divided by 255, row-major size*size doubles) plus
  // the unrotated-tip axis lattices (null when the tip is rotated).
  const double* tip_alpha;
  const int32_t* tip_u_texel0;
  const double* tip_u_fraction;
  const double* tip_u_one_minus;
  const uint8_t* tip_u_in_range;
  const int32_t* tip_v_texel0;
  const double* tip_v_fraction;
  const double* tip_v_one_minus;
  const uint8_t* tip_v_in_range;
  // Dual-brush tiled mask lattices (wrapped texel pairs).
  const double* dual_alpha;
  const int32_t* dual_u_texel0;
  const int32_t* dual_u_texel1;
  const double* dual_u_fraction;
  const double* dual_u_one_minus;
  const int32_t* dual_v_texel0;
  const int32_t* dual_v_texel1;
  const double* dual_v_fraction;
  const double* dual_v_one_minus;
  // Paper-texture tiled mask lattices (canvas anchored).
  const double* tex_alpha;
  const int32_t* tex_u_texel0;
  const int32_t* tex_u_texel1;
  const double* tex_u_fraction;
  const double* tex_u_one_minus;
  const int32_t* tex_v_texel0;
  const int32_t* tex_v_texel1;
  const double* tex_v_fraction;
  const double* tex_v_one_minus;
} qa_dab_spec;

QA_EXPORT int32_t qa_dab_spec_sizeof(void) {
  return (int32_t)sizeof(qa_dab_spec);
}

// Dart num.clamp(0.0, 1.0): lower on <, upper on >, otherwise the value.
static double qa_clamp01(double value) {
  if (value < 0.0) return 0.0;
  if (value > 1.0) return 1.0;
  return value;
}

// Dart .round().clamp(0, 255): llround is half-away-from-zero like Dart.
static int32_t qa_round_byte(double value) {
  int64_t rounded = llround(value);
  if (rounded < 0) return 0;
  if (rounded > 255) return 255;
  return (int32_t)rounded;
}

// sampleBrushTipMaskCoverage: scalar bilinear tip sample (rotated tips).
static double qa_sample_tip_scalar(
    const double* alpha,
    int32_t size,
    double tip_u,
    double tip_v,
    double radius) {
  const double scale = (double)size / (2.0 * radius);
  const double mask_x = (tip_u + radius) * scale - 0.5;
  const double mask_y = (tip_v + radius) * scale - 0.5;
  const double floor_x = floor(mask_x);
  const double floor_y = floor(mask_y);
  const int64_t x0 = (int64_t)floor_x;
  const int64_t y0 = (int64_t)floor_y;
  const double fraction_x = mask_x - floor_x;
  const double fraction_y = mask_y - floor_y;
  const int64_t x1 = x0 + 1;
  const int64_t y1 = y0 + 1;
  const int x0_in = x0 >= 0 && x0 < size;
  const int x1_in = x1 >= 0 && x1 < size;
  const double one_minus_fraction_x = 1.0 - fraction_x;

  double top = 0.0;
  if (y0 >= 0 && y0 < size) {
    const int64_t row = y0 * size;
    top = (x0_in ? alpha[row + x0] : 0.0) * one_minus_fraction_x +
          (x1_in ? alpha[row + x1] : 0.0) * fraction_x;
  }
  double bottom = 0.0;
  if (y1 >= 0 && y1 < size) {
    const int64_t row = y1 * size;
    bottom = (x0_in ? alpha[row + x0] : 0.0) * one_minus_fraction_x +
             (x1_in ? alpha[row + x1] : 0.0) * fraction_x;
  }
  return qa_clamp01(top * (1.0 - fraction_y) + bottom * fraction_y);
}

// sampleBrushTipMaskCoverageLattice: unrotated tip through axis lattices.
static double qa_sample_tip_lattice(
    const qa_dab_spec* s,
    int32_t u_index,
    int32_t v_index) {
  const int32_t size = s->tip_size;
  const double* alpha = s->tip_alpha;
  const int32_t x0 = s->tip_u_texel0[u_index];
  const int32_t y0 = s->tip_v_texel0[v_index];
  const int32_t x1 = x0 + 1;
  const int32_t y1 = y0 + 1;
  const double fraction_x = s->tip_u_fraction[u_index];
  const double one_minus_fraction_x = s->tip_u_one_minus[u_index];
  const int x0_in = x0 >= 0 && x0 < size;
  const int x1_in = x1 >= 0 && x1 < size;

  double top = 0.0;
  if (y0 >= 0 && y0 < size) {
    const int32_t row = y0 * size;
    top = (x0_in ? alpha[row + x0] : 0.0) * one_minus_fraction_x +
          (x1_in ? alpha[row + x1] : 0.0) * fraction_x;
  }
  double bottom = 0.0;
  if (y1 >= 0 && y1 < size) {
    const int32_t row = y1 * size;
    bottom = (x0_in ? alpha[row + x0] : 0.0) * one_minus_fraction_x +
             (x1_in ? alpha[row + x1] : 0.0) * fraction_x;
  }
  return qa_clamp01(
      top * s->tip_v_one_minus[v_index] + bottom * s->tip_v_fraction[v_index]);
}

// sampleBrushTipMaskTiledCoverageLattice: tiled mask (dual / texture)
// through wrapped axis lattices.
static double qa_sample_tiled_lattice(
    const double* alpha,
    int32_t size,
    const int32_t* u_texel0,
    const int32_t* u_texel1,
    const double* u_fraction,
    const double* u_one_minus,
    const int32_t* v_texel0,
    const int32_t* v_texel1,
    const double* v_fraction,
    const double* v_one_minus,
    int32_t u_index,
    int32_t v_index) {
  const int32_t x0 = u_texel0[u_index];
  const int32_t x1 = u_texel1[u_index];
  const int32_t row0 = v_texel0[v_index] * size;
  const int32_t row1 = v_texel1[v_index] * size;
  const double fraction_x = u_fraction[u_index];
  const double one_minus_fraction_x = u_one_minus[u_index];
  const double top =
      alpha[row0 + x0] * one_minus_fraction_x + alpha[row0 + x1] * fraction_x;
  const double bottom =
      alpha[row1 + x0] * one_minus_fraction_x + alpha[row1 + x1] * fraction_x;
  return qa_clamp01(
      top * v_one_minus[v_index] + bottom * v_fraction[v_index]);
}

// Blends one dab into one tile over the given canvas-space spans. Pixel
// visit set and math are identical to the Dart loop (which walks rows
// outermost; per-dab each pixel is touched exactly once either way).
// Returns nonzero when any destination byte changed.
QA_EXPORT int32_t qa_dab_blend_tile(
    uint8_t* tile_pixels,
    int32_t tile_size,
    int32_t tile_left,
    int32_t tile_top,
    int32_t span_left,
    int32_t span_right_exclusive,
    int32_t span_top,
    int32_t span_bottom_exclusive,
    const qa_dab_spec* s) {
  const int32_t flags = s->flags;
  const int erase = (flags & QA_DAB_FLAG_ERASE) != 0;
  const int is_round = (flags & QA_DAB_FLAG_ROUND) != 0;
  const int is_ellipse = (flags & QA_DAB_FLAG_ELLIPSE) != 0;
  const int is_rotated_rect = (flags & QA_DAB_FLAG_ROTATED_RECT) != 0;
  const int unrotated_tip = (flags & QA_DAB_FLAG_TIP_UNROTATED) != 0;
  const int has_tip = s->tip_alpha != NULL;
  const int has_dual = s->dual_alpha != NULL;
  const int has_tex = s->tex_alpha != NULL;
  int32_t changed = 0;

  for (int32_t y = span_top; y < span_bottom_exclusive; y += 1) {
    const int32_t v_index = y - s->region_top;
    if (has_tip && unrotated_tip && s->tip_v_in_range[v_index] == 0) {
      continue;
    }
    const double dy = (double)y + 0.5 - s->center_y;
    const double dy_squared = dy * dy;
    const int32_t local_row_offset = (y - tile_top) * tile_size;

    for (int32_t x = span_left; x < span_right_exclusive; x += 1) {
      double coverage;
      if (has_tip) {
        if (unrotated_tip) {
          const int32_t u_index = x - s->region_left;
          if (s->tip_u_in_range[u_index] == 0) {
            continue;
          }
          coverage = qa_sample_tip_lattice(s, u_index, v_index);
        } else {
          const double dx = (double)x + 0.5 - s->center_x;
          const double tip_u = dx * s->tip_cos - dy * s->tip_sin;
          const double tip_v =
              (dx * s->tip_sin + dy * s->tip_cos) * s->inverse_roundness;
          if (fabs(tip_u) > s->radius || fabs(tip_v) > s->radius) {
            continue;
          }
          coverage = qa_sample_tip_scalar(
              s->tip_alpha, s->tip_size, tip_u, tip_v, s->radius);
        }
        if (coverage <= 0.0) {
          continue;
        }
      } else if (is_round) {
        const double dx = (double)x + 0.5 - s->center_x;
        double distance;
        if (is_ellipse) {
          const double tip_u = dx * s->tip_cos - dy * s->tip_sin;
          const double tip_v =
              (dx * s->tip_sin + dy * s->tip_cos) * s->inverse_roundness;
          distance = sqrt(tip_u * tip_u + tip_v * tip_v);
        } else {
          const double dx_squared = dx * dx;
          if (dx_squared + dy_squared > s->radius_sq_skip) {
            continue;
          }
          distance = sqrt(dx_squared + dy_squared);
        }
        if (distance > s->radius) {
          continue;
        }
        if (distance <= s->hard_radius || s->edge_span <= 0.0) {
          coverage = 1.0;
        } else {
          coverage =
              qa_clamp01(1.0 - ((distance - s->hard_radius) / s->edge_span));
        }
        if (coverage <= 0.0) {
          continue;
        }
      } else {
        if (is_rotated_rect) {
          const double dx = (double)x + 0.5 - s->center_x;
          const double tip_u = dx * s->tip_cos - dy * s->tip_sin;
          const double tip_v = dx * s->tip_sin + dy * s->tip_cos;
          if (fabs(tip_u) > s->radius || fabs(tip_v) > s->minor_radius) {
            continue;
          }
        }
        coverage = 1.0;
      }

      if (has_dual) {
        coverage *= qa_sample_tiled_lattice(
            s->dual_alpha, s->dual_size, s->dual_u_texel0, s->dual_u_texel1,
            s->dual_u_fraction, s->dual_u_one_minus, s->dual_v_texel0,
            s->dual_v_texel1, s->dual_v_fraction, s->dual_v_one_minus,
            x - s->region_left, v_index);
        if (coverage <= 0.0) {
          continue;
        }
      }
      if (has_tex) {
        const double texture_sample = qa_sample_tiled_lattice(
            s->tex_alpha, s->tex_size, s->tex_u_texel0, s->tex_u_texel1,
            s->tex_u_fraction, s->tex_u_one_minus, s->tex_v_texel0,
            s->tex_v_texel1, s->tex_v_fraction, s->tex_v_one_minus,
            x - s->region_left, v_index);
        coverage *= s->texture_one_minus_density +
                    s->texture_density * texture_sample;
        if (coverage <= 0.0) {
          continue;
        }
      }

      const double effective_opacity = s->dab_opacity * coverage;
      if (effective_opacity == 0.0) {
        continue;
      }
      const double source_alpha =
          s->source_alpha_norm * effective_opacity * s->dab_flow;

      uint8_t* pixel =
          tile_pixels + (ptrdiff_t)(local_row_offset + (x - tile_left)) * 4;
      const uint8_t dest_r = pixel[0];
      const uint8_t dest_g = pixel[1];
      const uint8_t dest_b = pixel[2];
      const uint8_t dest_a = pixel[3];
      const double destination_alpha = (double)dest_a / 255.0;

      int32_t out_r;
      int32_t out_g;
      int32_t out_b;
      int32_t out_a;
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
          out_a = qa_round_byte(out_alpha * 255.0);
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
          out_r = qa_round_byte(
              ((double)s->source_r * source_alpha +
               (double)dest_r * destination_alpha * inverse_source_alpha) /
              out_alpha);
          out_g = qa_round_byte(
              ((double)s->source_g * source_alpha +
               (double)dest_g * destination_alpha * inverse_source_alpha) /
              out_alpha);
          out_b = qa_round_byte(
              ((double)s->source_b * source_alpha +
               (double)dest_b * destination_alpha * inverse_source_alpha) /
              out_alpha);
          out_a = qa_round_byte(out_alpha * 255.0);
        }
      }

      if ((uint8_t)out_r != dest_r || (uint8_t)out_g != dest_g ||
          (uint8_t)out_b != dest_b || (uint8_t)out_a != dest_a) {
        pixel[0] = (uint8_t)out_r;
        pixel[1] = (uint8_t)out_g;
        pixel[2] = (uint8_t)out_b;
        pixel[3] = (uint8_t)out_a;
        changed = 1;
      }
    }
  }
  return changed;
}

// ---------------------------------------------------------------------------
// Alpha premultiply (R18 A-2a): the display upload path's per-tile
// conversion (BitmapTileImageCache.premultipliedTilePixels) - straight
// alpha to premultiplied with Skia's own SkMulDiv255Round so uploads
// round identically to Skia's rasterization. Pure integer math, ported
// verbatim from the Dart reference.
QA_EXPORT void qa_premultiply_rgba(uint8_t* pixels, int32_t pixel_count) {
  for (int32_t i = 0; i < pixel_count; i += 1) {
    uint8_t* p = pixels + (ptrdiff_t)i * 4;
    const int32_t alpha = p[3];
    if (alpha == 255) {
      continue;
    }
    if (alpha == 0) {
      p[0] = 0;
      p[1] = 0;
      p[2] = 0;
      continue;
    }
    // SkMulDiv255Round: round(value * alpha / 255) for bytes.
    int32_t product = p[0] * alpha + 128;
    p[0] = (uint8_t)((product + (product >> 8)) >> 8);
    product = p[1] * alpha + 128;
    p[1] = (uint8_t)((product + (product >> 8)) >> 8);
    product = p[2] * alpha + 128;
    p[2] = (uint8_t)((product + (product >> 8)) >> 8);
  }
}

// Fused copy + premultiply (R19-Z): reads straight-alpha [src], writes
// premultiplied bytes into [dst] in one pass - the decode-start path
// used to pay a copy AND an in-place premultiply. Same SkMulDiv255Round
// math as qa_premultiply_rgba (byte-identical output by construction).
QA_EXPORT void qa_premultiply_rgba_copy(
    uint8_t* dst,
    const uint8_t* src,
    int32_t pixel_count) {
  for (int32_t i = 0; i < pixel_count; i += 1) {
    const uint8_t* s = src + (ptrdiff_t)i * 4;
    uint8_t* d = dst + (ptrdiff_t)i * 4;
    const int32_t alpha = s[3];
    if (alpha == 255) {
      d[0] = s[0];
      d[1] = s[1];
      d[2] = s[2];
      d[3] = 255;
      continue;
    }
    if (alpha == 0) {
      d[0] = 0;
      d[1] = 0;
      d[2] = 0;
      d[3] = 0;
      continue;
    }
    int32_t product = s[0] * alpha + 128;
    d[0] = (uint8_t)((product + (product >> 8)) >> 8);
    product = s[1] * alpha + 128;
    d[1] = (uint8_t)((product + (product >> 8)) >> 8);
    product = s[2] * alpha + 128;
    d[2] = (uint8_t)((product + (product >> 8)) >> 8);
    d[3] = (uint8_t)alpha;
  }
}

// Plain memcpy exposed to Dart (R19-Z): native-to-native tile staging at
// true memcpy speed - the VM's typed-data setRange was several times
// slower in debug builds, and staging copies 256KB per touched tile.
QA_EXPORT void qa_copy_bytes(
    uint8_t* dst,
    const uint8_t* src,
    int64_t length) {
  memcpy(dst, src, (size_t)length);
}

// ---------------------------------------------------------------------------
// Flood fill, frontier-stepped (R18 A-2b; RGBX + SSE2 R22-D).
//
// R22-D: the fill raster is RGBX - 4 bytes per pixel, X always 0 (the
// paper fill writes whole words and the compose never touches byte 3).
// One pixel is one 32-bit word and four pixels fill an SSE2 register,
// so the span loops below test 4 px per step; scalar tails keep every
// DECISION byte-identical to the Dart reference (which stays scalar
// RGBX - the parity suite pins identical filled sets).

#if defined(_M_X64) || defined(__x86_64__) || defined(__SSE2__) || \
    (defined(_M_IX86_FP) && _M_IX86_FP >= 2)
#define QA_FLOOD_SSE2 1
#include <emmintrin.h>
typedef __m128i qa_vec4;
static inline qa_vec4 qa_vec4_splat(uint32_t word) {
  return _mm_set1_epi32((int32_t)word);
}
#elif defined(__aarch64__)
// R28 NEON port: the ARM mirror of the SSE2 compare - same saturating
// abs-diff (vabd), same X-lane mask, same <= tol semantics, so the
// decisions stay byte-identical (the permanent Dart oracle pins them
// on-device). aarch64 only (vaddvq); 32-bit ARM keeps the scalar path.
#define QA_FLOOD_NEON 1
#include <arm_neon.h>
typedef uint8x16_t qa_vec4;
static inline qa_vec4 qa_vec4_splat(uint32_t word) {
  return vreinterpretq_u8_u32(vdupq_n_u32(word));
}
#endif

#if defined(QA_FLOOD_SSE2) || defined(QA_FLOOD_NEON)
#define QA_FLOOD_SIMD 1
#endif

// One-pixel tolerance test against the seed color (RGBX layout).
static inline int qa_tol_ok1(
    const uint8_t* px,
    int32_t seed_r,
    int32_t seed_g,
    int32_t seed_b,
    int32_t tolerance) {
  const int32_t dr = (int32_t)px[0] - seed_r;
  const int32_t dg = (int32_t)px[1] - seed_g;
  const int32_t db = (int32_t)px[2] - seed_b;
  return dr <= tolerance && -dr <= tolerance && dg <= tolerance &&
         -dg <= tolerance && db <= tolerance && -db <= tolerance;
}

#if defined(QA_FLOOD_SSE2)
// Bit i (0..3) set = pixel i of the 16-byte RGBX block is within
// tolerance of the seed on R, G and B. The X lane is MASKED OUT of the
// abs-diff, so the test matches the scalar compare under ANY X bytes -
// no hidden "X must be 0" contract. The per-byte |p-seed| <= tol via
// saturating unsigned abs-diff is exact for the integer compare above.
static inline int qa_tol_ok4(const uint8_t* rgbx, qa_vec4 seed4, qa_vec4 tol4) {
  const __m128i p = _mm_loadu_si128((const __m128i*)rgbx);
  const __m128i d = _mm_and_si128(
      _mm_or_si128(_mm_subs_epu8(p, seed4), _mm_subs_epu8(seed4, p)),
      _mm_set1_epi32(0x00FFFFFF));
  const __m128i ok8 =
      _mm_cmpeq_epi8(_mm_subs_epu8(d, tol4), _mm_setzero_si128());
  const __m128i ok32 = _mm_cmpeq_epi32(ok8, _mm_set1_epi32(-1));
  return _mm_movemask_ps(_mm_castsi128_ps(ok32));
}
#elif defined(QA_FLOOD_NEON)
static inline int qa_tol_ok4(const uint8_t* rgbx, qa_vec4 seed4, qa_vec4 tol4) {
  const uint8x16_t p = vld1q_u8(rgbx);
  const uint8x16_t xmask = vreinterpretq_u8_u32(vdupq_n_u32(0x00FFFFFFu));
  const uint8x16_t d = vandq_u8(vabdq_u8(p, seed4), xmask);
  const uint8x16_t ok8 = vcleq_u8(d, tol4);
  const uint32x4_t ok32 =
      vceqq_u32(vreinterpretq_u32_u8(ok8), vdupq_n_u32(0xFFFFFFFFu));
  const uint32x4_t weights = {1u, 2u, 4u, 8u};
  return (int)vaddvq_u32(vandq_u32(ok32, weights));
}
#endif

// EXACT port of the Dart scanline flood (floodFillRegion): expand each
// popped run left/right, seed the rows above/below once per contiguous
// matching run. The Dart original composes raster tiles LAZILY through a
// callback; C cannot call back into Dart, so composition is stepped
// instead: pixels that fall in a not-yet-composed 2^shift tile are
// reported as CANDIDATES and treated as run boundaries. The Dart driver
// composes those tiles, re-tests the candidates (filled[] dedupes), and
// re-enters with them as fresh seeds. A scanline flood fills the whole
// connected tolerance-region from any seed inside it, so the final
// filled set is identical to the single-pass reference - the parity
// suite pins it.
//
// Guards keep every early return BETWEEN runs (never mid-run): before a
// pop, the call returns if the candidate buffer could not absorb a
// whole worst-case run (~4*width) or the stack could not absorb its
// pushes (~width). The driver then composes / grows and re-enters with
// the stack state intact (it lives in caller-owned native memory).
//
// Returns the number of candidate pixel indices written.
QA_EXPORT int32_t qa_flood_fill_step(
    const uint8_t* rgb,
    uint8_t* filled,
    const uint8_t* composed,
    int32_t width,
    int32_t height,
    int32_t compose_tile_shift,
    int32_t tiles_x,
    int32_t seed_r,
    int32_t seed_g,
    int32_t seed_b,
    int32_t tolerance,
    int32_t* stack,
    int32_t* stack_size,
    int32_t stack_capacity,
    int32_t* candidates,
    int32_t candidates_capacity,
    int32_t* bounds) {
  int32_t candidate_count = 0;
  const int32_t candidate_margin = 4 * width + 16;
  const int32_t stack_margin = width + 4;
  int32_t min_x = bounds[0];
  int32_t max_x = bounds[1];
  int32_t min_y = bounds[2];
  int32_t max_y = bounds[3];
#ifdef QA_FLOOD_SIMD
  const qa_vec4 seed4 = qa_vec4_splat(
      (uint32_t)seed_r | ((uint32_t)seed_g << 8) |
      ((uint32_t)seed_b << 16));
  const qa_vec4 tol4 = qa_vec4_splat(
      (uint32_t)tolerance | ((uint32_t)tolerance << 8) |
      ((uint32_t)tolerance << 16));
#endif

  while (*stack_size > 0) {
    if (candidate_count + candidate_margin > candidates_capacity ||
        *stack_size + stack_margin > stack_capacity) {
      break;
    }
    *stack_size -= 1;
    const int32_t index = stack[*stack_size];
    const int32_t y = index / width;
    const int32_t row_start = y * width;
    const int32_t tile_row = (y >> compose_tile_shift) * tiles_x;

    // Expand the scanline run left and right; an uncomposed tile is a
    // candidate + run boundary (the driver re-seeds it after compose).
    // Scans run per compose-tile SEGMENT (composed[] is constant inside
    // one), 4 px per SSE2 step with a scalar tail owning every edge
    // decision - identical stop points to the plain loop.
    int32_t left = index - row_start;
    for (;;) {
      if (left <= 0 || filled[row_start + left - 1] != 0) {
        break;
      }
      const int32_t px = left - 1;
      if (composed[tile_row + (px >> compose_tile_shift)] == 0) {
        candidates[candidate_count] = row_start + px;
        candidate_count += 1;
        break;
      }
      const int32_t seg_start = (px >> compose_tile_shift)
                                << compose_tile_shift;
      int32_t x = px;
      int32_t stop = 0;
#ifdef QA_FLOOD_SIMD
      while (x - 3 >= seg_start) {
        uint32_t f4;
        memcpy(&f4, filled + row_start + x - 3, 4);
        if (f4 != 0) {
          break;
        }
        if (qa_tol_ok4(
                rgb + ((ptrdiff_t)(row_start + x - 3) << 2), seed4, tol4) !=
            0xF) {
          break;
        }
        memset(filled + row_start + x - 3, 255, 4);
        x -= 4;
      }
#endif
      while (x >= seg_start) {
        const int32_t p = row_start + x;
        if (filled[p] != 0 ||
            !qa_tol_ok1(
                rgb + ((ptrdiff_t)p << 2), seed_r, seed_g, seed_b,
                tolerance)) {
          stop = 1;
          break;
        }
        filled[p] = 255;
        x -= 1;
      }
      left = x + 1;
      if (stop) {
        break;
      }
    }
    int32_t right = index - row_start;
    for (;;) {
      if (right >= width - 1 || filled[row_start + right + 1] != 0) {
        break;
      }
      const int32_t px = right + 1;
      if (composed[tile_row + (px >> compose_tile_shift)] == 0) {
        candidates[candidate_count] = row_start + px;
        candidate_count += 1;
        break;
      }
      int32_t seg_end =
          ((((px >> compose_tile_shift) + 1) << compose_tile_shift)) - 1;
      if (seg_end > width - 1) {
        seg_end = width - 1;
      }
      int32_t x = px;
      int32_t stop = 0;
#ifdef QA_FLOOD_SIMD
      while (x + 3 <= seg_end) {
        uint32_t f4;
        memcpy(&f4, filled + row_start + x, 4);
        if (f4 != 0) {
          break;
        }
        if (qa_tol_ok4(rgb + ((ptrdiff_t)(row_start + x) << 2), seed4, tol4) !=
            0xF) {
          break;
        }
        memset(filled + row_start + x, 255, 4);
        x += 4;
      }
#endif
      while (x <= seg_end) {
        const int32_t p = row_start + x;
        if (filled[p] != 0 ||
            !qa_tol_ok1(
                rgb + ((ptrdiff_t)p << 2), seed_r, seed_g, seed_b,
                tolerance)) {
          stop = 1;
          break;
        }
        filled[p] = 255;
        x += 1;
      }
      right = x - 1;
      if (stop) {
        break;
      }
    }
    if (left < min_x) min_x = left;
    if (right > max_x) max_x = right;
    if (y < min_y) min_y = y;
    if (y > max_y) max_y = y;

    // Seed the rows above and below across the run - ONE seed per
    // contiguous matching run; uncomposed pixels are candidates and
    // close the current run exactly like a non-match. The composed
    // check hoists per segment; the SSE2 block computes a 4-px match
    // mask (unfilled AND within tolerance) and a scalar walk over the
    // bits runs the run_open state machine - decision-identical to the
    // plain loop.
    for (int32_t direction = 0; direction < 2; direction += 1) {
      const int32_t neighbor_y = direction == 0 ? y - 1 : y + 1;
      if (neighbor_y < 0 || neighbor_y >= height) {
        continue;
      }
      const int32_t neighbor_row = neighbor_y * width;
      const int32_t neighbor_tile_row =
          (neighbor_y >> compose_tile_shift) * tiles_x;
      int32_t run_open = 0;
      int32_t x = left;
      while (x <= right) {
        if (composed[neighbor_tile_row + (x >> compose_tile_shift)] == 0) {
          candidates[candidate_count] = neighbor_row + x;
          candidate_count += 1;
          run_open = 0;
          x += 1;
          continue;
        }
        int32_t seg_end =
            ((((x >> compose_tile_shift) + 1) << compose_tile_shift)) - 1;
        if (seg_end > right) {
          seg_end = right;
        }
#ifdef QA_FLOOD_SIMD
        while (x + 3 <= seg_end) {
          const int32_t p0 = neighbor_row + x;
          uint32_t f4;
          memcpy(&f4, filled + p0, 4);
          int32_t match =
              qa_tol_ok4(rgb + ((ptrdiff_t)p0 << 2), seed4, tol4);
          // Clear match bits for already-filled pixels (they close a
          // run exactly like a non-match in the reference loop).
          if (f4 != 0) {
            if (f4 & 0xFFu) match &= ~1;
            if (f4 & 0xFF00u) match &= ~2;
            if (f4 & 0xFF0000u) match &= ~4;
            if (f4 & 0xFF000000u) match &= ~8;
          }
          if (match == 0) {
            run_open = 0;
            x += 4;
            continue;
          }
          for (int32_t i = 0; i < 4; i += 1) {
            if (match & (1 << i)) {
              if (!run_open) {
                const int32_t p = p0 + i;
                filled[p] = 255;
                stack[*stack_size] = p;
                *stack_size += 1;
                run_open = 1;
              }
            } else {
              run_open = 0;
            }
          }
          x += 4;
        }
#endif
        while (x <= seg_end) {
          const int32_t p = neighbor_row + x;
          if (filled[p] == 0 &&
              qa_tol_ok1(
                  rgb + ((ptrdiff_t)p << 2), seed_r, seed_g, seed_b,
                  tolerance)) {
            if (!run_open) {
              filled[p] = 255;
              stack[*stack_size] = p;
              *stack_size += 1;
              run_open = 1;
            }
          } else {
            run_open = 0;
          }
          x += 1;
        }
      }
    }
  }

  bounds[0] = min_x;
  bounds[1] = max_x;
  bounds[2] = min_y;
  bounds[3] = max_y;
  return candidate_count;
}

// ---------------------------------------------------------------------------
// Fill raster compose (R18 A-2c): LazyCanvasRasterRgb's per-tile compose
// ported verbatim - the clean-run lab showed the lazy compose (paper
// fill + integer source-over of layer tiles onto the RGB raster) is
// most of what remains inside the fill.flood probe now that the flood
// itself is native.

// Fills a raster rect with the paper color (RGBX, 4 bytes per pixel;
// X writes 0 for determinism - the SIMD tolerance compare masks the X
// lane out, so nothing depends on it).
QA_EXPORT void qa_fill_paper_rect(
    uint8_t* rgb,
    int32_t raster_width,
    int32_t left,
    int32_t top,
    int32_t right_exclusive,
    int32_t bottom_exclusive,
    int32_t paper_r,
    int32_t paper_g,
    int32_t paper_b) {
  const uint32_t paper = (uint32_t)paper_r | ((uint32_t)paper_g << 8) |
                         ((uint32_t)paper_b << 16);
  for (int32_t y = top; y < bottom_exclusive; y += 1) {
    uint32_t* dst =
        (uint32_t*)(rgb + (((ptrdiff_t)y * raster_width + left) << 2));
    for (int32_t x = left; x < right_exclusive; x += 1) {
      *dst = paper;
      dst += 1;
    }
  }
}

// Integer source-over of one RGBA surface-tile clip onto the RGBX
// raster (byte-rounded, exactly the Dart loop: effective =
// (a*o+127)/255 etc.). The X byte stays untouched (0 from the paper
// fill).
QA_EXPORT void qa_fill_compose_tile(
    uint8_t* rgb,
    int32_t raster_width,
    const uint8_t* tile_pixels,
    int32_t tile_size,
    int32_t base_x,
    int32_t base_y,
    int32_t clip_left,
    int32_t clip_top,
    int32_t clip_right_exclusive,
    int32_t clip_bottom_exclusive,
    int32_t opacity_int) {
  for (int32_t y = clip_top; y < clip_bottom_exclusive; y += 1) {
    const uint8_t* src =
        tile_pixels +
        ((ptrdiff_t)(y - base_y) * tile_size + (clip_left - base_x)) * 4;
    uint8_t* dst = rgb + (((ptrdiff_t)y * raster_width + clip_left) << 2);
    for (int32_t x = clip_left; x < clip_right_exclusive; x += 1) {
      const int32_t alpha = src[3];
      if (alpha != 0) {
        const int32_t effective = (alpha * opacity_int + 127) / 255;
        const int32_t inverse = 255 - effective;
        dst[0] = (uint8_t)((src[0] * effective + dst[0] * inverse + 127) / 255);
        dst[1] = (uint8_t)((src[1] * effective + dst[1] * inverse + 127) / 255);
        dst[2] = (uint8_t)((src[2] * effective + dst[2] * inverse + 127) / 255);
      }
      src += 4;
      dst += 4;
    }
  }
}

// ---------------------------------------------------------------------------
// Fill mask finish (R18 A-2d / R24-A1 parallel): crop + expand +
// anti-alias, byte-identical to the Dart tail. Every pass reads one
// generation and writes another, so ROW BANDS are embarrassingly
// parallel - they fan out across the worker pool (R24-A1: at 8K these
// full-region passes were the largest remaining sequential slice of
// fill.flood). Generations ping-pong between `mask` and `scratch`; a
// final banded copy lands the result in `mask` when the pass count is
// odd.

// The pool lives further down with the tile-batch machinery.
typedef void (*qa_job_fn)(int32_t item_index, void* context);
static void qa_pool_run(qa_job_fn job_fn, void* context, int32_t item_count);

#define QA_FINISH_BAND_ROWS 64

typedef struct {
  const uint8_t* filled; // Crop source (mode 0 only).
  int32_t canvas_width;
  int32_t crop_left;
  int32_t crop_top;
  const uint8_t* src; // Read generation (modes 1-3).
  uint8_t* dst;       // Write generation.
  int32_t region_width;
  int32_t region_height;
  int32_t mode; // 0=crop, 1=expand, 2=anti-alias, 3=plain copy.
} qa_finish_band_context;

static void qa_finish_band_item(int32_t item_index, void* context) {
  const qa_finish_band_context* c = (const qa_finish_band_context*)context;
  const int32_t width = c->region_width;
  const int32_t y0 = item_index * QA_FINISH_BAND_ROWS;
  int32_t y1 = y0 + QA_FINISH_BAND_ROWS;
  if (y1 > c->region_height) {
    y1 = c->region_height;
  }
  switch (c->mode) {
    case 0:
      for (int32_t y = y0; y < y1; y += 1) {
        memcpy(
            c->dst + (ptrdiff_t)y * width,
            c->filled + (ptrdiff_t)(c->crop_top + y) * c->canvas_width +
                c->crop_left,
            (size_t)width);
      }
      return;
    case 3:
      memcpy(
          c->dst + (ptrdiff_t)y0 * width,
          c->src + (ptrdiff_t)y0 * width,
          (size_t)(y1 - y0) * (size_t)width);
      return;
    case 1:
      // Expand: dst = src, then zero pixels touching a nonzero
      // 4-neighbor become 255 - identical to the Dart grown-copy.
      for (int32_t y = y0; y < y1; y += 1) {
        const uint8_t* src_row = c->src + (ptrdiff_t)y * width;
        uint8_t* dst_row = c->dst + (ptrdiff_t)y * width;
        memcpy(dst_row, src_row, (size_t)width);
        for (int32_t x = 0; x < width; x += 1) {
          if (src_row[x] != 0) {
            continue;
          }
          const int touches =
              (x > 0 && src_row[x - 1] != 0) ||
              (x < width - 1 && src_row[x + 1] != 0) ||
              (y > 0 && c->src[(ptrdiff_t)(y - 1) * width + x] != 0) ||
              (y < c->region_height - 1 &&
               c->src[(ptrdiff_t)(y + 1) * width + x] != 0);
          if (touches) {
            dst_row[x] = 255;
          }
        }
      }
      return;
    default:
      // Anti-alias: boundary pixels average their 4-neighbors; the
      // Dart formula rounds a double division, so this stays double +
      // llround for byte identity.
      for (int32_t y = y0; y < y1; y += 1) {
        const uint8_t* src_row = c->src + (ptrdiff_t)y * width;
        uint8_t* dst_row = c->dst + (ptrdiff_t)y * width;
        memcpy(dst_row, src_row, (size_t)width);
        for (int32_t x = 0; x < width; x += 1) {
          const int32_t center = src_row[x];
          const int32_t left_v = x > 0 ? src_row[x - 1] : 0;
          const int32_t right_v = x < width - 1 ? src_row[x + 1] : 0;
          const int32_t up_v =
              y > 0 ? c->src[(ptrdiff_t)(y - 1) * width + x] : 0;
          const int32_t down_v = y < c->region_height - 1
              ? c->src[(ptrdiff_t)(y + 1) * width + x]
              : 0;
          const int32_t sum = center + left_v + right_v + up_v + down_v;
          if (sum != center * 5) {
            const int64_t rounded =
                llround((double)(center * 3 + (sum - center)) / 7.0);
            dst_row[x] = (uint8_t)rounded;
          }
        }
      }
      return;
  }
}

QA_EXPORT void qa_fill_finish_mask(
    const uint8_t* filled,
    int32_t canvas_width,
    int32_t crop_left,
    int32_t crop_top,
    int32_t region_width,
    int32_t region_height,
    int32_t expand_px,
    int32_t anti_alias,
    uint8_t* mask,
    uint8_t* scratch) {
  const int32_t bands =
      (region_height + QA_FINISH_BAND_ROWS - 1) / QA_FINISH_BAND_ROWS;
  qa_finish_band_context context;
  context.filled = filled;
  context.canvas_width = canvas_width;
  context.crop_left = crop_left;
  context.crop_top = crop_top;
  context.region_width = region_width;
  context.region_height = region_height;

  context.mode = 0;
  context.src = NULL;
  context.dst = mask;
  qa_pool_run(qa_finish_band_item, &context, bands);

  // Ping-pong generations through the passes; land back in `mask`.
  uint8_t* current = mask;
  uint8_t* other = scratch;
  for (int32_t pass = 0; pass < expand_px; pass += 1) {
    context.mode = 1;
    context.src = current;
    context.dst = other;
    qa_pool_run(qa_finish_band_item, &context, bands);
    uint8_t* swap = current;
    current = other;
    other = swap;
  }
  if (anti_alias) {
    context.mode = 2;
    context.src = current;
    context.dst = other;
    qa_pool_run(qa_finish_band_item, &context, bands);
    uint8_t* swap = current;
    current = other;
    other = swap;
  }
  if (current != mask) {
    context.mode = 3;
    context.src = current;
    context.dst = mask;
    qa_pool_run(qa_finish_band_item, &context, bands);
  }
}

// ---------------------------------------------------------------------------
// Batched fill compose (R25-3): the lazy raster used to compose each
// 256px tile through per-tile serial FFI calls (paper rect + one call
// per intersecting layer tile). One batch call now fans compose TILES
// across the worker pool; within one tile the paper fill and the layer
// blends run sequentially in order (source-over order IS the bytes),
// and tiles are disjoint - so the result is byte-identical to the
// serial path while the wall time divides by cores.

// One layer-tile blend of a batch. Field order/types MUST match the
// Dart QaComposeBlendStruct exactly; the loader cross-checks sizeof.
typedef struct {
  uint8_t* tile_pixels;
  int32_t tile_size;
  int32_t base_x;
  int32_t base_y;
  int32_t clip_left;
  int32_t clip_top;
  int32_t clip_right_exclusive;
  int32_t clip_bottom_exclusive;
  int32_t opacity_int;
  int32_t reserved;
} qa_compose_blend;

QA_EXPORT int32_t qa_compose_blend_sizeof(void) {
  return (int32_t)sizeof(qa_compose_blend);
}

// One compose TILE of a batch: paper-fill its rect, then run its slice
// of the shared blend array in order. Mirrors QaComposeTileItemStruct.
typedef struct {
  int32_t tile_left;
  int32_t tile_top;
  int32_t tile_right_exclusive;
  int32_t tile_bottom_exclusive;
  int32_t first_blend;
  int32_t blend_count;
} qa_compose_tile_item;

QA_EXPORT int32_t qa_compose_tile_item_sizeof(void) {
  return (int32_t)sizeof(qa_compose_tile_item);
}

static struct {
  uint8_t* rgb;
  int32_t raster_width;
  int32_t paper_r, paper_g, paper_b;
  const qa_compose_tile_item* items;
  const qa_compose_blend* blends;
} g_compose_job;

static void qa_compose_batch_item(int32_t item_index, void* context) {
  (void)context;
  const qa_compose_tile_item* item = &g_compose_job.items[item_index];
  qa_fill_paper_rect(
      g_compose_job.rgb, g_compose_job.raster_width, item->tile_left,
      item->tile_top, item->tile_right_exclusive, item->tile_bottom_exclusive,
      g_compose_job.paper_r, g_compose_job.paper_g, g_compose_job.paper_b);
  for (int32_t i = 0; i < item->blend_count; i += 1) {
    const qa_compose_blend* blend =
        &g_compose_job.blends[item->first_blend + i];
    qa_fill_compose_tile(
        g_compose_job.rgb, g_compose_job.raster_width, blend->tile_pixels,
        blend->tile_size, blend->base_x, blend->base_y, blend->clip_left,
        blend->clip_top, blend->clip_right_exclusive,
        blend->clip_bottom_exclusive, blend->opacity_int);
  }
}

QA_EXPORT void qa_fill_compose_batch(
    uint8_t* rgb,
    int32_t raster_width,
    int32_t paper_r,
    int32_t paper_g,
    int32_t paper_b,
    const qa_compose_tile_item* items,
    int32_t item_count,
    const qa_compose_blend* blends) {
  g_compose_job.rgb = rgb;
  g_compose_job.raster_width = raster_width;
  g_compose_job.paper_r = paper_r;
  g_compose_job.paper_g = paper_g;
  g_compose_job.paper_b = paper_b;
  g_compose_job.items = items;
  g_compose_job.blends = blends;
  qa_pool_run(qa_compose_batch_item, NULL, item_count);
}

// ---------------------------------------------------------------------------
// Close-gap fill (R20-C1) - mirrors the Dart reference pipeline in
// canvas_flood_fill.dart EXACTLY (integer chamfer math; parity-pinned):
// tolerance mask, 3-4 chamfer distance transform, erode by 3*gap, flood,
// grow back by 3*gap clipped to fillable.

static void qa_chamfer_distance(
    uint16_t* dist,
    const uint8_t* from,
    uint8_t zero_when,
    int32_t width,
    int32_t height) {
  const int32_t infinity = 60000;
  const int64_t count = (int64_t)width * height;
  for (int64_t i = 0; i < count; i += 1) {
    dist[i] = from[i] == zero_when ? 0 : (uint16_t)infinity;
  }
  for (int32_t y = 0; y < height; y += 1) {
    const int64_t row = (int64_t)y * width;
    for (int32_t x = 0; x < width; x += 1) {
      const int64_t index = row + x;
      int32_t best = dist[index];
      if (best == 0) {
        continue;
      }
      if (x > 0 && dist[index - 1] + 3 < best) best = dist[index - 1] + 3;
      if (y > 0) {
        const int64_t up = index - width;
        if (dist[up] + 3 < best) best = dist[up] + 3;
        if (x > 0 && dist[up - 1] + 4 < best) best = dist[up - 1] + 4;
        if (x < width - 1 && dist[up + 1] + 4 < best) best = dist[up + 1] + 4;
      }
      dist[index] = (uint16_t)(best > infinity ? infinity : best);
    }
  }
  for (int32_t y = height - 1; y >= 0; y -= 1) {
    const int64_t row = (int64_t)y * width;
    for (int32_t x = width - 1; x >= 0; x -= 1) {
      const int64_t index = row + x;
      int32_t best = dist[index];
      if (best == 0) {
        continue;
      }
      if (x < width - 1 && dist[index + 1] + 3 < best) {
        best = dist[index + 1] + 3;
      }
      if (y < height - 1) {
        const int64_t down = index + width;
        if (dist[down] + 3 < best) best = dist[down] + 3;
        if (x < width - 1 && dist[down + 1] + 4 < best) {
          best = dist[down + 1] + 4;
        }
        if (x > 0 && dist[down - 1] + 4 < best) best = dist[down - 1] + 4;
      }
      dist[index] = (uint16_t)(best > infinity ? infinity : best);
    }
  }
}

// Returns the EFFECTIVE gap used (>= 0; seed-survival may have halved
// it), -1 on stack overflow (caller falls back to the Dart reference),
// -2 when nothing fills. bounds_out = {minX, maxX, minY, maxY}.
QA_EXPORT int32_t qa_fill_gap_close_run(
    const uint8_t* rgb,
    int32_t width,
    int32_t height,
    int32_t seed_x,
    int32_t seed_y,
    int32_t seed_r,
    int32_t seed_g,
    int32_t seed_b,
    int32_t tolerance,
    int32_t gap_px,
    uint8_t* fillable,
    uint16_t* dist,
    uint8_t* filled,
    int32_t* stack,
    int32_t stack_capacity,
    int32_t* bounds_out) {
  const int64_t count = (int64_t)width * height;
  int64_t i = 0;
#ifdef QA_FLOOD_SIMD
  // Full-canvas tolerance mask, 4 px per step (RGBX) - at 8K this pass
  // alone walks 132MB.
  const qa_vec4 seed4 = qa_vec4_splat(
      (uint32_t)seed_r | ((uint32_t)seed_g << 8) |
      ((uint32_t)seed_b << 16));
  const qa_vec4 tol4 = qa_vec4_splat(
      (uint32_t)tolerance | ((uint32_t)tolerance << 8) |
      ((uint32_t)tolerance << 16));
  for (; i + 4 <= count; i += 4) {
    const int32_t ok = qa_tol_ok4(rgb + (i << 2), seed4, tol4);
    fillable[i] = (uint8_t)(ok & 1);
    fillable[i + 1] = (uint8_t)((ok >> 1) & 1);
    fillable[i + 2] = (uint8_t)((ok >> 2) & 1);
    fillable[i + 3] = (uint8_t)((ok >> 3) & 1);
  }
#endif
  for (; i < count; i += 1) {
    fillable[i] = qa_tol_ok1(
                      rgb + (i << 2), seed_r, seed_g, seed_b, tolerance)
                      ? 1
                      : 0;
  }
  qa_chamfer_distance(dist, fillable, 0, width, height);

  int32_t gap = gap_px;
  const int64_t seed_index = (int64_t)seed_y * width + seed_x;
  while (gap > 0 && dist[seed_index] <= 3 * gap) {
    gap /= 2;
  }
  const int32_t threshold = 3 * gap;

  memset(filled, 0, (size_t)count);
  if (dist[seed_index] <= threshold) {
    return -2;
  }
  int32_t stack_size = 0;
  filled[seed_index] = 255;
  stack[stack_size++] = (int32_t)seed_index;
  while (stack_size > 0) {
    const int32_t index = stack[--stack_size];
    const int32_t y = index / width;
    const int32_t row = y * width;
    int32_t left = index - row;
    while (left > 0 && filled[row + left - 1] == 0 &&
           dist[row + left - 1] > threshold) {
      left -= 1;
      filled[row + left] = 255;
    }
    int32_t right = index - row;
    while (right < width - 1 && filled[row + right + 1] == 0 &&
           dist[row + right + 1] > threshold) {
      right += 1;
      filled[row + right] = 255;
    }
    for (int32_t dy = -1; dy <= 1; dy += 2) {
      const int32_t neighbor_y = y + dy;
      if (neighbor_y < 0 || neighbor_y >= height) {
        continue;
      }
      const int32_t neighbor_row = neighbor_y * width;
      int32_t run_open = 0;
      for (int32_t x = left; x <= right; x += 1) {
        const int32_t neighbor = neighbor_row + x;
        if (filled[neighbor] == 0 && dist[neighbor] > threshold) {
          if (!run_open) {
            if (stack_size >= stack_capacity) {
              return -1;
            }
            filled[neighbor] = 255;
            stack[stack_size++] = neighbor;
            run_open = 1;
          }
        } else {
          run_open = 0;
        }
      }
    }
  }

  // Grow back to the real barriers (dist reused for the second
  // transform, sourced from the flooded set this time).
  qa_chamfer_distance(dist, filled, 255, width, height);
  int32_t min_x = width, max_x = -1, min_y = height, max_y = -1;
  for (int32_t y = 0; y < height; y += 1) {
    const int32_t row = y * width;
    for (int32_t x = 0; x < width; x += 1) {
      const int32_t i = row + x;
      if (fillable[i] != 0 && dist[i] <= threshold) {
        filled[i] = 255;
        if (x < min_x) min_x = x;
        if (x > max_x) max_x = x;
        if (y < min_y) min_y = y;
        if (y > max_y) max_y = y;
      } else {
        filled[i] = 0;
      }
    }
  }
  if (max_x < 0) {
    return -2;
  }
  bounds_out[0] = min_x;
  bounds_out[1] = max_x;
  bounds_out[2] = min_y;
  bounds_out[3] = max_y;
  return gap;
}

// ---------------------------------------------------------------------------
// Stamp blend, whole tile span (R18 F-1): the Dart driver used to make
// one FFI call PER ROW - a full-canvas fill stamp was ~10k calls whose
// call overhead dwarfed the blend (commit.edit 55-95ms warm). One call
// per (dab, tile) loops the rows here, through the SAME row kernel, so
// the math (and its parity pins) are untouched.
QA_EXPORT int32_t qa_stamp_blend_tile(
    uint8_t* tile_pixels,
    int32_t tile_size,
    int32_t tile_left,
    int32_t tile_top,
    const uint8_t* stamp,
    int32_t stamp_width,
    int32_t stamp_left,
    int32_t stamp_top,
    int32_t span_left,
    int32_t span_right_exclusive,
    int32_t span_top,
    int32_t span_bottom_exclusive,
    double opacity,
    int32_t erase) {
  int32_t changed = 0;
  const int32_t count = span_right_exclusive - span_left;
  for (int32_t y = span_top; y < span_bottom_exclusive; y += 1) {
    uint8_t* tile_row =
        tile_pixels +
        ((ptrdiff_t)(y - tile_top) * tile_size + (span_left - tile_left)) * 4;
    const uint8_t* stamp_row =
        stamp +
        ((ptrdiff_t)(y - stamp_top) * stamp_width + (span_left - stamp_left)) *
            4;
    if (qa_stamp_blend_row(tile_row, stamp_row, count, opacity, erase)) {
      changed = 1;
    }
  }
  return changed;
}

// ---------------------------------------------------------------------------
// Worker pool (R18 A-3a): tile batches fan out across a small persistent
// thread pool. Tiles are DISJOINT memory, each tile's pixel loop runs
// sequentially inside exactly one thread with the exact single-thread
// kernels, so results are byte-identical regardless of worker count -
// the parity suites keep pinning the whole path.
//
// Windows uses event-pair workers; every other platform runs the
// pthread mirror below (R22-E2) - same dynamic atomic distribution,
// same byte-identical contract. QA_ENGINE_THREADS caps the TOTAL
// thread count including the caller (0 or 1 disables the pool).

// One tile's span of a batch job. Field order/types MUST match the Dart
// QaTileSpanStruct exactly; the loader cross-checks qa_tile_span_sizeof.
typedef struct {
  uint8_t* tile_pixels;
  int32_t tile_left;
  int32_t tile_top;
  int32_t span_left;
  int32_t span_right_exclusive;
  int32_t span_top;
  int32_t span_bottom_exclusive;
  int32_t reserved;
} qa_tile_span;

QA_EXPORT int32_t qa_tile_span_sizeof(void) {
  return (int32_t)sizeof(qa_tile_span);
}

// qa_job_fn is declared with the fill-finish machinery above.

// R22-E1: cap raised 8 -> 32 for future many-core CPUs. Default stays
// "logical cores - 1, clamped"; past ~8 workers the tile kernels go
// memory-bandwidth-bound and scale sublinearly - expected, recorded in
// the lab notes, not a regression.
#define QA_MAX_WORKERS 32

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <process.h>
#include <stdlib.h>

static struct {
  int initialized;
  int worker_count;
  HANDLE threads[QA_MAX_WORKERS];
  HANDLE work_ready[QA_MAX_WORKERS];
  HANDLE work_done[QA_MAX_WORKERS];
  qa_job_fn job_fn;
  void* job_context;
  volatile LONG next_item;
  int32_t item_count;
} g_pool;

static void qa_pool_run_items(void) {
  for (;;) {
    const LONG item = InterlockedIncrement(&g_pool.next_item) - 1;
    if (item >= g_pool.item_count) {
      return;
    }
    g_pool.job_fn((int32_t)item, g_pool.job_context);
  }
}

static unsigned __stdcall qa_pool_worker(void* arg) {
  const int index = (int)(intptr_t)arg;
  for (;;) {
    WaitForSingleObject(g_pool.work_ready[index], INFINITE);
    qa_pool_run_items();
    SetEvent(g_pool.work_done[index]);
  }
}

static void qa_pool_init_once(void) {
  if (g_pool.initialized) {
    return;
  }
  g_pool.initialized = 1;
  SYSTEM_INFO info;
  GetSystemInfo(&info);
  int workers = (int)info.dwNumberOfProcessors - 1;
  const char* override_text = getenv("QA_ENGINE_THREADS");
  if (override_text != NULL) {
    const int override_value = atoi(override_text);
    // The override is TOTAL threads including the caller.
    workers = override_value - 1;
  }
  if (workers > QA_MAX_WORKERS) workers = QA_MAX_WORKERS;
  if (workers < 0) workers = 0;
  g_pool.worker_count = 0;
  for (int i = 0; i < workers; i += 1) {
    g_pool.work_ready[i] = CreateEventW(NULL, FALSE, FALSE, NULL);
    g_pool.work_done[i] = CreateEventW(NULL, FALSE, FALSE, NULL);
    if (g_pool.work_ready[i] == NULL || g_pool.work_done[i] == NULL) {
      break;
    }
    const uintptr_t handle = _beginthreadex(
        NULL, 0, qa_pool_worker, (void*)(intptr_t)i, 0, NULL);
    if (handle == 0) {
      break;
    }
    g_pool.threads[i] = (HANDLE)handle;
    g_pool.worker_count += 1;
  }
}

// Runs job_fn(0..item_count-1, context) across the pool + the caller;
// returns only when every item completed.
static void qa_pool_run(qa_job_fn job_fn, void* context, int32_t item_count) {
  if (item_count <= 0) {
    return;
  }
  qa_pool_init_once();
  if (g_pool.worker_count == 0 || item_count == 1) {
    for (int32_t i = 0; i < item_count; i += 1) {
      job_fn(i, context);
    }
    return;
  }
  g_pool.job_fn = job_fn;
  g_pool.job_context = context;
  g_pool.item_count = item_count;
  g_pool.next_item = 0;
  int engaged = g_pool.worker_count;
  if (engaged > item_count - 1) {
    engaged = (int)item_count - 1;
  }
  for (int i = 0; i < engaged; i += 1) {
    SetEvent(g_pool.work_ready[i]);
  }
  qa_pool_run_items();
  for (int i = 0; i < engaged; i += 1) {
    WaitForSingleObject(g_pool.work_done[i], INFINITE);
  }
}

#else  // !_WIN32: pthread mirror of the Windows pool (R22-E2).
// Structure-identical: persistent workers, dynamic atomic item counter
// (P/E-hybrid friendly), caller participates, byte-identical results by
// construction. Auto-reset event pairs become a token count + two
// condition variables (macOS has no unnamed semaphores, so mutex+cond
// is the portable pair). This lock is DISTINCT from the tile-pool lock
// (qa_tile_free on the GC thread) - no ordering between them.

#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>

static struct {
  int initialized;
  int worker_count;
  pthread_t threads[QA_MAX_WORKERS];
  pthread_mutex_t lock;
  pthread_cond_t ready_cond;
  pthread_cond_t done_cond;
  int ready_tokens;
  int done_count;
  qa_job_fn job_fn;
  void* job_context;
  volatile int32_t next_item;
  int32_t item_count;
} g_pool;

static void qa_pool_run_items(void) {
  for (;;) {
    const int32_t item =
        __atomic_fetch_add(&g_pool.next_item, 1, __ATOMIC_RELAXED);
    if (item >= g_pool.item_count) {
      return;
    }
    g_pool.job_fn(item, g_pool.job_context);
  }
}

static void* qa_pool_worker(void* arg) {
  (void)arg;
  for (;;) {
    pthread_mutex_lock(&g_pool.lock);
    while (g_pool.ready_tokens == 0) {
      pthread_cond_wait(&g_pool.ready_cond, &g_pool.lock);
    }
    g_pool.ready_tokens -= 1;
    pthread_mutex_unlock(&g_pool.lock);
    qa_pool_run_items();
    pthread_mutex_lock(&g_pool.lock);
    g_pool.done_count += 1;
    pthread_cond_signal(&g_pool.done_cond);
    pthread_mutex_unlock(&g_pool.lock);
  }
  return NULL;
}

static void qa_pool_init_once(void) {
  if (g_pool.initialized) {
    return;
  }
  g_pool.initialized = 1;
  pthread_mutex_init(&g_pool.lock, NULL);
  pthread_cond_init(&g_pool.ready_cond, NULL);
  pthread_cond_init(&g_pool.done_cond, NULL);
  int workers = (int)sysconf(_SC_NPROCESSORS_ONLN) - 1;
  const char* override_text = getenv("QA_ENGINE_THREADS");
  if (override_text != NULL) {
    const int override_value = atoi(override_text);
    // The override is TOTAL threads including the caller.
    workers = override_value - 1;
  }
  if (workers > QA_MAX_WORKERS) workers = QA_MAX_WORKERS;
  if (workers < 0) workers = 0;
  g_pool.worker_count = 0;
  for (int i = 0; i < workers; i += 1) {
    if (pthread_create(&g_pool.threads[i], NULL, qa_pool_worker, NULL) != 0) {
      break;
    }
    g_pool.worker_count += 1;
  }
}

// Runs job_fn(0..item_count-1, context) across the pool + the caller;
// returns only when every item completed.
static void qa_pool_run(qa_job_fn job_fn, void* context, int32_t item_count) {
  if (item_count <= 0) {
    return;
  }
  qa_pool_init_once();
  if (g_pool.worker_count == 0 || item_count == 1) {
    for (int32_t i = 0; i < item_count; i += 1) {
      job_fn(i, context);
    }
    return;
  }
  g_pool.job_fn = job_fn;
  g_pool.job_context = context;
  g_pool.item_count = item_count;
  g_pool.next_item = 0;
  int engaged = g_pool.worker_count;
  if (engaged > item_count - 1) {
    engaged = (int)item_count - 1;
  }
  pthread_mutex_lock(&g_pool.lock);
  g_pool.done_count = 0;
  g_pool.ready_tokens = engaged;
  pthread_cond_broadcast(&g_pool.ready_cond);
  pthread_mutex_unlock(&g_pool.lock);
  qa_pool_run_items();
  pthread_mutex_lock(&g_pool.lock);
  while (g_pool.done_count < engaged) {
    pthread_cond_wait(&g_pool.done_cond, &g_pool.lock);
  }
  pthread_mutex_unlock(&g_pool.lock);
}

#endif

// --- Batched generic dab blend -------------------------------------------

typedef struct {
  qa_tile_span* tiles;
  int32_t tile_size;
  const qa_dab_spec* spec;
  uint8_t* changed_out;
} qa_dab_batch_context;

static void qa_dab_batch_item(int32_t item_index, void* context) {
  const qa_dab_batch_context* batch = (const qa_dab_batch_context*)context;
  const qa_tile_span* span = &batch->tiles[item_index];
  batch->changed_out[item_index] = (uint8_t)qa_dab_blend_tile(
      span->tile_pixels, batch->tile_size, span->tile_left, span->tile_top,
      span->span_left, span->span_right_exclusive, span->span_top,
      span->span_bottom_exclusive, batch->spec);
}

// Blends one dab into MANY tiles in one call, fanned across the pool.
QA_EXPORT void qa_dab_blend_tiles(
    qa_tile_span* tiles,
    int32_t tile_count,
    int32_t tile_size,
    const qa_dab_spec* spec,
    uint8_t* changed_out) {
  qa_dab_batch_context context;
  context.tiles = tiles;
  context.tile_size = tile_size;
  context.spec = spec;
  context.changed_out = changed_out;
  qa_pool_run(qa_dab_batch_item, &context, tile_count);
}

// --- Batched stamp blend ---------------------------------------------------

typedef struct {
  qa_tile_span* tiles;
  int32_t tile_size;
  const uint8_t* stamp;
  int32_t stamp_width;
  int32_t stamp_left;
  int32_t stamp_top;
  double opacity;
  int32_t erase;
  uint8_t* changed_out;
} qa_stamp_batch_context;

static void qa_stamp_batch_item(int32_t item_index, void* context) {
  const qa_stamp_batch_context* batch = (const qa_stamp_batch_context*)context;
  const qa_tile_span* span = &batch->tiles[item_index];
  batch->changed_out[item_index] = (uint8_t)qa_stamp_blend_tile(
      span->tile_pixels, batch->tile_size, span->tile_left, span->tile_top,
      batch->stamp, batch->stamp_width, batch->stamp_left, batch->stamp_top,
      span->span_left, span->span_right_exclusive, span->span_top,
      span->span_bottom_exclusive, batch->opacity, batch->erase);
}

// Blends one stamp dab into MANY tiles in one call, fanned across the pool.
QA_EXPORT void qa_stamp_blend_tiles(
    qa_tile_span* tiles,
    int32_t tile_count,
    int32_t tile_size,
    const uint8_t* stamp,
    int32_t stamp_width,
    int32_t stamp_left,
    int32_t stamp_top,
    double opacity,
    int32_t erase,
    uint8_t* changed_out) {
  qa_stamp_batch_context context;
  context.tiles = tiles;
  context.tile_size = tile_size;
  context.stamp = stamp;
  context.stamp_width = stamp_width;
  context.stamp_left = stamp_left;
  context.stamp_top = stamp_top;
  context.opacity = opacity;
  context.erase = erase;
  context.changed_out = changed_out;
  qa_pool_run(qa_stamp_batch_item, &context, tile_count);
}

// ---------------------------------------------------------------------------
// Parallel flood fill (R22-E3): wave-parallel connected growth.
//
// The sequential stepper (qa_flood_fill_step) grows the region pixel by
// pixel; at 64MP it is the app's dominant fill term. This engine keeps
// the SAME lazy-compose protocol with the Dart driver (uncomposed
// pixels come back as candidates) but grows the region one compose-tile
// WAVE at a time: every tile with pending seeds floods LOCALLY (scan-
// line + the SSE2 tolerance spans, no composed checks inside a tile) in
// parallel across the worker pool; tiles write only their own filled
// pixels and their own outgoing edge-crossing buffers, so there is no
// shared-write anywhere in the parallel phase. A serial routing phase
// moves crossings into neighbor pending lists (composed) or the
// caller's candidate buffer (uncomposed), then the next wave runs.
//
// Determinism: the final filled set is "the seed's connected component
// of within-tolerance pixels" - a SET, independent of tile visit order
// and worker count, so the mask and bounds are byte-identical to the
// sequential reference (the randomized parity suite pins this against
// the permanent Dart oracle).
//
// Buffer bounds (why nothing can overflow): a pixel fills exactly once
// per fill, and only edge pixels emit crossings - so a tile's outgoing
// buffer per edge is capped by the edge length, and a tile's pending
// intake is capped by its own perimeter (from neighbors and from the
// driver's candidate re-seeds, which are exactly edge crossings) plus
// the original seed. Local stacks are capped by the per-tile run count
// (checkerboard worst case = tile_size^2/2). Every cap is enforced with
// an error flag anyway; any failure returns -1 and the caller redoes
// the fill on the sequential path from clean state.

#if defined(_MSC_VER)
#define QA_THREAD_LOCAL __declspec(thread)
#else
#define QA_THREAD_LOCAL __thread
#endif

enum { QA_WAVE_LEFT = 0, QA_WAVE_RIGHT = 1, QA_WAVE_UP = 2, QA_WAVE_DOWN = 3 };

typedef struct {
  int32_t px0, py0, px1, py1; // Inclusive pixel bounds of the tile.
  int32_t min_x, max_x, min_y, max_y; // Filled bounds inside this tile.
  int32_t pending_count;
  int32_t pending_taken;
  int32_t out_count[4];
  int32_t out_routed[4];
  uint8_t in_wave;
  uint8_t queued; // On the new-pending list for the next wave scan.
  uint8_t error;
} qa_wave_tile;

static struct {
  int32_t tile_capacity; // Allocated tile slots.
  int32_t pending_capacity_per_tile;
  int32_t out_capacity_per_edge;
  qa_wave_tile* tiles;
  int32_t* pending;   // tile_capacity * pending_capacity_per_tile
  int32_t* outgoing;  // tile_capacity * 4 * out_capacity_per_edge
  int32_t* wave_list; // tile ids in the current wave
  int32_t* queue_list; // tile ids with new pending (next wave scan)
} g_wave;

// Shared per-call view for the parallel job (read-only except the
// per-tile-owned fields documented above).
static struct {
  const uint8_t* rgb;
  uint8_t* filled;
  int32_t width;
  int32_t height;
  int32_t seed_r, seed_g, seed_b, tolerance;
} g_wave_job;

// Worker-local scanline stack, lazily allocated per thread and kept.
#define QA_WAVE_LOCAL_STACK (1 << 17)
static QA_THREAD_LOCAL int32_t* g_wave_local_stack;

static int qa_wave_arena_ensure(int32_t tile_count, int32_t tile_size) {
  // Intake per tile per call: driver re-seeds (<= perimeter) + their
  // routed cross-tile crossings + neighbor wave crossings (<= 4 edges).
  const int32_t pending_cap = 16 * tile_size + 64;
  const int32_t out_cap = tile_size;
  if (g_wave.tile_capacity >= tile_count &&
      g_wave.pending_capacity_per_tile >= pending_cap &&
      g_wave.out_capacity_per_edge >= out_cap) {
    return 1;
  }
  free(g_wave.tiles);
  free(g_wave.pending);
  free(g_wave.outgoing);
  free(g_wave.wave_list);
  free(g_wave.queue_list);
  g_wave.tiles = (qa_wave_tile*)malloc(sizeof(qa_wave_tile) * tile_count);
  g_wave.pending =
      (int32_t*)malloc(sizeof(int32_t) * (size_t)tile_count * pending_cap);
  g_wave.outgoing =
      (int32_t*)malloc(sizeof(int32_t) * (size_t)tile_count * 4 * out_cap);
  g_wave.wave_list = (int32_t*)malloc(sizeof(int32_t) * tile_count);
  g_wave.queue_list = (int32_t*)malloc(sizeof(int32_t) * tile_count);
  if (g_wave.tiles == NULL || g_wave.pending == NULL ||
      g_wave.outgoing == NULL || g_wave.wave_list == NULL ||
      g_wave.queue_list == NULL) {
    free(g_wave.tiles);
    free(g_wave.pending);
    free(g_wave.outgoing);
    free(g_wave.wave_list);
    free(g_wave.queue_list);
    memset(&g_wave, 0, sizeof(g_wave));
    return 0;
  }
  g_wave.tile_capacity = tile_count;
  g_wave.pending_capacity_per_tile = pending_cap;
  g_wave.out_capacity_per_edge = out_cap;
  return 1;
}

static inline int32_t* qa_wave_pending_of(int32_t tile) {
  return g_wave.pending + (size_t)tile * g_wave.pending_capacity_per_tile;
}

static inline int32_t* qa_wave_out_of(int32_t tile, int edge) {
  return g_wave.outgoing +
         ((size_t)tile * 4 + edge) * g_wave.out_capacity_per_edge;
}

// Emits the crossing NEIGHBOR pixel for a filled edge pixel. Called
// only from the tile that owns (x, y) - single-writer per buffer.
static inline void qa_wave_emit(
    qa_wave_tile* t, int32_t tile_id, int edge, int32_t neighbor_index) {
  if (t->out_count[edge] >= g_wave.out_capacity_per_edge) {
    t->error = 1; // Unreachable by the perimeter bound; belt only.
    return;
  }
  qa_wave_out_of(tile_id, edge)[t->out_count[edge]] = neighbor_index;
  t->out_count[edge] += 1;
}

// Fills one pixel of the tile, with edge-crossing emission. Vector
// fast paths may bypass this ONLY for pixels strictly inside the tile
// (no crossings possible); bounds are tracked at run granularity by
// the caller.
static inline void qa_wave_fill_px(
    qa_wave_tile* t, int32_t tile_id, int32_t x, int32_t y) {
  const int32_t width = g_wave_job.width;
  g_wave_job.filled[(size_t)y * width + x] = 255;
  if (x == t->px0 && x > 0) {
    qa_wave_emit(t, tile_id, QA_WAVE_LEFT, y * width + x - 1);
  }
  if (x == t->px1 && x < width - 1) {
    qa_wave_emit(t, tile_id, QA_WAVE_RIGHT, y * width + x + 1);
  }
  if (y == t->py0 && y > 0) {
    qa_wave_emit(t, tile_id, QA_WAVE_UP, (y - 1) * width + x);
  }
  if (y == t->py1 && y < g_wave_job.height - 1) {
    qa_wave_emit(t, tile_id, QA_WAVE_DOWN, (y + 1) * width + x);
  }
}

// Pool job adapter: item index -> current wave's tile id.
static void qa_wave_flood_wave_item(int32_t item_index, void* context);

// Local scanline flood of ONE tile: consumes the tile's fresh pending
// seeds, never reads outside [px0..px1]x[py0..py1]. Runs inside one
// pool worker; everything it writes is tile-owned.
static void qa_wave_flood_tile(int32_t tile_id, void* context) {
  (void)context;
  qa_wave_tile* t = &g_wave.tiles[tile_id];
  const uint8_t* rgb = g_wave_job.rgb;
  uint8_t* filled = g_wave_job.filled;
  const int32_t width = g_wave_job.width;
  const int32_t seed_r = g_wave_job.seed_r;
  const int32_t seed_g = g_wave_job.seed_g;
  const int32_t seed_b = g_wave_job.seed_b;
  const int32_t tolerance = g_wave_job.tolerance;
#ifdef QA_FLOOD_SIMD
  const qa_vec4 seed4 = qa_vec4_splat(
      (uint32_t)seed_r | ((uint32_t)seed_g << 8) |
      ((uint32_t)seed_b << 16));
  const qa_vec4 tol4 = qa_vec4_splat(
      (uint32_t)tolerance | ((uint32_t)tolerance << 8) |
      ((uint32_t)tolerance << 16));
#endif

  if (g_wave_local_stack == NULL) {
    g_wave_local_stack =
        (int32_t*)malloc(sizeof(int32_t) * QA_WAVE_LOCAL_STACK);
    if (g_wave_local_stack == NULL) {
      t->error = 1;
      return;
    }
  }
  int32_t* stack = g_wave_local_stack;
  int32_t stack_size = 0;

  const int32_t* pending = qa_wave_pending_of(tile_id);
  const int32_t pending_end = t->pending_count;
  for (int32_t i = t->pending_taken; i < pending_end; i += 1) {
    const int32_t p = pending[i];
    if (filled[p] == 0) {
      if (!qa_tol_ok1(
              rgb + ((ptrdiff_t)p << 2), seed_r, seed_g, seed_b, tolerance)) {
        continue;
      }
      const int32_t x = p % width;
      const int32_t y = p / width;
      qa_wave_fill_px(t, tile_id, x, y);
      if (x < t->min_x) t->min_x = x;
      if (x > t->max_x) t->max_x = x;
      if (y < t->min_y) t->min_y = y;
      if (y > t->max_y) t->max_y = y;
    }
    if (stack_size >= QA_WAVE_LOCAL_STACK) {
      t->error = 1;
      return;
    }
    stack[stack_size] = p;
    stack_size += 1;
  }
  t->pending_taken = pending_end;

  while (stack_size > 0) {
    stack_size -= 1;
    const int32_t index = stack[stack_size];
    const int32_t y = index / width;
    const int32_t row_start = y * width;

    // Expand the run left/right WITHIN the tile (SSE2 on the interior;
    // scalar owns edge pixels so crossings always emit).
    int32_t left = index - row_start;
    {
      int32_t x = left - 1;
#ifdef QA_FLOOD_SIMD
      if (y > t->py0 && y < t->py1) {
        while (x - 3 > t->px0) {
          uint32_t f4;
          memcpy(&f4, filled + row_start + x - 3, 4);
          if (f4 != 0) {
            break;
          }
          if (qa_tol_ok4(
                  rgb + ((ptrdiff_t)(row_start + x - 3) << 2), seed4, tol4) !=
              0xF) {
            break;
          }
          memset(filled + row_start + x - 3, 255, 4);
          x -= 4;
        }
      }
#endif
      while (x >= t->px0) {
        const int32_t p = row_start + x;
        if (filled[p] != 0 ||
            !qa_tol_ok1(
                rgb + ((ptrdiff_t)p << 2), seed_r, seed_g, seed_b,
                tolerance)) {
          break;
        }
        qa_wave_fill_px(t, tile_id, x, y);
        x -= 1;
      }
      left = x + 1;
    }
    int32_t right = index - row_start;
    {
      int32_t x = right + 1;
#ifdef QA_FLOOD_SIMD
      if (y > t->py0 && y < t->py1) {
        while (x + 3 < t->px1) {
          uint32_t f4;
          memcpy(&f4, filled + row_start + x, 4);
          if (f4 != 0) {
            break;
          }
          if (qa_tol_ok4(
                  rgb + ((ptrdiff_t)(row_start + x) << 2), seed4, tol4) !=
              0xF) {
            break;
          }
          memset(filled + row_start + x, 255, 4);
          x += 4;
        }
      }
#endif
      while (x <= t->px1) {
        const int32_t p = row_start + x;
        if (filled[p] != 0 ||
            !qa_tol_ok1(
                rgb + ((ptrdiff_t)p << 2), seed_r, seed_g, seed_b,
                tolerance)) {
          break;
        }
        qa_wave_fill_px(t, tile_id, x, y);
        x += 1;
      }
      right = x - 1;
    }
    if (left < t->min_x) t->min_x = left;
    if (right > t->max_x) t->max_x = right;
    if (y < t->min_y) t->min_y = y;
    if (y > t->max_y) t->max_y = y;

    // Seed the rows above/below WITHIN the tile (crossings to the rows
    // outside were already emitted when the edge-row pixels filled).
    for (int32_t direction = 0; direction < 2; direction += 1) {
      const int32_t neighbor_y = direction == 0 ? y - 1 : y + 1;
      if (neighbor_y < t->py0 || neighbor_y > t->py1) {
        continue;
      }
      const int32_t neighbor_row = neighbor_y * width;
      int32_t run_open = 0;
      for (int32_t x = left; x <= right; x += 1) {
        const int32_t p = neighbor_row + x;
        if (filled[p] == 0 &&
            qa_tol_ok1(
                rgb + ((ptrdiff_t)p << 2), seed_r, seed_g, seed_b,
                tolerance)) {
          if (!run_open) {
            qa_wave_fill_px(t, tile_id, x, neighbor_y);
            if (stack_size >= QA_WAVE_LOCAL_STACK) {
              t->error = 1;
              return;
            }
            stack[stack_size] = p;
            stack_size += 1;
            run_open = 1;
          }
        } else {
          run_open = 0;
        }
      }
    }
  }
}

static void qa_wave_flood_wave_item(int32_t item_index, void* context) {
  (void)context;
  qa_wave_flood_tile(g_wave.wave_list[item_index], NULL);
}

// One full lazy-protocol round: floods EVERYTHING reachable through
// currently-composed tiles (wave-parallel), returns crossings into
// uncomposed tiles as candidates (same contract as the sequential
// stepper: the driver composes them, re-seeds the matches, re-enters).
// stack in: the driver's seeds; out: always fully consumed (0).
// Returns the candidate count, or -1 on any allocation/bound failure -
// the caller redoes the fill on the sequential path from clean state.
QA_EXPORT int32_t qa_flood_fill_wave(
    const uint8_t* rgb,
    uint8_t* filled,
    const uint8_t* composed,
    int32_t width,
    int32_t height,
    int32_t compose_tile_shift,
    int32_t tiles_x,
    int32_t seed_r,
    int32_t seed_g,
    int32_t seed_b,
    int32_t tolerance,
    int32_t* stack,
    int32_t* stack_size,
    int32_t* candidates,
    int32_t candidates_capacity,
    int32_t* bounds) {
  const int32_t tile_size = 1 << compose_tile_shift;
  const int32_t tiles_y = (height + tile_size - 1) >> compose_tile_shift;
  const int32_t tile_count = tiles_x * tiles_y;
  if (!qa_wave_arena_ensure(tile_count, tile_size)) {
    return -1;
  }

  // Per-call reset of tile bookkeeping (geometry + counters).
  for (int32_t ty = 0; ty < tiles_y; ty += 1) {
    for (int32_t tx = 0; tx < tiles_x; tx += 1) {
      qa_wave_tile* t = &g_wave.tiles[ty * tiles_x + tx];
      t->px0 = tx << compose_tile_shift;
      t->py0 = ty << compose_tile_shift;
      t->px1 = t->px0 + tile_size - 1;
      if (t->px1 > width - 1) t->px1 = width - 1;
      t->py1 = t->py0 + tile_size - 1;
      if (t->py1 > height - 1) t->py1 = height - 1;
      t->min_x = width;
      t->max_x = -1;
      t->min_y = height;
      t->max_y = -1;
      t->pending_count = 0;
      t->pending_taken = 0;
      t->out_count[0] = t->out_count[1] = t->out_count[2] = t->out_count[3] =
          0;
      t->out_routed[0] = t->out_routed[1] = t->out_routed[2] =
          t->out_routed[3] = 0;
      t->in_wave = 0;
      t->queued = 0;
      t->error = 0;
    }
  }

  int32_t candidate_count = 0;
  int32_t queue_count = 0;

  // Route one pixel to its tile's pending list (composed) or to the
  // candidate buffer (uncomposed). Serial phases only.
#define QA_WAVE_ROUTE(pixel_index)                                          \
  do {                                                                      \
    const int32_t rp_ = (pixel_index);                                      \
    const int32_t rx_ = rp_ % width;                                        \
    const int32_t ry_ = rp_ / width;                                        \
    const int32_t rt_ = (ry_ >> compose_tile_shift) * tiles_x +             \
                        (rx_ >> compose_tile_shift);                        \
    if (composed[rt_] == 0) {                                               \
      if (candidate_count >= candidates_capacity) {                         \
        return -1;                                                          \
      }                                                                     \
      candidates[candidate_count] = rp_;                                    \
      candidate_count += 1;                                                 \
    } else {                                                                \
      qa_wave_tile* rtile_ = &g_wave.tiles[rt_];                            \
      if (rtile_->pending_count >= g_wave.pending_capacity_per_tile) {      \
        return -1;                                                          \
      }                                                                     \
      qa_wave_pending_of(rt_)[rtile_->pending_count] = rp_;                 \
      rtile_->pending_count += 1;                                           \
      if (!rtile_->queued) {                                                \
        rtile_->queued = 1;                                                 \
        g_wave.queue_list[queue_count] = rt_;                               \
        queue_count += 1;                                                   \
      }                                                                     \
    }                                                                       \
  } while (0)

  // Distribute the driver's seeds. Seeds the DRIVER filled (the
  // original seed and re-seeded candidates) never went through the
  // engine's fill-time crossing emission, so a driver-filled seed
  // sitting on a tile edge routes its cross-tile 4-neighbors here
  // directly (serial phase; in-tile neighbors are covered by the
  // seed's own expansion).
  const int32_t tile_mask = tile_size - 1;
  for (int32_t i = 0; i < *stack_size; i += 1) {
    const int32_t p = stack[i];
    QA_WAVE_ROUTE(p);
    if (filled[p] != 0) {
      const int32_t x = p % width;
      const int32_t y = p / width;
      if ((x & tile_mask) == 0 && x > 0) {
        QA_WAVE_ROUTE(p - 1);
      }
      if ((x & tile_mask) == tile_mask && x < width - 1) {
        QA_WAVE_ROUTE(p + 1);
      }
      if ((y & tile_mask) == 0 && y > 0) {
        QA_WAVE_ROUTE(p - width);
      }
      if ((y & tile_mask) == tile_mask && y < height - 1) {
        QA_WAVE_ROUTE(p + width);
      }
    }
  }
  *stack_size = 0;

  g_wave_job.rgb = rgb;
  g_wave_job.filled = filled;
  g_wave_job.width = width;
  g_wave_job.height = height;
  g_wave_job.seed_r = seed_r;
  g_wave_job.seed_g = seed_g;
  g_wave_job.seed_b = seed_b;
  g_wave_job.tolerance = tolerance;

  while (queue_count > 0) {
    // Wave = every queued tile (all are composed by routing).
    int32_t wave_count = 0;
    for (int32_t i = 0; i < queue_count; i += 1) {
      const int32_t tile_id = g_wave.queue_list[i];
      qa_wave_tile* t = &g_wave.tiles[tile_id];
      t->queued = 0;
      if (t->pending_taken < t->pending_count) {
        g_wave.wave_list[wave_count] = tile_id;
        wave_count += 1;
      }
    }
    queue_count = 0;
    if (wave_count == 0) {
      break;
    }

    // Parallel local floods (tile-owned writes only).
    if (wave_count == 1) {
      qa_wave_flood_tile(g_wave.wave_list[0], NULL);
    } else {
      qa_pool_run(qa_wave_flood_wave_item, NULL, wave_count);
    }

    // Serial routing of the new crossings.
    for (int32_t i = 0; i < wave_count; i += 1) {
      const int32_t tile_id = g_wave.wave_list[i];
      qa_wave_tile* t = &g_wave.tiles[tile_id];
      if (t->error) {
        return -1;
      }
      for (int edge = 0; edge < 4; edge += 1) {
        const int32_t* out = qa_wave_out_of(tile_id, edge);
        for (int32_t j = t->out_routed[edge]; j < t->out_count[edge];
             j += 1) {
          QA_WAVE_ROUTE(out[j]);
        }
        t->out_routed[edge] = t->out_count[edge];
      }
    }
  }
#undef QA_WAVE_ROUTE

  // Merge per-tile bounds.
  int32_t min_x = bounds[0];
  int32_t max_x = bounds[1];
  int32_t min_y = bounds[2];
  int32_t max_y = bounds[3];
  for (int32_t i = 0; i < tile_count; i += 1) {
    const qa_wave_tile* t = &g_wave.tiles[i];
    if (t->max_x < 0) {
      continue;
    }
    if (t->min_x < min_x) min_x = t->min_x;
    if (t->max_x > max_x) max_x = t->max_x;
    if (t->min_y < min_y) min_y = t->min_y;
    if (t->max_y > max_y) max_y = t->max_y;
  }
  bounds[0] = min_x;
  bounds[1] = max_x;
  bounds[2] = min_y;
  bounds[3] = max_y;
  return candidate_count;
}

// --- Tile allocator (R20-E1) -----------------------------------------------
//
// Exact-size free-list recycler for tile pixel buffers. Tiles churn hard:
// every commit ADOPTS its scratch buffers as finished tiles (R19-Z), so
// buffers leave the acquire/release cycle and only come back when the GC
// finalizes old tiles - with plain malloc that meant ~1024 fresh mallocs
// per full-canvas 8K fill. Freed tile blocks now park on per-size free
// lists and are handed straight back to the next allocation.
//
// qa_tile_free doubles as the Dart NativeFinalizer callback, which runs
// on GC threads - all pool state is mutex-guarded.

#include <stdlib.h>

#if defined(_WIN32)
static SRWLOCK g_tile_pool_lock = SRWLOCK_INIT;
#define QA_TILE_LOCK() AcquireSRWLockExclusive(&g_tile_pool_lock)
#define QA_TILE_UNLOCK() ReleaseSRWLockExclusive(&g_tile_pool_lock)
#else
#include <pthread.h>
static pthread_mutex_t g_tile_pool_lock = PTHREAD_MUTEX_INITIALIZER;
#define QA_TILE_LOCK() pthread_mutex_lock(&g_tile_pool_lock)
#define QA_TILE_UNLOCK() pthread_mutex_unlock(&g_tile_pool_lock)
#endif

typedef struct qa_tile_block {
  struct qa_tile_block* next;  // free-list link (meaningful only while free)
  int64_t size;                // user-visible byte length
} qa_tile_block;  // 16-byte header keeps the user data 16-byte aligned

#define QA_TILE_BUCKETS 8
// Total bytes allowed to park across all buckets: one full 8K frame of
// tiles (256MB) plus headroom for a previous frame still draining.
#define QA_TILE_POOL_BYTE_CAP (512ll * 1024 * 1024)

static int64_t g_tile_bucket_sizes[QA_TILE_BUCKETS];
static qa_tile_block* g_tile_bucket_heads[QA_TILE_BUCKETS];
static int64_t g_tile_pool_cached_bytes = 0;

QA_EXPORT void* qa_tile_alloc(int64_t size) {
  if (size <= 0) {
    return NULL;
  }
  QA_TILE_LOCK();
  for (int i = 0; i < QA_TILE_BUCKETS; i += 1) {
    if (g_tile_bucket_sizes[i] == size && g_tile_bucket_heads[i] != NULL) {
      qa_tile_block* block = g_tile_bucket_heads[i];
      g_tile_bucket_heads[i] = block->next;
      g_tile_pool_cached_bytes -= size;
      QA_TILE_UNLOCK();
      return (void*)(block + 1);
    }
  }
  QA_TILE_UNLOCK();
  qa_tile_block* block =
      (qa_tile_block*)malloc(sizeof(qa_tile_block) + (size_t)size);
  if (block == NULL) {
    return NULL;
  }
  block->next = NULL;
  block->size = size;
  return (void*)(block + 1);
}

// Parks the block for reuse, or frees it past the byte cap. The signature
// is exactly Dart's NativeFinalizerFunction: tile finalizers call this
// directly. Only pointers returned by qa_tile_alloc may be passed.
QA_EXPORT void qa_tile_free(void* pixels) {
  if (pixels == NULL) {
    return;
  }
  qa_tile_block* block = ((qa_tile_block*)pixels) - 1;
  const int64_t size = block->size;
  QA_TILE_LOCK();
  if (g_tile_pool_cached_bytes + size <= QA_TILE_POOL_BYTE_CAP) {
    int slot = -1;
    for (int i = 0; i < QA_TILE_BUCKETS; i += 1) {
      if (g_tile_bucket_sizes[i] == size) {
        slot = i;
        break;
      }
    }
    if (slot < 0) {
      // Claim an idle bucket for this size (empty lists can be re-keyed).
      for (int i = 0; i < QA_TILE_BUCKETS; i += 1) {
        if (g_tile_bucket_heads[i] == NULL) {
          g_tile_bucket_sizes[i] = size;
          slot = i;
          break;
        }
      }
    }
    if (slot >= 0) {
      block->next = g_tile_bucket_heads[slot];
      g_tile_bucket_heads[slot] = block;
      g_tile_pool_cached_bytes += size;
      QA_TILE_UNLOCK();
      return;
    }
  }
  QA_TILE_UNLOCK();
  free(block);
}

QA_EXPORT int64_t qa_tile_pool_cached_bytes(void) {
  QA_TILE_LOCK();
  const int64_t bytes = g_tile_pool_cached_bytes;
  QA_TILE_UNLOCK();
  return bytes;
}

// Releases every parked block (diagnostics / tests).
QA_EXPORT void qa_tile_pool_trim(void) {
  QA_TILE_LOCK();
  for (int i = 0; i < QA_TILE_BUCKETS; i += 1) {
    qa_tile_block* block = g_tile_bucket_heads[i];
    while (block != NULL) {
      qa_tile_block* next = block->next;
      free(block);
      block = next;
    }
    g_tile_bucket_heads[i] = NULL;
    g_tile_bucket_sizes[i] = 0;
  }
  g_tile_pool_cached_bytes = 0;
  QA_TILE_UNLOCK();
}

// ---------------------------------------------------------------------------
// Grid tile rasterizer (UI-R18 O7 / R18-T T1): the timeline frame grids
// pre-raster their cell strips into RGBA tiles OFF the UI thread. The op
// stream is a flat int32 word list - deterministic INTEGER rasterization
// (byte-rounded source-over, the fill-compose arithmetic), so the output
// bytes are pinned against the Dart reference implementation by parity
// tests and identical on every platform/worker-count.
//
// Colors pack as memory-order RGBA words: r | g<<8 | b<<16 | a<<24,
// STRAIGHT (non-premultiplied) alpha. The background fill forces a=255,
// so a finished tile is opaque and uploads as-is.
//
// Op stream layout (int32 words, count validated - a truncated op makes
// the call return negative without touching remaining pixels):
//   QA_GRID_OP_FILL_RECT (1): x, y, w, h, rgba            = 6 words
//   QA_GRID_OP_HLINE     (2): x, y, length, thickness, rgba = 6 words
//   QA_GRID_OP_VLINE     (3): x, y, length, thickness, rgba = 6 words
//   QA_GRID_OP_GLYPH     (4): dest_x, dest_y, atlas_x, atlas_y,
//                             w, h, rgba                  = 8 words
// Glyph coverage reads the A8 atlas and scales the color's alpha per
// pixel. Every op clips to the tile (and the glyph also to the atlas);
// fully off-tile ops are no-ops, never errors.

enum {
  QA_GRID_OP_FILL_RECT = 1,
  QA_GRID_OP_HLINE = 2,
  QA_GRID_OP_VLINE = 3,
  QA_GRID_OP_GLYPH = 4,
};

static inline void qa_grid_blend_span(
    uint8_t* dst,
    int32_t count,
    int32_t r,
    int32_t g,
    int32_t b,
    int32_t a) {
  if (a >= 255) {
    for (int32_t i = 0; i < count; i += 1) {
      dst[0] = (uint8_t)r;
      dst[1] = (uint8_t)g;
      dst[2] = (uint8_t)b;
      dst[3] = 255;
      dst += 4;
    }
    return;
  }
  const int32_t inv = 255 - a;
  for (int32_t i = 0; i < count; i += 1) {
    dst[0] = (uint8_t)((r * a + dst[0] * inv + 127) / 255);
    dst[1] = (uint8_t)((g * a + dst[1] * inv + 127) / 255);
    dst[2] = (uint8_t)((b * a + dst[2] * inv + 127) / 255);
    dst[3] = (uint8_t)(255 - ((255 - dst[3]) * inv + 127) / 255);
    dst += 4;
  }
}

static void qa_grid_blend_rect(
    uint8_t* pixels,
    int32_t tile_width,
    int32_t tile_height,
    int32_t x,
    int32_t y,
    int32_t w,
    int32_t h,
    uint32_t rgba) {
  const int32_t a = (int32_t)(rgba >> 24) & 0xFF;
  if (a == 0 || w <= 0 || h <= 0) {
    return;
  }
  int32_t left = x < 0 ? 0 : x;
  int32_t top = y < 0 ? 0 : y;
  int32_t right = x + w;
  int32_t bottom = y + h;
  if (right > tile_width) right = tile_width;
  if (bottom > tile_height) bottom = tile_height;
  if (left >= right || top >= bottom) {
    return;
  }
  const int32_t r = (int32_t)rgba & 0xFF;
  const int32_t g = (int32_t)(rgba >> 8) & 0xFF;
  const int32_t b = (int32_t)(rgba >> 16) & 0xFF;
  for (int32_t row = top; row < bottom; row += 1) {
    qa_grid_blend_span(
        pixels + (((ptrdiff_t)row * tile_width + left) << 2),
        right - left, r, g, b, a);
  }
}

QA_EXPORT int32_t qa_grid_raster_tile(
    uint8_t* pixels,
    int32_t tile_width,
    int32_t tile_height,
    uint32_t background_rgba,
    const int32_t* ops,
    int32_t op_word_count,
    const uint8_t* atlas,
    int32_t atlas_width,
    int32_t atlas_height) {
  if (pixels == NULL || tile_width <= 0 || tile_height <= 0) {
    return -1;
  }
  // Opaque background first: a finished tile never carries translucency.
  {
    const uint32_t bg = background_rgba | 0xFF000000u;
    uint32_t* dst = (uint32_t*)pixels;
    const ptrdiff_t count = (ptrdiff_t)tile_width * tile_height;
    for (ptrdiff_t i = 0; i < count; i += 1) {
      dst[i] = bg;
    }
  }
  if (ops == NULL || op_word_count <= 0) {
    return 0;
  }

  int32_t cursor = 0;
  while (cursor < op_word_count) {
    const int32_t op = ops[cursor];
    switch (op) {
      case QA_GRID_OP_FILL_RECT: {
        if (cursor + 6 > op_word_count) return -2;
        qa_grid_blend_rect(
            pixels, tile_width, tile_height,
            ops[cursor + 1], ops[cursor + 2], ops[cursor + 3],
            ops[cursor + 4], (uint32_t)ops[cursor + 5]);
        cursor += 6;
        break;
      }
      case QA_GRID_OP_HLINE: {
        if (cursor + 6 > op_word_count) return -2;
        qa_grid_blend_rect(
            pixels, tile_width, tile_height,
            ops[cursor + 1], ops[cursor + 2], ops[cursor + 3],
            ops[cursor + 4], (uint32_t)ops[cursor + 5]);
        cursor += 6;
        break;
      }
      case QA_GRID_OP_VLINE: {
        if (cursor + 6 > op_word_count) return -2;
        qa_grid_blend_rect(
            pixels, tile_width, tile_height,
            ops[cursor + 1], ops[cursor + 2], ops[cursor + 4],
            ops[cursor + 3], (uint32_t)ops[cursor + 5]);
        cursor += 6;
        break;
      }
      case QA_GRID_OP_GLYPH: {
        if (cursor + 8 > op_word_count) return -2;
        if (atlas == NULL) return -3;
        const int32_t dest_x = ops[cursor + 1];
        const int32_t dest_y = ops[cursor + 2];
        const int32_t atlas_x = ops[cursor + 3];
        const int32_t atlas_y = ops[cursor + 4];
        const int32_t w = ops[cursor + 5];
        const int32_t h = ops[cursor + 6];
        const uint32_t rgba = (uint32_t)ops[cursor + 7];
        const int32_t color_a = (int32_t)(rgba >> 24) & 0xFF;
        const int32_t r = (int32_t)rgba & 0xFF;
        const int32_t g = (int32_t)(rgba >> 8) & 0xFF;
        const int32_t b = (int32_t)(rgba >> 16) & 0xFF;
        for (int32_t row = 0; row < h; row += 1) {
          const int32_t ty = dest_y + row;
          const int32_t ay = atlas_y + row;
          if (ty < 0 || ty >= tile_height || ay < 0 || ay >= atlas_height) {
            continue;
          }
          for (int32_t col = 0; col < w; col += 1) {
            const int32_t tx = dest_x + col;
            const int32_t ax = atlas_x + col;
            if (tx < 0 || tx >= tile_width || ax < 0 || ax >= atlas_width) {
              continue;
            }
            const int32_t coverage =
                atlas[(ptrdiff_t)ay * atlas_width + ax];
            if (coverage == 0 || color_a == 0) {
              continue;
            }
            const int32_t a = (color_a * coverage + 127) / 255;
            qa_grid_blend_span(
                pixels + (((ptrdiff_t)ty * tile_width + tx) << 2),
                1, r, g, b, a);
          }
        }
        cursor += 8;
        break;
      }
      default:
        return -4;
    }
  }
  return 0;
}

// Engine ABI version - the Dart loader refuses a mismatched binary.
// v12: fill raster RGB -> RGBX (R22-D flood SIMD).
// v13: qa_flood_fill_wave - wave-parallel flood (R22-E3).
// v14: qa_fill_compose_batch - pooled fill compose (R25-3).
// v15: qa_grid_raster_tile - timeline grid tile rasterizer (UI-R18 O7 T1).
QA_EXPORT int32_t qa_engine_abi_version(void) { return 15; }
