import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/timesheet_info.dart';

void main() {
  group('TimesheetInfo', () {
    test('serializes scene and hidden header boxes round-trip', () {
      const info = TimesheetInfo(
        title: 'YOASOBI',
        episode: 'MV',
        scene: 'S12',
        artist: 'MYOUN',
        hiddenFields: {TimesheetHeaderField.scene, TimesheetHeaderField.sheet},
      );

      final restored = TimesheetInfo.fromJson(info.toJson());
      expect(restored, info);
      expect(restored.scene, 'S12');
      expect(restored.hiddenFields, {
        TimesheetHeaderField.scene,
        TimesheetHeaderField.sheet,
      });
    });

    test('older files without the new keys load with everything visible', () {
      final restored = TimesheetInfo.fromJson({
        'title': 'YOASOBI',
        'episode': 'MV',
        'artist': 'MYOUN',
      });

      expect(restored.scene, '');
      expect(restored.hiddenFields, isEmpty);
      expect(restored.visibleFields, TimesheetHeaderField.values);
    });

    test('unknown hidden-field names from newer files drop silently', () {
      final restored = TimesheetInfo.fromJson({
        'hiddenFields': ['scene', 'holographic-box'],
      });

      expect(restored.hiddenFields, {TimesheetHeaderField.scene});
    });

    test('visibleFields keeps the printing order minus hidden boxes', () {
      const info = TimesheetInfo(hiddenFields: {TimesheetHeaderField.episode});

      expect(info.visibleFields, const [
        TimesheetHeaderField.title,
        TimesheetHeaderField.scene,
        TimesheetHeaderField.cut,
        TimesheetHeaderField.time,
        TimesheetHeaderField.name,
        TimesheetHeaderField.sheet,
      ]);
    });
  });
}
