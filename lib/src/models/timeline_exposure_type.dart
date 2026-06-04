enum TimelineExposureType {
  drawing,
  blank;

  String toJson() => name;

  static TimelineExposureType fromJson(Object? value) {
    if (value == 'drawing') {
      return TimelineExposureType.drawing;
    }
    if (value == 'blank') {
      return TimelineExposureType.blank;
    }
    throw FormatException('Unknown timeline exposure type: $value');
  }
}
