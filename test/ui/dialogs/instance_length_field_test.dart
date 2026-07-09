import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/dialogs/instance_length_field.dart';

void main() {
  group('parseInstanceLength', () {
    test('seconds+komas parses s+k and bare koma counts', () {
      const format = InstanceLengthFormat.secondsPlusKomas;
      expect(parseInstanceLength('1+12', format, fps: 24), 36);
      expect(parseInstanceLength('0+6', format, fps: 24), 6);
      expect(parseInstanceLength('2+0', format, fps: 12), 24);
      expect(parseInstanceLength(' 1+0 ', format, fps: 24), 24);
      // A bare integer means komas.
      expect(parseInstanceLength('12', format, fps: 24), 12);
      // Invalid or sub-frame lengths are rejected.
      expect(parseInstanceLength('0+0', format, fps: 24), isNull);
      expect(parseInstanceLength('', format, fps: 24), isNull);
      expect(parseInstanceLength('1+', format, fps: 24), isNull);
      expect(parseInstanceLength('abc', format, fps: 24), isNull);
      expect(parseInstanceLength('12f', format, fps: 24), isNull);
    });

    test('frames parses a count with an optional trailing f', () {
      const format = InstanceLengthFormat.frames;
      expect(parseInstanceLength('36', format, fps: 24), 36);
      expect(parseInstanceLength('36f', format, fps: 24), 36);
      expect(parseInstanceLength('1', format, fps: 24), 1);
      expect(parseInstanceLength('0', format, fps: 24), isNull);
      expect(parseInstanceLength('1+12', format, fps: 24), isNull);
      expect(parseInstanceLength('f', format, fps: 24), isNull);
    });
  });

  group('formatInstanceLength', () {
    test('round-trips both notations', () {
      expect(
        formatInstanceLength(
          36,
          InstanceLengthFormat.secondsPlusKomas,
          fps: 24,
        ),
        '1+12',
      );
      expect(
        formatInstanceLength(6, InstanceLengthFormat.secondsPlusKomas, fps: 24),
        '0+6',
      );
      expect(
        formatInstanceLength(36, InstanceLengthFormat.frames, fps: 24),
        '36f',
      );
    });
  });
}
