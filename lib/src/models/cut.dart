import 'canvas_size.dart';
import 'cut_id.dart';
import 'layer.dart';

class Cut {
  Cut({
    required this.id,
    required this.name,
    required List<Layer> layers,
    required this.duration,
    required this.canvasSize,
  }) : layers = List.unmodifiable(layers);

  final CutId id;
  final String name;
  final List<Layer> layers;
  final int duration;
  final CanvasSize canvasSize;

  Cut copyWith({
    CutId? id,
    String? name,
    List<Layer>? layers,
    int? duration,
    CanvasSize? canvasSize,
  }) {
    return Cut(
      id: id ?? this.id,
      name: name ?? this.name,
      layers: layers ?? this.layers,
      duration: duration ?? this.duration,
      canvasSize: canvasSize ?? this.canvasSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.toJson(),
        'name': name,
        'layers': layers.map((layer) => layer.toJson()).toList(),
        'duration': duration,
        'canvasSize': canvasSize.toJson(),
      };

  factory Cut.fromJson(Map<String, dynamic> json) {
    return Cut(
      id: CutId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      layers: (json['layers'] as List<dynamic>)
          .map((layer) => Layer.fromJson(layer as Map<String, dynamic>))
          .toList(),
      duration: json['duration'] as int,
      canvasSize: CanvasSize.fromJson(
        json['canvasSize'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cut &&
          other.id == id &&
          other.name == name &&
          _listEquals(other.layers, layers) &&
          other.duration == duration &&
          other.canvasSize == canvasSize;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(layers), duration, canvasSize);

  @override
  String toString() =>
      'Cut(id: $id, name: $name, layers: $layers, duration: $duration, canvasSize: $canvasSize)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
