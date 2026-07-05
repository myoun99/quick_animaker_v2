import '../core/copy_with_sentinel.dart';
import 'bitmap_surface.dart';
import 'brush_surface_edit.dart';

class CanvasSurfaceState {
  CanvasSurfaceState({required this.currentSurface, this.lastEdit});

  final BitmapSurface currentSurface;
  final BrushSurfaceEdit? lastEdit;

  bool get hasLastEdit => lastEdit != null;

  CanvasSurfaceState copyWith({
    BitmapSurface? currentSurface,
    Object? lastEdit = copyWithSentinel,
  }) {
    return CanvasSurfaceState(
      currentSurface: currentSurface ?? this.currentSurface,
      lastEdit: identical(lastEdit, copyWithSentinel)
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
