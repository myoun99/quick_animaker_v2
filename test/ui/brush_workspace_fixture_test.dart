import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_fixture.dart';

void main() {
  test('fixture creates three shared-context brush frame keys', () {
    final frameKeys = BrushWorkspaceFixture.createFrameKeys();

    expect(frameKeys, hasLength(3));
    expect(frameKeys.map((key) => key.frameId.value), [
      'frame-1',
      'frame-2',
      'frame-3',
    ]);

    for (final key in frameKeys) {
      expect(key.projectId, BrushWorkspaceFixture.projectId);
      expect(key.trackId, BrushWorkspaceFixture.trackId);
      expect(key.cutId, BrushWorkspaceFixture.cutId);
      expect(key.layerId, BrushWorkspaceFixture.layerId);
    }
  });
}
