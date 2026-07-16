/// What a timeline index records: a drawing (a cel block start with an
/// explicit length). Inbetween dots live INSIDE drawing entries as
/// `TimelineExposure.breakdownOffsets` — there is no standalone mark
/// entry anymore.
///
/// Emptiness is NOT a timeline entry: cells not covered by any drawing
/// block are simply uncovered, and the UI renders them with the timesheet
/// "X" glyph. (The legacy `blank` and `mark` entry types are migrated
/// away on load — a blank used to terminate a hold, which explicit
/// drawing lengths now express directly, and covered marks fold into
/// their block's offsets. [mark] survives only so legacy JSON parses.)
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
