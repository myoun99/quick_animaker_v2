import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/storyboard_layer.dart';
import 'package:quick_animaker_v2/src/models/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/models/storyboard_panel_id.dart';

void main() {
  group('StoryboardLayer', () {
    test('empty has no panels', () {
      const layer = StoryboardLayer.empty();

      expect(layer.panels, isEmpty);
    });

    test('defensively stores an unmodifiable panels list', () {
      final panels = [_panel('panel-1')];
      final layer = StoryboardLayer(panels: panels);

      panels.clear();

      expect(layer.panels, [_panel('panel-1')]);
      expect(
        () => layer.panels.add(_panel('panel-2')),
        throwsUnsupportedError,
      );
    });

    test('copyWith replaces panels', () {
      final layer = StoryboardLayer(panels: [_panel('panel-1')]);
      final updated = layer.copyWith(panels: [_panel('panel-2')]);

      expect(updated.panels, [_panel('panel-2')]);
      expect(layer.panels, [_panel('panel-1')]);
    });

    test('uses panel list equality', () {
      final layer = StoryboardLayer(panels: [_panel('panel-1')]);
      final sameLayer = StoryboardLayer(panels: [_panel('panel-1')]);
      final differentLayer = StoryboardLayer(panels: [_panel('panel-2')]);

      expect(layer, sameLayer);
      expect(layer.hashCode, sameLayer.hashCode);
      expect(layer, isNot(differentLayer));
    });

    test('round-trips through JSON', () {
      final layer = StoryboardLayer(
        panels: [
          const StoryboardPanel(
            id: StoryboardPanelId('panel-1'),
            actionMemo: 'Action',
            dialogueMemo: 'Dialogue',
            note: 'Note',
          ),
        ],
      );

      final restored = StoryboardLayer.fromJson(layer.toJson());

      expect(restored, layer);
      expect(restored.toJson(), layer.toJson());
    });
  });
}

StoryboardPanel _panel(String id) {
  return StoryboardPanel(id: StoryboardPanelId(id));
}
