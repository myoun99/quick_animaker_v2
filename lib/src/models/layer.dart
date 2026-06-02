import 'frame.dart';
import 'layer_id.dart';

class Layer {
  Layer({
    required this.id,
    required this.name,
    required List<Frame> frames,
    this.isVisible = true,
    this.opacity = 1.0,
  }) : frames = List.unmodifiable(frames);

  final LayerId id;
  final String name;
  final List<Frame> frames;
  final bool isVisible;
  final double opacity;

  Layer copyWith({
    LayerId? id,
    String? name,
    List<Frame>? frames,
    bool? isVisible,
    double? opacity,
  }) {
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      frames: frames ?? this.frames,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.toJson(),
        'name': name,
        'frames': frames.map((frame) => frame.toJson()).toList(),
        'isVisible': isVisible,
        'opacity': opacity,
      };

  factory Layer.fromJson(Map<String, dynamic> json) {
    return Layer(
      id: LayerId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      frames: (json['frames'] as List<dynamic>)
          .map((frame) => Frame.fromJson(frame as Map<String, dynamic>))
          .toList(),
      isVisible: json['isVisible'] as bool,
      opacity: (json['opacity'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Layer &&
          other.id == id &&
          other.name == name &&
          _listEquals(other.frames, frames) &&
          other.isVisible == isVisible &&
          other.opacity == opacity;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(frames), isVisible, opacity);

  @override
  String toString() =>
      'Layer(id: $id, name: $name, frames: $frames, isVisible: $isVisible, opacity: $opacity)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
