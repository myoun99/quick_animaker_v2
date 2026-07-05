import 'dart:collection';

import '../core/collection_equality.dart';
import 'frame.dart';
import 'layer_id.dart';
import 'layer_kind.dart';
import 'timeline_exposure.dart';
import 'timeline_mark.dart';

class Layer {
  Layer({
    required this.id,
    required this.name,
    required List<Frame> frames,
    Map<int, TimelineExposure>? timeline,
    Map<int, TimelineMark>? marks,
    this.isVisible = true,
    this.opacity = 1.0,
    this.kind = LayerKind.animation,
  }) : frames = List.unmodifiable(frames),
       timeline = _immutableTimeline(timeline ?? _deriveTimeline(frames)),
       marks = _immutableMarks(marks ?? const {});

  final LayerId id;
  final String name;
  final List<Frame> frames;
  final SplayTreeMap<int, TimelineExposure> timeline;
  final SplayTreeMap<int, TimelineMark> marks;
  final bool isVisible;
  final double opacity;
  final LayerKind kind;

  Layer copyWith({
    LayerId? id,
    String? name,
    List<Frame>? frames,
    Map<int, TimelineExposure>? timeline,
    Map<int, TimelineMark>? marks,
    bool? isVisible,
    double? opacity,
    LayerKind? kind,
  }) {
    final nextFrames = frames ?? this.frames;
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      frames: nextFrames,
      timeline: timeline ?? this.timeline,
      marks: marks ?? this.marks,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'frames': frames.map((frame) => frame.toJson()).toList(),
    'timeline': timeline.entries
        .map((entry) => {'index': entry.key, 'exposure': entry.value.toJson()})
        .toList(),
    'marks': marks.entries
        .map((entry) => {'index': entry.key, 'mark': entry.value.toJson()})
        .toList(),
    'isVisible': isVisible,
    'opacity': opacity,
    'kind': kind.toJson(),
  };

  factory Layer.fromJson(Map<String, dynamic> json) {
    final frames = (json['frames'] as List<dynamic>)
        .map((frame) => Frame.fromJson(frame as Map<String, dynamic>))
        .toList();
    return Layer(
      id: LayerId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      frames: frames,
      timeline: json.containsKey('timeline')
          ? _timelineFromJson(json['timeline'])
          : _deriveTimeline(frames),
      marks: json.containsKey('marks')
          ? _marksFromJson(json['marks'])
          : const {},
      isVisible: json['isVisible'] as bool,
      opacity: (json['opacity'] as num).toDouble(),
      kind: json.containsKey('kind')
          ? LayerKind.fromJson(json['kind'])
          : LayerKind.animation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Layer &&
          other.id == id &&
          other.name == name &&
          listEquals(other.frames, frames) &&
          mapEquals(other.timeline, timeline) &&
          mapEquals(other.marks, marks) &&
          other.isVisible == isVisible &&
          other.opacity == opacity &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(frames),
    Object.hashAll(
      timeline.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAll(
      marks.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    isVisible,
    opacity,
    kind,
  );

  @override
  String toString() =>
      'Layer(id: $id, name: $name, frames: $frames, timeline: $timeline, '
      'marks: $marks, isVisible: $isVisible, opacity: $opacity, kind: $kind)';
}

SplayTreeMap<int, TimelineExposure> _immutableTimeline(
  Map<int, TimelineExposure> timeline,
) {
  final result = SplayTreeMap<int, TimelineExposure>();
  for (final entry in timeline.entries) {
    if (entry.key < 0) {
      throw ArgumentError.value(
        entry.key,
        'timeline',
        'Timeline indexes must be non-negative.',
      );
    }
    result[entry.key] = entry.value;
  }
  return result;
}

SplayTreeMap<int, TimelineMark> _immutableMarks(Map<int, TimelineMark> marks) {
  final result = SplayTreeMap<int, TimelineMark>();
  for (final entry in marks.entries) {
    if (entry.key < 0) {
      throw ArgumentError.value(
        entry.key,
        'marks',
        'Timeline mark indexes must be non-negative.',
      );
    }
    result[entry.key] = entry.value;
  }
  return result;
}

SplayTreeMap<int, TimelineExposure> _deriveTimeline(List<Frame> frames) {
  final timeline = SplayTreeMap<int, TimelineExposure>();
  var index = 0;
  for (final frame in frames) {
    timeline[index] = TimelineExposure.drawing(frame.id);
    index += frame.duration <= 0 ? 1 : frame.duration;
  }
  return timeline;
}

SplayTreeMap<int, TimelineExposure> _timelineFromJson(Object? json) {
  final timeline = SplayTreeMap<int, TimelineExposure>();

  if (json is List<dynamic>) {
    for (final item in json) {
      final entry = item as Map<String, dynamic>;
      final index = entry['index'] as int;
      if (index < 0) {
        throw const FormatException('Timeline indexes must be non-negative.');
      }
      if (timeline.containsKey(index)) {
        throw FormatException('Duplicate timeline index: $index');
      }
      timeline[index] = TimelineExposure.fromJson(
        entry['exposure'] as Map<String, dynamic>,
      );
    }
    return timeline;
  }

  if (json is Map<String, dynamic>) {
    for (final entry in json.entries) {
      final index = int.tryParse(entry.key);
      if (index == null || index < 0) {
        throw FormatException('Invalid timeline index: ${entry.key}');
      }
      if (timeline.containsKey(index)) {
        throw FormatException('Duplicate timeline index: $index');
      }
      timeline[index] = TimelineExposure.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    return timeline;
  }

  throw const FormatException('Layer timeline must be a list or object.');
}

SplayTreeMap<int, TimelineMark> _marksFromJson(Object? json) {
  final marks = SplayTreeMap<int, TimelineMark>();

  if (json is List<dynamic>) {
    for (final item in json) {
      final entry = item as Map<String, dynamic>;
      final index = entry['index'] as int;
      if (index < 0) {
        throw const FormatException(
          'Timeline mark indexes must be non-negative.',
        );
      }
      if (marks.containsKey(index)) {
        throw FormatException('Duplicate timeline mark index: $index');
      }
      marks[index] = TimelineMark.fromJson(
        entry['mark'] as Map<String, dynamic>,
      );
    }
    return marks;
  }

  if (json is Map<String, dynamic>) {
    for (final entry in json.entries) {
      final index = int.tryParse(entry.key);
      if (index == null || index < 0) {
        throw FormatException('Invalid timeline mark index: ${entry.key}');
      }
      if (marks.containsKey(index)) {
        throw FormatException('Duplicate timeline mark index: $index');
      }
      marks[index] = TimelineMark.fromJson(entry.value as Map<String, dynamic>);
    }
    return marks;
  }

  throw const FormatException('Layer marks must be a list or object.');
}
