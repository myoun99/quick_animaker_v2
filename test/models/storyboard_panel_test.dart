import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/models/storyboard_panel_id.dart';

void main() {
  group('StoryboardPanel', () {
    test('defaults text fields to empty', () {
      const panel = StoryboardPanel(id: StoryboardPanelId('panel-1'));

      expect(panel.actionMemo, '');
      expect(panel.dialogueMemo, '');
      expect(panel.note, '');
    });

    test('copyWith updates text fields without changing id', () {
      const panel = StoryboardPanel(id: StoryboardPanelId('panel-1'));

      final updated = panel.copyWith(
        actionMemo: 'Run to the door.',
        dialogueMemo: 'A: Wait!',
        note: 'Check expression.',
      );

      expect(updated.id, panel.id);
      expect(updated.actionMemo, 'Run to the door.');
      expect(updated.dialogueMemo, 'A: Wait!');
      expect(updated.note, 'Check expression.');
    });

    test('uses all fields for equality', () {
      const panel = StoryboardPanel(
        id: StoryboardPanelId('panel-1'),
        actionMemo: 'Action',
        dialogueMemo: 'Dialogue',
        note: 'Note',
      );
      const samePanel = StoryboardPanel(
        id: StoryboardPanelId('panel-1'),
        actionMemo: 'Action',
        dialogueMemo: 'Dialogue',
        note: 'Note',
      );

      expect(panel, samePanel);
      expect(panel.hashCode, samePanel.hashCode);
      expect(panel.copyWith(actionMemo: 'Different'), isNot(panel));
      expect(panel.copyWith(dialogueMemo: 'Different'), isNot(panel));
      expect(panel.copyWith(note: 'Different'), isNot(panel));
    });

    test('round-trips through JSON', () {
      const panel = StoryboardPanel(
        id: StoryboardPanelId('panel-1'),
        actionMemo: 'Run to the door.',
        dialogueMemo: 'A: Wait!',
        note: 'Check expression.',
      );

      final restored = StoryboardPanel.fromJson(panel.toJson());

      expect(restored, panel);
      expect(restored.toJson(), panel.toJson());
    });
  });
}
