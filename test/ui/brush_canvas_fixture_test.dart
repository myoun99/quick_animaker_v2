import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_fixture.dart';

void main() {
  test('fixture creates three shared-context brush frame keys', () {
    final frameKeys = BrushCanvasFixture.createFrameKeys();

    expect(frameKeys, hasLength(3));
    expect(frameKeys.map((key) => key.frameId.value), [
      'frame-1',
      'frame-2',
      'frame-3',
    ]);

    for (final key in frameKeys) {
      expect(key.projectId, BrushCanvasFixture.projectId);
      expect(key.trackId, BrushCanvasFixture.trackId);
      expect(key.cutId, BrushCanvasFixture.cutId);
      expect(key.layerId, BrushCanvasFixture.layerId);
    }
  });
}
