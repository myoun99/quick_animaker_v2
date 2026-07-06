/// The two things a timeline index can record: a drawing (a cel block start
/// with an explicit length) or an inbetween mark.
///
/// Emptiness is NOT a timeline entry: cells not covered by any drawing
/// block are simply uncovered, and the UI renders them with the timesheet
/// "X" glyph. (The legacy `blank` entry type is migrated away on load — a
/// blank used to terminate a hold, which explicit drawing lengths now
/// express directly.)
enum TimelineExposureType {
  drawing,
  mark;

  String toJson() => name;

  static TimelineExposureType fromJson(Object? value) {
    if (value == 'drawing') {
      return TimelineExposureType.drawing;
    }
    if (value == 'mark') {
      return TimelineExposureType.mark;
    }
    throw FormatException('Unknown timeline exposure type: $value');
  }
}
