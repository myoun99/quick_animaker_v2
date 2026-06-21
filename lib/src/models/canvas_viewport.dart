import 'canvas_point.dart';
import 'viewport_point.dart';

class CanvasViewport {
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
  String toString() =>
      'CanvasViewport(zoom: $zoom, panX: $panX, panY: $panY)';
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
