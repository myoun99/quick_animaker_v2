import 'frame_id.dart';
import 'stroke.dart';

class Frame {
  Frame({
    required this.id,
    required this.duration,
    required List<Stroke> strokes,
  }) : strokes = List.unmodifiable(strokes);

  final FrameId id;
  final int duration;
  final List<Stroke> strokes;

  Frame copyWith({FrameId? id, int? duration, List<Stroke>? strokes}) {
    return Frame(
      id: id ?? this.id,
      duration: duration ?? this.duration,
      strokes: strokes ?? this.strokes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.toJson(),
        'duration': duration,
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      };

  factory Frame.fromJson(Map<String, dynamic> json) {
    return Frame(
      id: FrameId.fromJson(json['id'] as Map<String, dynamic>),
      duration: json['duration'] as int,
      strokes: (json['strokes'] as List<dynamic>)
          .map((stroke) => Stroke.fromJson(stroke as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Frame &&
          other.id == id &&
          other.duration == duration &&
          _listEquals(other.strokes, strokes);

  @override
  int get hashCode => Object.hash(id, duration, Object.hashAll(strokes));

  @override
  String toString() => 'Frame(id: $id, duration: $duration, strokes: $strokes)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
