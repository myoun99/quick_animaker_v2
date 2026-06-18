import 'dart:math' as math;

int? frameIndexFromLocalX({
  required double localX,
  required double horizontalScrollOffset,
  required double frameCellWidth,
  required int visibleFrameCount,
}) {
  if (visibleFrameCount <= 0 || frameCellWidth <= 0) {
    return null;
  }

  final frameIndex = ((localX + horizontalScrollOffset) / frameCellWidth)
      .floor();

  return clampFrameIndex(
    frameIndex: frameIndex,
    visibleFrameCount: visibleFrameCount,
  );
}

int? clampFrameIndex({
  required int frameIndex,
  required int visibleFrameCount,
}) {
  if (visibleFrameCount <= 0) {
    return null;
  }

  return frameIndex.clamp(0, visibleFrameCount - 1).toInt();
}

double frameContentX({
  required int frameIndex,
  required double frameCellWidth,
}) {
  return frameIndex * frameCellWidth;
}

double frameVisibleX({
  required int frameIndex,
  required int frameStartIndex,
  required double frameCellWidth,
  required double leadingFrameSpacerWidth,
}) {
  return leadingFrameSpacerWidth +
      (frameIndex - frameStartIndex) * frameCellWidth;
}

double frameRangeVisibleWidth({
  required int startFrameIndex,
  required int endFrameIndexExclusive,
  required double frameCellWidth,
}) {
  return math.max(0, endFrameIndexExclusive - startFrameIndex) *
      frameCellWidth;
}
