import '../core/collection_equality.dart';
import 'frame_id.dart';
import 'storyboard_frame_metadata.dart';
import '../core/copy_with_sentinel.dart';
import 'stroke.dart';

class Frame {
  Frame({
    required this.id,
    required this.duration,
    required List<Stroke> strokes,
    this.name,
    this.storyboardMetadata = const StoryboardFrameMetadata.empty(),
  }) : strokes = List.unmodifiable(strokes);

  final FrameId id;
  final int duration;
  final List<Stroke> strokes;
  final String? name;
  final StoryboardFrameMetadata storyboardMetadata;

  Frame copyWith({
    FrameId? id,
    int? duration,
    List<Stroke>? strokes,
    Object? name = copyWithSentinel,
    StoryboardFrameMetadata? storyboardMetadata,
  }) {
    return Frame(
      id: id ?? this.id,
      duration: duration ?? this.duration,
      strokes: strokes ?? this.strokes,
      name: identical(name, copyWithSentinel) ? this.name : name as String?,
      storyboardMetadata: storyboardMetadata ?? this.storyboardMetadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'duration': duration,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    if (name != null) 'name': name,
    'storyboardMetadata': storyboardMetadata.toJson(),
  };

  factory Frame.fromJson(Map<String, dynamic> json) {
    return Frame(
      id: FrameId.fromJson(json['id'] as Map<String, dynamic>),
      duration: json['duration'] as int,
      strokes: (json['strokes'] as List<dynamic>)
          .map((stroke) => Stroke.fromJson(stroke as Map<String, dynamic>))
          .toList(),
      name: json['name'] as String?,
      storyboardMetadata: json['storyboardMetadata'] == null
          ? const StoryboardFrameMetadata.empty()
          : StoryboardFrameMetadata.fromJson(
              json['storyboardMetadata'] as Map<String, dynamic>,
            ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Frame &&
          other.id == id &&
          other.duration == duration &&
          other.name == name &&
          other.storyboardMetadata == storyboardMetadata &&
          listEquals(other.strokes, strokes);

  @override
  int get hashCode => Object.hash(
    id,
    duration,
    name,
    storyboardMetadata,
    Object.hashAll(strokes),
  );

  @override
  String toString() =>
      'Frame(id: $id, duration: $duration, name: $name, strokes: $strokes, storyboardMetadata: $storyboardMetadata)';
}
