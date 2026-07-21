import 'dart:math' as math;
import 'dart:typed_data';

import '../core/floor_math.dart';
import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/brush_blend_mode.dart';
import '../models/brush_dab.dart';
import '../models/brush_dab_sequence.dart';
import '../models/brush_stamp_image.dart';
import '../models/brush_tip_shape.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/dirty_region.dart';
import '../models/dirty_tile_set.dart';
import '../models/pasteboard_bounds.dart';
import '../models/tile_coord.dart';
import '../native/qa_native_engine.dart';
import '../ui/dev_profile.dart';
import 'brush_dab_dirty_region.dart';
import 'brush_stroke_blend.dart';
import 'brush_tip_mask_sampling.dart';

class BrushSurfaceMaterialization {
  const BrushSurfaceMaterialization({
    required this.surface,
    required this.dirtyTiles,
  });

  final BitmapSurface surface;
  final DirtyTileSet dirtyTiles;

  bool get hasChanges => dirtyTiles.isNotEmpty;
}

/// Rasterizes [sequence] onto [surface] and returns the updated surface plus
/// the tiles it changed.
///
/// This is the stroke-commit hot path. It blends dabs directly into per-tile
/// scratch byte buffers: each touched tile's pixels are copied at most once,
/// and no per-pixel objects are allocated. The blend math is kept identical to
/// the reference pixel pipeline (`brushPixelBlendOperationsForDabSequence` +
/// `applyBrushPixelBlendOperationsToBitmapTile`), which remains as the slow
/// per-pixel-operation oracle used by the parity test.
BrushSurfaceMaterialization materializeBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
}) {
  // Strokes clip at the PASTEBOARD (canvas + one canvas size in every
  // direction), not the canvas — drawing off the stage is the point.
  // Composite/export raster at canvas size, which crops for free.
  final canvasSize = surface.canvasSize;
  final pasteboardLeft = canvasSize.pasteboardLeft;
  final pasteboardTop = canvasSize.pasteboardTop;
  final pasteboardRight = canvasSize.pasteboardRightExclusive;
  final pasteboardBottom = canvasSize.pasteboardBottomExclusive;
  final tileSize = surface.tileSize;
  final tileByteLength = tileSize * tileSize * BitmapTile.bytesPerPixel;

  // Mutable scratch pixels per touched tile. `BitmapTile.pixels` already
  // returns a defensive copy, so it can be mutated freely; blank tiles start
  // as zeroed buffers without allocating a BitmapTile.
  //
  // With the native engine loaded (R18 A-1 / R19-Z) the scratch lives in
  // pooled NATIVE memory: staging is a C memcpy from the tile's native
  // buffer, Dart works through a typed-data view (the fallback and stamp
  // loops run unchanged) while the kernel gets the raw pointer, and the
  // commit tail ADOPTS the changed buffers as the finished tiles — the
  // whole sequence materializes with zero pixel copies out.
  final native = QaNativeEngine.instance;
  final nativeTiles = native == null ? null : <TileCoord, QaNativeTileBuffer>{};
  final scratchBuffers = <TileCoord, Uint8List>{};
  final changedCoords = <TileCoord>{};

  Uint8List scratchBufferFor(TileCoord coord) {
    return scratchBuffers.putIfAbsent(coord, () {
      final tile = surface.tileAt(coord);
      if (nativeTiles != null) {
        final buffer = native!.acquireTileBuffer(
          tileByteLength,
          zeroed: tile == null,
        );
        nativeTiles[coord] = buffer;
        if (tile != null) {
          native.copyBytes(buffer.pointer, tile.nativePixels, tileByteLength);
        }
        return buffer.view;
      }
      if (tile == null) {
        return Uint8List(tileByteLength);
      }
      return tile.pixels;
    });
  }

  void releaseNativeTiles() {
    if (nativeTiles != null) {
      for (final buffer in nativeTiles.values) {
        native!.releaseTileBuffer(buffer);
      }
      nativeTiles.clear();
    }
  }

  for (final dab in sequence.dabs) {
    // RGBA stamp dabs (R14-④ bitmap lift) take a dedicated 1:1 blend path
    // — the generic tip machinery below stays byte-untouched (its parity
    // pins never see stamps; live == commit still holds by construction
    // because stamps only enter through programmatic commits).
    final stamp = dab.stamp;
    if (stamp != null) {
      _blendStampDab(
        dab: dab,
        stamp: stamp,
        canvasSize: canvasSize,
        tileSize: tileSize,
        scratchBufferFor: scratchBufferFor,
        nativeTileFor: nativeTiles == null
            ? null
            : (coord) {
                scratchBufferFor(coord);
                return nativeTiles[coord]!;
              },
        changedCoords: changedCoords,
      );
      continue;
    }

    final region = dirtyRegionForBrushDab(dab);
    if (region == null) {
      continue;
    }

    final sourceArgb = dab.color;
    final sourceA = (sourceArgb >> 24) & 0xFF;
    if (sourceA == 0 || dab.opacity == 0.0 || dab.flow == 0.0) {
      continue;
    }
    final sourceR = (sourceArgb >> 16) & 0xFF;
    final sourceG = (sourceArgb >> 8) & 0xFF;
    final sourceB = sourceArgb & 0xFF;
    final sourceAlphaNorm = sourceA / 255.0;

    final radius = dab.size / 2.0;
    final hardRadius = radius * dab.hardness;
    final edgeSpan = radius - hardRadius;
    final isRound = dab.tipShape == BrushTipShape.round;
    // Elliptical / rotated tips evaluate coverage in tip space: rotate the
    // pixel offset onto the tip axes and stretch the minor axis by
    // 1/roundness, turning the ellipse test back into the circle test. The
    // classic circle (roundness == 1, rotation-invariant) and axis-aligned
    // square keep their original code path so existing strokes stay
    // byte-identical. Must match BrushLiveStrokeRasterizer exactly.
    final tipMask = dab.tipMask;
    final isEllipse = tipMask == null && isRound && dab.roundness < 1.0;
    final isRotatedRect =
        tipMask == null &&
        !isRound &&
        (dab.roundness < 1.0 || dab.angleDegrees != 0.0);
    var tipCos = 1.0;
    var tipSin = 0.0;
    var inverseRoundness = 1.0;
    if (isEllipse || isRotatedRect || tipMask != null) {
      final angleRadians = dab.angleDegrees * (math.pi / 180.0);
      tipCos = math.cos(angleRadians);
      tipSin = math.sin(angleRadians);
      inverseRoundness = 1.0 / dab.roundness;
    }
    final minorRadius = radius * dab.roundness;
    final centerX = dab.center.x;
    final centerY = dab.center.y;
    final dabOpacity = dab.opacity;
    final dabFlow = dab.flow;

    final top = math.max(region.top, pasteboardTop);
    final bottomExclusive = math.min(region.bottomExclusive, pasteboardBottom);
    final left = math.max(region.left, pasteboardLeft);
    final rightExclusive = math.min(region.rightExclusive, pasteboardRight);
    if (rightExclusive <= left || bottomExclusive <= top) {
      continue;
    }
    final columnCount = rightExclusive - left;
    final rowCount = bottomExclusive - top;

    // Per-dab hoists and axis lattices, mirroring BrushLiveStrokeRasterizer
    // exactly (see brush_tip_mask_sampling.dart): the lattices reproduce
    // the scalar samplers' arithmetic byte-for-byte — the parity suites pin
    // commit == live == reference.
    final dualMask = dab.dualMask;
    final textureMask = dab.textureMask;
    final textureDensity = dab.textureDensity;
    final textureOneMinusDensity = 1.0 - textureDensity;
    final dabErase = dab.erase;
    final unrotatedTip = tipMask != null && dab.angleDegrees == 0.0;
    // Conservative squared-distance cull for plain round tips: only pixels
    // PROVABLY outside the radius skip the sqrt; anything within the float
    // margin still runs the exact scalar test.
    final radiusSqSkip = radius * radius * (1.0 + 1e-12);

    final tipULattice = unrotatedTip
        ? BrushTipMaskAxisLattice.compute(
            mask: tipMask,
            radius: radius,
            start: left,
            count: columnCount,
            center: centerX,
          )
        : null;
    final tipVLattice = unrotatedTip
        ? BrushTipMaskAxisLattice.compute(
            mask: tipMask,
            radius: radius,
            start: top,
            count: rowCount,
            center: centerY,
            inverseRoundness: inverseRoundness,
          )
        : null;
    final dualULattice = dualMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: dualMask,
            start: left,
            count: columnCount,
            originOffset: -centerX,
            period: dab.size * dab.dualMaskScale,
            offset: dab.dualOffsetU,
          );
    final dualVLattice = dualMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: dualMask,
            start: top,
            count: rowCount,
            originOffset: -centerY,
            period: dab.size * dab.dualMaskScale,
            offset: dab.dualOffsetV,
          );
    final textureULattice = textureMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: textureMask,
            start: left,
            count: columnCount,
            originOffset: 0.0,
            period: textureMask.size * dab.textureScale,
            offset: 0.0,
          );
    final textureVLattice = textureMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: textureMask,
            start: top,
            count: rowCount,
            originOffset: 0.0,
            period: textureMask.size * dab.textureScale,
            offset: 0.0,
          );

    final tileXStart = floorDiv(left, tileSize);
    final tileXEnd = floorDiv(rightExclusive - 1, tileSize);

    // Native kernel (R18 A-1): identical pixel visits and float math, one
    // call per (dab, tile) straight into the native-backed scratch. The
    // Dart loop below stays byte-for-byte as the reference fallback.
    if (native != null) {
      native.prepareDab(
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        hardRadius: hardRadius,
        edgeSpan: edgeSpan,
        minorRadius: minorRadius,
        tipCos: tipCos,
        tipSin: tipSin,
        inverseRoundness: inverseRoundness,
        dabOpacity: dabOpacity,
        dabFlow: dabFlow,
        sourceAlphaNorm: sourceAlphaNorm,
        radiusSqSkip: radiusSqSkip,
        textureDensity: textureDensity,
        textureOneMinusDensity: textureOneMinusDensity,
        sourceR: sourceR,
        sourceG: sourceG,
        sourceB: sourceB,
        flags:
            (dabErase ? QaNativeEngine.dabFlagErase : 0) |
            (isRound ? QaNativeEngine.dabFlagRound : 0) |
            (isEllipse ? QaNativeEngine.dabFlagEllipse : 0) |
            (isRotatedRect ? QaNativeEngine.dabFlagRotatedRect : 0) |
            (unrotatedTip ? QaNativeEngine.dabFlagTipUnrotated : 0),
        regionLeft: left,
        regionTop: top,
        tipAlpha: tipMask?.alphaNormalized,
        tipSize: tipMask?.size ?? 0,
        tipUTexel0: tipULattice?.texel0,
        tipUFraction: tipULattice?.fraction,
        tipUOneMinus: tipULattice?.oneMinusFraction,
        tipUInRange: tipULattice?.inRange,
        tipVTexel0: tipVLattice?.texel0,
        tipVFraction: tipVLattice?.fraction,
        tipVOneMinus: tipVLattice?.oneMinusFraction,
        tipVInRange: tipVLattice?.inRange,
        dualAlpha: dualMask?.alphaNormalized,
        dualSize: dualMask?.size ?? 0,
        dualUTexel0: dualULattice?.texel0,
        dualUTexel1: dualULattice?.texel1,
        dualUFraction: dualULattice?.fraction,
        dualUOneMinus: dualULattice?.oneMinusFraction,
        dualVTexel0: dualVLattice?.texel0,
        dualVTexel1: dualVLattice?.texel1,
        dualVFraction: dualVLattice?.fraction,
        dualVOneMinus: dualVLattice?.oneMinusFraction,
        texAlpha: textureMask?.alphaNormalized,
        texSize: textureMask?.size ?? 0,
        texUTexel0: textureULattice?.texel0,
        texUTexel1: textureULattice?.texel1,
        texUFraction: textureULattice?.fraction,
        texUOneMinus: textureULattice?.oneMinusFraction,
        texVTexel0: textureVLattice?.texel0,
        texVTexel1: textureVLattice?.texel1,
        texVFraction: textureVLattice?.fraction,
        texVOneMinus: textureVLattice?.oneMinusFraction,
      );
      // One BATCH call per dab (R18 A-3a): the spans fan out across the
      // C worker pool — tiles are disjoint, so the result is
      // byte-identical to the sequential per-tile loop.
      final tileYStart = floorDiv(top, tileSize);
      final tileYEnd = floorDiv(bottomExclusive - 1, tileSize);
      final batchCoords = <TileCoord>[];
      native.ensureTileSpanBatch(
        (tileYEnd - tileYStart + 1) * (tileXEnd - tileXStart + 1),
      );
      for (var tileY = tileYStart; tileY <= tileYEnd; tileY += 1) {
        final tileTop = tileY * tileSize;
        final spanTop = math.max(top, tileTop);
        final spanBottomExclusive = math.min(
          bottomExclusive,
          tileTop + tileSize,
        );
        for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
          final coord = TileCoord(x: tileX, y: tileY);
          scratchBufferFor(coord);
          final buffer = nativeTiles![coord]!;
          final tileLeft = tileX * tileSize;
          native.setTileSpan(
            batchCoords.length,
            tilePixels: buffer.pointer,
            tileLeft: tileLeft,
            tileTop: tileTop,
            spanLeft: math.max(left, tileLeft),
            spanRightExclusive: math.min(rightExclusive, tileLeft + tileSize),
            spanTop: spanTop,
            spanBottomExclusive: spanBottomExclusive,
          );
          batchCoords.add(coord);
        }
      }
      final changed = native.dabBlendTiles(
        count: batchCoords.length,
        tileSize: tileSize,
      );
      for (var i = 0; i < batchCoords.length; i += 1) {
        if (changed[i] != 0) {
          changedCoords.add(batchCoords[i]);
        }
      }
      continue;
    }

    for (var y = top; y < bottomExclusive; y += 1) {
      final tileY = floorDiv(y, tileSize);
      final localRowOffset = (y - tileY * tileSize) * tileSize;
      final dy = y + 0.5 - centerY;
      final dySquared = dy * dy;
      final vIndex = y - top;
      if (tipVLattice != null && tipVLattice.inRange[vIndex] == 0) {
        // Same effect as the scalar |tipV| > radius per-pixel cull.
        continue;
      }

      for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
        final coord = TileCoord(x: tileX, y: tileY);
        final buffer = scratchBufferFor(coord);
        final tileLeft = tileX * tileSize;
        final spanLeft = math.max(left, tileLeft);
        final spanRightExclusive = math.min(
          rightExclusive,
          tileLeft + tileSize,
        );

        for (var x = spanLeft; x < spanRightExclusive; x += 1) {
          double coverage;
          if (tipMask != null) {
            if (unrotatedTip) {
              final uIndex = x - left;
              if (tipULattice!.inRange[uIndex] == 0) {
                continue;
              }
              coverage = sampleBrushTipMaskCoverageLattice(
                mask: tipMask,
                uAxis: tipULattice,
                uIndex: uIndex,
                vAxis: tipVLattice!,
                vIndex: vIndex,
              );
            } else {
              final dx = x + 0.5 - centerX;
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
              if (tipU.abs() > radius || tipV.abs() > radius) {
                continue;
              }
              coverage = sampleBrushTipMaskCoverage(
                mask: tipMask,
                tipU: tipU,
                tipV: tipV,
                radius: radius,
              );
            }
            if (coverage <= 0.0) {
              continue;
            }
          } else if (isRound) {
            final dx = x + 0.5 - centerX;
            double distance;
            if (isEllipse) {
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
              distance = math.sqrt(tipU * tipU + tipV * tipV);
            } else {
              final dxSquared = dx * dx;
              if (dxSquared + dySquared > radiusSqSkip) {
                continue;
              }
              distance = math.sqrt(dxSquared + dySquared);
            }
            if (distance > radius) {
              continue;
            }
            if (distance <= hardRadius || edgeSpan <= 0.0) {
              coverage = 1.0;
            } else {
              coverage = (1.0 - ((distance - hardRadius) / edgeSpan)).clamp(
                0.0,
                1.0,
              );
            }
            if (coverage <= 0.0) {
              continue;
            }
          } else {
            if (isRotatedRect) {
              final dx = x + 0.5 - centerX;
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = dx * tipSin + dy * tipCos;
              if (tipU.abs() > radius || tipV.abs() > minorRadius) {
                continue;
              }
            }
            coverage = 1.0;
          }

          // Dual-brush texture: a second tiled mask multiplies the coverage
          // (must match the live rasterizer and oracle exactly).
          if (dualMask != null) {
            coverage *= sampleBrushTipMaskTiledCoverageLattice(
              mask: dualMask,
              uAxis: dualULattice!,
              uIndex: x - left,
              vAxis: dualVLattice!,
              vIndex: vIndex,
            );
            if (coverage <= 0.0) {
              continue;
            }
          }

          // Paper texture: canvas-anchored tiled mask, blended in by density
          // (must match the live rasterizer and oracle exactly).
          if (textureMask != null) {
            final textureSample = sampleBrushTipMaskTiledCoverageLattice(
              mask: textureMask,
              uAxis: textureULattice!,
              uIndex: x - left,
              vAxis: textureVLattice!,
              vIndex: vIndex,
            );
            coverage *= textureOneMinusDensity + textureDensity * textureSample;
            if (coverage <= 0.0) {
              continue;
            }
          }

          // Same grouping as the reference path:
          // effectiveOpacity = dab.opacity * coverage,
          // sourceAlpha = ((a/255) * effectiveOpacity) * flow.
          final effectiveOpacity = dabOpacity * coverage;
          if (effectiveOpacity == 0.0) {
            continue;
          }
          final sourceAlpha = sourceAlphaNorm * effectiveOpacity * dabFlow;

          final offset =
              (localRowOffset + (x - tileLeft)) * BitmapTile.bytesPerPixel;
          final destR = buffer[offset];
          final destG = buffer[offset + 1];
          final destB = buffer[offset + 2];
          final destA = buffer[offset + 3];

          final destinationAlpha = destA / 255.0;

          int outRByte;
          int outGByte;
          int outBByte;
          int outAByte;
          if (dabErase) {
            // Destination-out (same grouping as the reference
            // rgbaDestinationOut): coverage removes destination alpha.
            final outAlpha = destinationAlpha * (1.0 - sourceAlpha);
            if (outAlpha == 0.0) {
              outRByte = 0;
              outGByte = 0;
              outBByte = 0;
              outAByte = 0;
            } else {
              outRByte = destR;
              outGByte = destG;
              outBByte = destB;
              outAByte = (outAlpha * 255.0).round().clamp(0, 255);
            }
          } else {
            final outAlpha =
                sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);
            if (outAlpha == 0.0) {
              outRByte = 0;
              outGByte = 0;
              outBByte = 0;
              outAByte = 0;
            } else {
              // Keep the exact floating-point grouping of the reference
              // rgbaSourceOver: (dest * destinationAlpha) *
              // inverseSourceAlpha.
              final inverseSourceAlpha = 1.0 - sourceAlpha;
              outRByte =
                  ((sourceR * sourceAlpha +
                              destR * destinationAlpha * inverseSourceAlpha) /
                          outAlpha)
                      .round()
                      .clamp(0, 255);
              outGByte =
                  ((sourceG * sourceAlpha +
                              destG * destinationAlpha * inverseSourceAlpha) /
                          outAlpha)
                      .round()
                      .clamp(0, 255);
              outBByte =
                  ((sourceB * sourceAlpha +
                              destB * destinationAlpha * inverseSourceAlpha) /
                          outAlpha)
                      .round()
                      .clamp(0, 255);
              outAByte = (outAlpha * 255.0).round().clamp(0, 255);
            }
          }

          if (outRByte != destR ||
              outGByte != destG ||
              outBByte != destB ||
              outAByte != destA) {
            buffer[offset] = outRByte;
            buffer[offset + 1] = outGByte;
            buffer[offset + 2] = outBByte;
            buffer[offset + 3] = outAByte;
            changedCoords.add(coord);
          }
        }
      }
    }
  }

  if (changedCoords.isEmpty) {
    releaseNativeTiles();
    return BrushSurfaceMaterialization(
      surface: surface,
      dirtyTiles: DirtyTileSet.empty(),
    );
  }

  final sortedCoords = changedCoords.toList()
    ..sort((a, b) {
      final yComparison = a.y.compareTo(b.y);
      if (yComparison != 0) return yComparison;
      return a.x.compareTo(b.x);
    });

  var updatedSurface = surface;
  var dirtyTiles = DirtyTileSet.empty();
  labProbe('commit.putTiles', () {
    // R19-Z: the CHANGED scratch buffers become the finished tiles — the
    // tile ADOPTS the native buffer (ownership leaves the pool; the
    // tile's finalizer frees it), so a full-canvas commit writes zero
    // pixel copies out. Untouched staged buffers still return to the
    // pool below; the Dart fallback keeps the constructor copy.
    updatedSurface = updatedSurface.putTiles([
      for (final coord in sortedCoords)
        if (nativeTiles != null)
          BitmapTile.adoptNative(
            coord: coord,
            size: tileSize,
            pixels: nativeTiles.remove(coord)!.pointer,
          )
        else
          BitmapTile(
            coord: coord,
            size: tileSize,
            pixels: scratchBuffers[coord]!,
          ),
    ]);
    for (final coord in sortedCoords) {
      dirtyTiles = dirtyTiles.add(coord);
    }
  });
  releaseNativeTiles();

  return BrushSurfaceMaterialization(
    surface: updatedSurface,
    dirtyTiles: dirtyTiles,
  );
}

/// The RGBA stamp blend (R14-④): the stamp's straight-alpha pixels land
/// 1:1 source-over centered on the dab (integer top-left from the center,
/// so a lift-then-drop round trip is byte-exact at full opacity). The
/// source-over float grouping matches the generic path's exactly.
void _blendStampDab({
  required BrushDab dab,
  required BrushStampImage stamp,
  required CanvasSize canvasSize,
  required int tileSize,
  required Uint8List Function(TileCoord) scratchBufferFor,
  required QaNativeTileBuffer Function(TileCoord)? nativeTileFor,
  required Set<TileCoord> changedCoords,
}) {
  final dabOpacity = dab.opacity;
  if (dabOpacity == 0.0) {
    return;
  }
  final stampLeft = (dab.center.x - stamp.width / 2).round();
  final stampTop = (dab.center.y - stamp.height / 2).round();
  // Pasteboard clip, NOT canvas: a selection dropped past the stage edge
  // keeps its pixels (they land on the pasteboard instead of vanishing).
  final left = math.max(canvasSize.pasteboardLeft, stampLeft);
  final top = math.max(canvasSize.pasteboardTop, stampTop);
  final rightExclusive = math.min(
    canvasSize.pasteboardRightExclusive,
    stampLeft + stamp.width,
  );
  final bottomExclusive = math.min(
    canvasSize.pasteboardBottomExclusive,
    stampTop + stamp.height,
  );
  if (rightExclusive <= left || bottomExclusive <= top) {
    return;
  }
  final rgba = stamp.rgba;

  // R18 A-0/A-1.5/F-1: the native core blends whole (dab, tile) spans in
  // ONE call each (the per-row FFI call overhead was the fill commit's
  // dominant term), and both sides are native memory — the tile scratch
  // is native-backed and the stamp uploads once per rgba identity (a
  // move session re-commits the SAME stamp per drag move, so repeats are
  // pure pointer math). Byte-identical to the Dart loop below
  // (parity-pinned); Dart remains the reference and the fallback.
  final native = QaNativeEngine.instance;
  final stampUpload = (native != null && nativeTileFor != null)
      ? labProbe('stamp.upload', () => native.uploadStampBytes(rgba))
      : null;
  if (stampUpload != null) {
    // One BATCH call for the whole stamp (R18 A-3a): spans fan out
    // across the C worker pool; disjoint tiles keep it byte-identical
    // to the sequential loop.
    final tileXStart = floorDiv(left, tileSize);
    final tileXEnd = floorDiv(rightExclusive - 1, tileSize);
    final tileYStart = floorDiv(top, tileSize);
    final tileYEnd = floorDiv(bottomExclusive - 1, tileSize);
    final batchCoords = <TileCoord>[];
    labProbe('stamp.stage', () {
      native!.ensureTileSpanBatch(
        (tileYEnd - tileYStart + 1) * (tileXEnd - tileXStart + 1),
      );
      for (var tileY = tileYStart; tileY <= tileYEnd; tileY += 1) {
        final tileTop = tileY * tileSize;
        for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
          final coord = TileCoord(x: tileX, y: tileY);
          final tileLeft = tileX * tileSize;
          native.setTileSpan(
            batchCoords.length,
            tilePixels: nativeTileFor!(coord).pointer,
            tileLeft: tileLeft,
            tileTop: tileTop,
            spanLeft: math.max(left, tileLeft),
            spanRightExclusive: math.min(rightExclusive, tileLeft + tileSize),
            spanTop: math.max(top, tileTop),
            spanBottomExclusive: math.min(bottomExclusive, tileTop + tileSize),
          );
          batchCoords.add(coord);
        }
      }
    });
    final changed = labProbe(
      'stamp.blend',
      () => native!.stampBlendTiles(
        count: batchCoords.length,
        tileSize: tileSize,
        stampBytes: stampUpload,
        stampWidth: stamp.width,
        stampLeft: stampLeft,
        stampTop: stampTop,
        opacity: dabOpacity,
        erase: dab.erase,
      ),
    );
    for (var i = 0; i < batchCoords.length; i += 1) {
      if (changed[i] != 0) {
        changedCoords.add(batchCoords[i]);
      }
    }
    return;
  }

  for (var y = top; y < bottomExclusive; y += 1) {
    final tileY = floorDiv(y, tileSize);
    final localRowOffset = (y - tileY * tileSize) * tileSize;
    final stampRowOffset = (y - stampTop) * stamp.width;
    final tileXStart = floorDiv(left, tileSize);
    final tileXEnd = floorDiv(rightExclusive - 1, tileSize);

    for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
      final coord = TileCoord(x: tileX, y: tileY);
      final tileLeft = tileX * tileSize;
      final spanLeft = math.max(left, tileLeft);
      final spanRightExclusive = math.min(rightExclusive, tileLeft + tileSize);

      final buffer = scratchBufferFor(coord);
      for (var x = spanLeft; x < spanRightExclusive; x += 1) {
        final sourceOffset = (stampRowOffset + (x - stampLeft)) * 4;
        final stampA = rgba[sourceOffset + 3];
        if (stampA == 0) {
          continue;
        }
        final offset =
            (localRowOffset + (x - tileLeft)) * BitmapTile.bytesPerPixel;

        // Opaque full-coverage fast paths (R16-④ measured: full-canvas
        // fill/lift stamps spent ~0.5s in the per-pixel double math) —
        // a fully covering stamp pixel at opacity 1 is a byte copy
        // (srcOver) or a byte zero (erase).
        if (stampA == 255 && dabOpacity == 1.0) {
          if (dab.erase) {
            if (buffer[offset] != 0 ||
                buffer[offset + 1] != 0 ||
                buffer[offset + 2] != 0 ||
                buffer[offset + 3] != 0) {
              buffer[offset] = 0;
              buffer[offset + 1] = 0;
              buffer[offset + 2] = 0;
              buffer[offset + 3] = 0;
              changedCoords.add(coord);
            }
          } else {
            if (buffer[offset] != rgba[sourceOffset] ||
                buffer[offset + 1] != rgba[sourceOffset + 1] ||
                buffer[offset + 2] != rgba[sourceOffset + 2] ||
                buffer[offset + 3] != 255) {
              buffer[offset] = rgba[sourceOffset];
              buffer[offset + 1] = rgba[sourceOffset + 1];
              buffer[offset + 2] = rgba[sourceOffset + 2];
              buffer[offset + 3] = 255;
              changedCoords.add(coord);
            }
          }
          continue;
        }
        final sourceAlpha = (stampA / 255.0) * dabOpacity;
        final destR = buffer[offset];
        final destG = buffer[offset + 1];
        final destB = buffer[offset + 2];
        final destA = buffer[offset + 3];
        final destinationAlpha = destA / 255.0;

        int outRByte;
        int outGByte;
        int outBByte;
        int outAByte;
        if (dab.erase) {
          // Stamp-ERASE (R15-④): destination-out from the stamp's EXACT
          // alpha — no tip-mask resampling, so a lift's cut edge is
          // byte-hard (the bilinear tip-mask erase left a half-alpha ring
          // at the selection silhouette: the fringe + origin remnant).
          final outAlpha = destinationAlpha * (1.0 - sourceAlpha);
          if (outAlpha == 0.0) {
            outRByte = 0;
            outGByte = 0;
            outBByte = 0;
            outAByte = 0;
          } else {
            outRByte = destR;
            outGByte = destG;
            outBByte = destB;
            outAByte = (outAlpha * 255.0).round().clamp(0, 255);
          }
          if (outRByte != destR ||
              outGByte != destG ||
              outBByte != destB ||
              outAByte != destA) {
            buffer[offset] = outRByte;
            buffer[offset + 1] = outGByte;
            buffer[offset + 2] = outBByte;
            buffer[offset + 3] = outAByte;
            changedCoords.add(coord);
          }
          continue;
        }

        final outAlpha = sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);
        if (outAlpha == 0.0) {
          outRByte = 0;
          outGByte = 0;
          outBByte = 0;
          outAByte = 0;
        } else {
          final inverseSourceAlpha = 1.0 - sourceAlpha;
          outRByte =
              ((rgba[sourceOffset] * sourceAlpha +
                          destR * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          outGByte =
              ((rgba[sourceOffset + 1] * sourceAlpha +
                          destG * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          outBByte =
              ((rgba[sourceOffset + 2] * sourceAlpha +
                          destB * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          outAByte = (outAlpha * 255.0).round().clamp(0, 255);
        }

        if (outRByte != destR ||
            outGByte != destG ||
            outBByte != destB ||
            outAByte != destA) {
          buffer[offset] = outRByte;
          buffer[offset + 1] = outGByte;
          buffer[offset + 2] = outBByte;
          buffer[offset + 3] = outAByte;
          changedCoords.add(coord);
        }
      }
    }
  }
}

/// Composites a pre-rasterized straight-alpha stroke buffer onto [surface]
/// within [bounds].
///
/// [strokePixels] is BOUNDS-LOCAL: row-major with stride = the bounds
/// width, exactly what `BrushLiveStrokeRasterizer.strokePixelsWithinBounds`
/// materializes — its size scales with the stroke, never the canvas.
///
/// This is the pen-up fast path: the interactive view rasterizes the stroke
/// incrementally while the pointer moves (`BrushLiveStrokeRasterizer`, same
/// per-dab math as [materializeBrushDabSequenceOnBitmapSurface]), so commit
/// only needs one source-over pass of the finished stroke over the existing
/// artwork instead of re-running the whole dab loop — removing the commit
/// hiccup for long dense strokes. The composited pixels are exactly the
/// stroke the user watched being drawn.
///
/// R21: implemented as ONE synthetic stamp dab through the ordinary
/// materializer — the stroke buffer IS a stamp at the bounds (integer
/// placement is exact: center = left + w/2 rounds back to left), and the
/// stamp blend's opacity-1 source-over/destination-out is byte-identical
/// to the old inline loop. That routes the pen-up composite through the
/// SAME C kernels as everything else; the pure-Dart pass here was a
/// measured ~91ms-avg/193ms-max UI hitch per stroke at 2340×1654.
BrushSurfaceMaterialization compositeStrokePixelsOntoBitmapSurface({
  required BitmapSurface surface,
  required Uint8List strokePixels,
  required DirtyRegion bounds,
  bool erase = false,
  BrushBlendMode blendMode = BrushBlendMode.color,
}) {
  final width = bounds.rightExclusive - bounds.left;
  final height = bounds.bottomExclusive - bounds.top;
  if (width <= 0 || height <= 0) {
    return BrushSurfaceMaterialization(
      surface: surface,
      dirtyTiles: DirtyTileSet.empty(),
    );
  }
  BrushDab boundsStampDab({
    required String id,
    required Uint8List rgba,
    required bool erase,
    int sequence = 0,
  }) => BrushDab(
    center: CanvasPoint(
      x: bounds.left + width / 2,
      y: bounds.top + height / 2,
    ),
    color: 0xFF000000,
    size: math.max(width, height).toDouble(),
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: sequence,
    erase: erase,
    stamp: BrushStampImage(id: id, width: width, height: height, rgba: rgba),
  );

  // BB-1 (R26 #9): a non-trivial BRUSH BLEND applies once per stroke —
  // the result region is computed through the blend kernel and lands
  // through the SAME stamp kernels as everything else: an erase-rect
  // pass clears the bounds, then a source-over pass writes the result
  // verbatim (over emptiness srcOver IS replace, byte-exactly). Pixels
  // the stroke never touched come back verbatim from the kernel's
  // alpha-0 copy rule, so the round trip is invisible outside the ink.
  if (blendMode != BrushBlendMode.color && blendMode != BrushBlendMode.erase) {
    final result = blendStrokeRegionPixels(
      dst: bitmapSurfaceRegionPixels(surface, bounds),
      src: strokePixels,
      mode: blendMode,
      pixelCount: width * height,
    );
    final opaqueRect = Uint8List(width * height * 4)
      ..fillRange(0, width * height * 4, 0xFF);
    return materializeBrushDabSequenceOnBitmapSurface(
      surface: surface,
      sequence: BrushDabSequence([
        boundsStampDab(id: 'stroke-blend-clear', rgba: opaqueRect, erase: true),
        boundsStampDab(
          id: 'stroke-blend-result',
          rgba: result,
          erase: false,
          sequence: 1,
        ),
      ]),
    );
  }
  return materializeBrushDabSequenceOnBitmapSurface(
    surface: surface,
    sequence: BrushDabSequence([
      boundsStampDab(
        id: 'stroke-composite',
        rgba: strokePixels,
        erase: erase || blendMode == BrushBlendMode.erase,
      ),
    ]),
  );
}
