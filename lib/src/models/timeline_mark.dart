import 'timeline_mark_type.dart';

class TimelineMark {
  const TimelineMark({required this.type});

  const TimelineMark.inbetween() : type = TimelineMarkType.inbetween;

  final TimelineMarkType type;

  TimelineMark copyWith({TimelineMarkType? type}) {
    return TimelineMark(type: type ?? this.type);
  }

  Map<String, dynamic> toJson() => {'type': type.toJson()};

  factory TimelineMark.fromJson(Map<String, dynamic> json) {
    return TimelineMark(type: TimelineMarkType.fromJson(json['type']));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TimelineMark && other.type == type;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'TimelineMark(type: $type)';
}
