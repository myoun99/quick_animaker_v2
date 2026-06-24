import 'bitmap_surface.dart';
import 'brush_surface_edit.dart';

const Object _copyWithSentinel = Object();

class CanvasSurfaceState {
  CanvasSurfaceState({required this.currentSurface, this.lastEdit});

  final BitmapSurface currentSurface;
  final BrushSurfaceEdit? lastEdit;

  bool get hasLastEdit => lastEdit != null;

  CanvasSurfaceState copyWith({
    BitmapSurface? currentSurface,
    Object? lastEdit = _copyWithSentinel,
  }) {
    return CanvasSurfaceState(
      currentSurface: currentSurface ?? this.currentSurface,
      lastEdit: identical(lastEdit, _copyWithSentinel)
          ? this.lastEdit
          : lastEdit as BrushSurfaceEdit?,
    );
  }

  CanvasSurfaceState clearLastEdit() => copyWith(lastEdit: null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasSurfaceState &&
          other.currentSurface == currentSurface &&
          other.lastEdit == lastEdit;

  @override
  int get hashCode => Object.hash(currentSurface, lastEdit);

  @override
  String toString() =>
      'CanvasSurfaceState(currentSurface: $currentSurface, '
      'lastEdit: $lastEdit)';
}
