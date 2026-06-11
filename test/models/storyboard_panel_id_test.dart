import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/storyboard_panel_id.dart';

void main() {
  group('StoryboardPanelId', () {
    test('uses value equality', () {
      const id = StoryboardPanelId('panel-1');
      const sameId = StoryboardPanelId('panel-1');
      const differentId = StoryboardPanelId('panel-2');

      expect(id, sameId);
      expect(id.hashCode, sameId.hashCode);
      expect(id, isNot(differentId));
    });

    test('round-trips through JSON', () {
      const id = StoryboardPanelId('panel-1');

      expect(StoryboardPanelId.fromJson(id.toJson()), id);
    });
  });
}
