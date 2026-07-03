import 'canvas_point.dart';
import 'viewport_point.dart';

class CanvasViewport {
  static const double minZoom = 0.1;
  static const double maxZoom = 16.0;

  CanvasViewport({this.zoom = 1.0, this.panX = 0.0, this.panY = 0.0}) {
    _validateZoom(zoom);
    _validateFinitePan(panX, 'panX');
    _validateFinitePan(panY, 'panY');
  }

  final double zoom;
  final double panX;
  final double panY;

  CanvasViewport copyWith({double? zoom, double? panX, double? panY}) {
    return CanvasViewport(
      zoom: zoom ?? this.zoom,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
    );
  }

  CanvasViewport clamped() {
    return copyWith(zoom: zoom.clamp(minZoom, maxZoom).toDouble());
  }

  CanvasViewport translated({required double dx, required double dy}) {
    return copyWith(panX: panX + dx, panY: panY + dy);
  }

  CanvasViewport zoomedAround({
    required double nextZoom,
    required ViewportPoint anchor,
  }) {
    final clampedZoom = nextZoom.clamp(minZoom, maxZoom).toDouble();
    final before = viewportToCanvas(anchor);
    return CanvasViewport(
      zoom: clampedZoom,
      panX: anchor.x - before.x * clampedZoom,
      panY: anchor.y - before.y * clampedZoom,
    );
  }

  factory CanvasViewport.fitToView({
    required double canvasWidth,
    required double canvasHeight,
    required double viewportWidth,
    required double viewportHeight,
    double padding = 24.0,
  }) {
    _validatePositiveFinite(canvasWidth, 'canvasWidth');
    _validatePositiveFinite(canvasHeight, 'canvasHeight');
    _validatePositiveFinite(viewportWidth, 'viewportWidth');
    _validatePositiveFinite(viewportHeight, 'viewportHeight');
    if (!padding.isFinite || padding < 0) {
      throw ArgumentError.value(
        padding,
        'padding',
        'CanvasViewport.fitToView padding must be finite and non-negative.',
      );
    }

    final usableWidth = (viewportWidth - padding * 2).clamp(1.0, viewportWidth);
    final usableHeight = (viewportHeight - padding * 2).clamp(
      1.0,
      viewportHeight,
    );
    final zoom = (usableWidth / canvasWidth) < (usableHeight / canvasHeight)
        ? usableWidth / canvasWidth
        : usableHeight / canvasHeight;
    final clampedZoom = zoom.clamp(minZoom, maxZoom).toDouble();

    return CanvasViewport(
      zoom: clampedZoom,
      panX: (viewportWidth - canvasWidth * clampedZoom) / 2,
      panY: (viewportHeight - canvasHeight * clampedZoom) / 2,
    );
  }

  ViewportPoint canvasToViewport(CanvasPoint point) {
    return ViewportPoint(x: point.x * zoom + panX, y: point.y * zoom + panY);
  }

  CanvasPoint viewportToCanvas(ViewportPoint point) {
    return CanvasPoint(x: (point.x - panX) / zoom, y: (point.y - panY) / zoom);
  }

  Map<String, dynamic> toJson() => {'zoom': zoom, 'panX': panX, 'panY': panY};

  factory CanvasViewport.fromJson(Map<String, dynamic> json) {
    return CanvasViewport(
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      panX: (json['panX'] as num?)?.toDouble() ?? 0.0,
      panY: (json['panY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasViewport &&
          other.zoom == zoom &&
          other.panX == panX &&
          other.panY == panY;

  @override
  int get hashCode => Object.hash(zoom, panX, panY);

  @override
  String toString() => 'CanvasViewport(zoom: $zoom, panX: $panX, panY: $panY)';
}

void _validateZoom(double value) {
  if (!value.isFinite || value <= 0.0) {
    throw ArgumentError.value(
      value,
      'zoom',
      'CanvasViewport.zoom must be finite and greater than 0.',
    );
  }
}

void _validateFinitePan(double value, String fieldName) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      fieldName,
      'CanvasViewport.$fieldName must be finite.',
    );
  }
}

void _validatePositiveFinite(double value, String fieldName) {
  if (!value.isFinite || value <= 0.0) {
    throw ArgumentError.value(
      value,
      fieldName,
      'CanvasViewport.$fieldName must be finite and greater than 0.',
    );
  }
}
