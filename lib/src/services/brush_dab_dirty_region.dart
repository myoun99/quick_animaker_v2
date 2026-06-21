import 'dart:math' as math;

import '../models/brush_dab.dart';
import '../models/brush_dab_sequence.dart';
import '../models/dirty_region.dart';
import '../models/dirty_tile_set.dart';

DirtyRegion? dirtyRegionForBrushDab(BrushDab dab) {
  if (dab.size == 0 || dab.opacity == 0 || dab.flow == 0) {
    return null;
  }

  final radius = dab.size / 2.0;
  final left = math.max(0, (dab.center.x - radius).floor());
  final top = math.max(0, (dab.center.y - radius).floor());
  final rightExclusive = (dab.center.x + radius).ceil();
  final bottomExclusive = (dab.center.y + radius).ceil();

  if (rightExclusive <= left || bottomExclusive <= top) {
    return null;
  }

  return DirtyRegion(
    left: left,
    top: top,
    rightExclusive: rightExclusive,
    bottomExclusive: bottomExclusive,
  );
}

List<DirtyRegion> dirtyRegionsForBrushDabSequence(BrushDabSequence sequence) {
  return List<DirtyRegion>.unmodifiable(
    sequence.dabs.map(dirtyRegionForBrushDab).whereType<DirtyRegion>(),
  );
}

DirtyRegion? dirtyRegionForBrushDabSequence(BrushDabSequence sequence) {
  final regions = dirtyRegionsForBrushDabSequence(sequence);
  if (regions.isEmpty) {
    return null;
  }

  return regions.skip(1).fold<DirtyRegion>(regions.first, (union, region) {
    return union.union(region);
  });
}

DirtyTileSet dirtyTileSetForBrushDabSequence({
  required BrushDabSequence sequence,
  required int tileSize,
}) {
  if (tileSize <= 0) {
    throw ArgumentError.value(
      tileSize,
      'tileSize',
      'tileSize must be greater than 0.',
    );
  }

  final regions = dirtyRegionsForBrushDabSequence(sequence);
  if (regions.isEmpty) {
    return DirtyTileSet.empty();
  }

  return DirtyTileSet.fromRegions(regions: regions, tileSize: tileSize);
}
