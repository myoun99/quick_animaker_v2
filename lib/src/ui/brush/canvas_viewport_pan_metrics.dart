import 'package:flutter/widgets.dart';

import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';

class CanvasViewportPanMetrics {
  static const double minThumbExtent = 24;

  CanvasViewportPanMetrics({
    required this.axis,
    required this.viewport,
    required this.editorViewportSize,
    required this.canvasSize,
    required double trackExtent,
  }) : trackExtent = _finiteNonNegative(trackExtent),
       visibleExtent = _visibleExtent(axis, editorViewportSize) {
    // The canvas content's viewport-space AABB (pan excluded): under
    // rotation/flip the panbar tracks the rotated silhouette, not the raw
    // canvas rect.
    final bounds = _contentBounds(axis, viewport, canvasSize);
    scaledContentExtent = _finiteNonNegative(bounds.extent);
    _contentOffset = bounds.start;
    maxScroll = (scaledContentExtent - visibleExtent)
        .clamp(0.0, double.infinity)
        .toDouble();
    canScroll = maxScroll > 0 && this.trackExtent > 0;
    if (!canScroll) {
      thumbExtent = this.trackExtent;
      thumbTravel = 0;
      thumbStart = 0;
      return;
    }

    final proportionalExtent =
        visibleExtent / scaledContentExtent * this.trackExtent;
    final safeMinimum = minThumbExtent.clamp(0.0, this.trackExtent).toDouble();
    thumbExtent = proportionalExtent
        .clamp(safeMinimum, this.trackExtent)
        .toDouble();
    thumbTravel = (this.trackExtent - thumbExtent)
        .clamp(0.0, double.infinity)
        .toDouble();
    final pan = axis == Axis.horizontal ? viewport.panX : viewport.panY;
    final scroll = (-(pan + _contentOffset)).clamp(0.0, maxScroll).toDouble();
    thumbStart = thumbTravel == 0 ? 0 : scroll / maxScroll * thumbTravel;
  }

  final Axis axis;
  final CanvasViewport viewport;
  final Size editorViewportSize;
  final CanvasSize canvasSize;
  final double trackExtent;
  late final double scaledContentExtent;
  final double visibleExtent;
  late final double maxScroll;
  late final bool canScroll;
  late final double thumbExtent;
  late final double thumbTravel;
  late final double thumbStart;

  /// The content AABB's start along [axis] relative to the pan (0 without
  /// rotation/flip, where the canvas origin IS the content start).
  late final double _contentOffset;

  CanvasViewport panToThumb(double thumbStart) {
    if (!canScroll || thumbTravel <= 0) {
      return viewport;
    }
    final clampedThumbStart = thumbStart.clamp(0.0, thumbTravel).toDouble();
    final scroll = clampedThumbStart / thumbTravel * maxScroll;
    return axis == Axis.horizontal
        ? viewport.copyWith(panX: -scroll - _contentOffset)
        : viewport.copyWith(panY: -scroll - _contentOffset);
  }

  CanvasViewport thumbDeltaToPanDelta(double thumbDelta) {
    if (!canScroll || thumbTravel <= 0 || !thumbDelta.isFinite) {
      return viewport;
    }
    final panDelta = -(thumbDelta / thumbTravel) * maxScroll;
    return axis == Axis.horizontal
        ? viewport.copyWith(panX: viewport.panX + panDelta)
        : viewport.copyWith(panY: viewport.panY + panDelta);
  }

  static ({double start, double extent}) _contentBounds(
    Axis axis,
    CanvasViewport viewport,
    CanvasSize canvasSize,
  ) {
    if (!viewport.hasRotationOrFlip) {
      final source = axis == Axis.horizontal
          ? canvasSize.width
          : canvasSize.height;
      return (start: 0, extent: source * viewport.zoom);
    }
    final unpanned = viewport.copyWith(panX: 0, panY: 0);
    final width = canvasSize.width.toDouble();
    final height = canvasSize.height.toDouble();
    double? min;
    double? max;
    for (final corner in [
      CanvasPoint(x: 0, y: 0),
      CanvasPoint(x: width, y: 0),
      CanvasPoint(x: width, y: height),
      CanvasPoint(x: 0, y: height),
    ]) {
      final mapped = unpanned.canvasToViewport(corner);
      final value = axis == Axis.horizontal ? mapped.x : mapped.y;
      min = min == null || value < min ? value : min;
      max = max == null || value > max ? value : max;
    }
    return (start: min!, extent: max! - min);
  }

  static double _visibleExtent(Axis axis, Size editorViewportSize) {
    final source = axis == Axis.horizontal
        ? editorViewportSize.width
        : editorViewportSize.height;
    return _finiteNonNegative(source);
  }

  static double _finiteNonNegative(double value) {
    if (!value.isFinite || value <= 0) {
      return 0;
    }
    return value;
  }
}
