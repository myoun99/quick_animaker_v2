import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/timeline_mark.dart';
import 'package:quick_animaker_v2/src/models/timeline_mark_type.dart';

void main() {
  group('TimelineMark', () {
    test('inbetween constructor creates inbetween mark', () {
      expect(
        const TimelineMark.inbetween().type,
        TimelineMarkType.inbetween,
      );
    });

    test('round-trips JSON', () {
      const mark = TimelineMark.inbetween();

      expect(TimelineMark.fromJson(mark.toJson()), mark);
      expect(mark.toJson(), {'type': 'inbetween'});
    });

    test('invalid type throws clear FormatException', () {
      expect(
        () => TimelineMark.fromJson({'type': 'missing'}),
        throwsFormatException,
      );
    });

    test('implements equality and hashCode', () {
      const first = TimelineMark.inbetween();
      const second = TimelineMark.inbetween();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
