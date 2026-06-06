enum TimelineMarkType {
  inbetween;

  String toJson() => name;

  static TimelineMarkType fromJson(Object? value) {
    if (value == 'inbetween') {
      return TimelineMarkType.inbetween;
    }
    throw FormatException('Unknown timeline mark type: $value');
  }
}
