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

// ---------------------------------------------------------------------------
// Flood fill, frontier-stepped (R18 A-2b).
//
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
    int32_t left = index - row_start;
    while (left > 0 && filled[row_start + left - 1] == 0) {
      const int32_t px = left - 1;
      const int32_t p = row_start + px;
      if (composed[tile_row + (px >> compose_tile_shift)] == 0) {
        candidates[candidate_count] = p;
        candidate_count += 1;
        break;
      }
      const int32_t base = p * 3;
      const int32_t dr = (int32_t)rgb[base] - seed_r;
      const int32_t dg = (int32_t)rgb[base + 1] - seed_g;
      const int32_t db = (int32_t)rgb[base + 2] - seed_b;
      if (dr > tolerance || -dr > tolerance || dg > tolerance ||
          -dg > tolerance || db > tolerance || -db > tolerance) {
        break;
      }
      left -= 1;
      filled[row_start + left] = 255;
    }
    int32_t right = index - row_start;
    while (right < width - 1 && filled[row_start + right + 1] == 0) {
      const int32_t px = right + 1;
      const int32_t p = row_start + px;
      if (composed[tile_row + (px >> compose_tile_shift)] == 0) {
        candidates[candidate_count] = p;
        candidate_count += 1;
        break;
      }
      const int32_t base = p * 3;
      const int32_t dr = (int32_t)rgb[base] - seed_r;
      const int32_t dg = (int32_t)rgb[base + 1] - seed_g;
      const int32_t db = (int32_t)rgb[base + 2] - seed_b;
      if (dr > tolerance || -dr > tolerance || dg > tolerance ||
          -dg > tolerance || db > tolerance || -db > tolerance) {
        break;
      }
      right += 1;
      filled[row_start + right] = 255;
    }
    if (left < min_x) min_x = left;
    if (right > max_x) max_x = right;
    if (y < min_y) min_y = y;
    if (y > max_y) max_y = y;

    // Seed the rows above and below across the run - ONE seed per
    // contiguous matching run; uncomposed pixels are candidates and
    // close the current run exactly like a non-match.
    for (int32_t direction = 0; direction < 2; direction += 1) {
      const int32_t neighbor_y = direction == 0 ? y - 1 : y + 1;
      if (neighbor_y < 0 || neighbor_y >= height) {
        continue;
      }
      const int32_t neighbor_row = neighbor_y * width;
      const int32_t neighbor_tile_row =
          (neighbor_y >> compose_tile_shift) * tiles_x;
      int32_t run_open = 0;
      for (int32_t x = left; x <= right; x += 1) {
        const int32_t p = neighbor_row + x;
        if (composed[neighbor_tile_row + (x >> compose_tile_shift)] == 0) {
          candidates[candidate_count] = p;
          candidate_count += 1;
          run_open = 0;
          continue;
        }
        if (filled[p] == 0) {
          const int32_t base = p * 3;
          const int32_t dr = (int32_t)rgb[base] - seed_r;
          const int32_t dg = (int32_t)rgb[base + 1] - seed_g;
          const int32_t db = (int32_t)rgb[base + 2] - seed_b;
          if (dr <= tolerance && -dr <= tolerance && dg <= tolerance &&
              -dg <= tolerance && db <= tolerance && -db <= tolerance) {
            if (!run_open) {
              filled[p] = 255;
              stack[*stack_size] = p;
              *stack_size += 1;
              run_open = 1;
            }
            continue;
          }
        }
        run_open = 0;
      }
    }
  }

  bounds[0] = min_x;
  bounds[1] = max_x;
  bounds[2] = min_y;
  bounds[3] = max_y;
  return candidate_count;
}

// Engine ABI version - the Dart loader refuses a mismatched binary.
QA_EXPORT int32_t qa_engine_abi_version(void) { return 4; }
