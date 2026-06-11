import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/storyboard_layer.dart';
import 'package:quick_animaker_v2/src/models/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/models/storyboard_panel_id.dart';

void main() {
  group('Cut storyboardLayer', () {
    test('defaults to empty storyboard layer', () {
      final cut = _cut();

      expect(cut.storyboardLayer, const StoryboardLayer.empty());
    });

    test('copyWith updates storyboardLayer and preserves other fields', () {
      final cut = _cut();
      final storyboardLayer = _storyboardLayer();

      final updated = cut.copyWith(storyboardLayer: storyboardLayer);

      expect(updated.storyboardLayer, storyboardLayer);
      expect(updated.id, cut.id);
      expect(updated.name, cut.name);
      expect(updated.layers, cut.layers);
      expect(updated.duration, cut.duration);
      expect(updated.canvasSize, cut.canvasSize);
      expect(updated.metadata, cut.metadata);
    });

    test('equality includes storyboardLayer', () {
      final cut = _cut();
      final cutWithStoryboardLayer = cut.copyWith(
        storyboardLayer: _storyboardLayer(),
      );

      expect(cutWithStoryboardLayer, isNot(cut));
      expect(
        cutWithStoryboardLayer,
        _cut().copyWith(storyboardLayer: _storyboardLayer()),
      );
    });

    test('round-trips storyboardLayer through JSON', () {
      final cut = _cut().copyWith(storyboardLayer: _storyboardLayer());

      final restored = Cut.fromJson(cut.toJson());

      expect(restored, cut);
      expect(restored.storyboardLayer, cut.storyboardLayer);
      expect(restored.toJson(), cut.toJson());
    });

    test('old JSON without storyboardLayer loads with empty storyboard layer', () {
      final json = _cut().toJson()..remove('storyboardLayer');

      final restored = Cut.fromJson(json);

      expect(restored.storyboardLayer, const StoryboardLayer.empty());
    });
  });
}

Cut _cut() {
  return Cut(
    id: const CutId('cut-1'),
    name: 'Cut 1',
    layers: const [],
    duration: 24,
    canvasSize: const CanvasSize(width: 1920, height: 1080),
  );
}

StoryboardLayer _storyboardLayer() {
  return StoryboardLayer(
    panels: const [
      StoryboardPanel(
        id: StoryboardPanelId('panel-1'),
        actionMemo: 'Run to the door.',
        dialogueMemo: 'A: Wait!',
        note: 'Check expression.',
      ),
    ],
  );
}
