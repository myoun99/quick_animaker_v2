import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_preset.dart';
import 'package:quick_animaker_v2/src/models/brush_preset_id.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_preset_reorder.dart';

BrushPreset _preset(String id, {String? group}) {
  return BrushPreset(
    id: BrushPresetId(id),
    name: id,
    group: group,
    settings: BrushSettings(size: 5),
  );
}

List<String> _ids(List<BrushPreset> presets) => [
  for (final preset in presets) preset.id.value,
];

void main() {
  final library = [
    _preset('a'),
    _preset('b'),
    _preset('w1', group: 'Watercolor'),
    _preset('w2', group: 'Watercolor'),
    _preset('w3', group: 'Watercolor'),
  ];

  test('moves before an anchor within the same group', () {
    final moved = moveBrushPresetInLibrary(
      presets: library,
      movedId: const BrushPresetId('w3'),
      targetGroup: 'Watercolor',
      insertBeforeId: const BrushPresetId('w1'),
    );

    expect(_ids(moved), ['a', 'b', 'w3', 'w1', 'w2']);
    expect(moved[2].group, 'Watercolor');
  });

  test('appends at the end of the target group without an anchor', () {
    final moved = moveBrushPresetInLibrary(
      presets: library,
      movedId: const BrushPresetId('a'),
      targetGroup: 'Watercolor',
    );

    expect(_ids(moved), ['b', 'w1', 'w2', 'w3', 'a']);
    expect(moved.last.group, 'Watercolor');
  });

  test('moving into the default group clears the group field', () {
    final moved = moveBrushPresetInLibrary(
      presets: library,
      movedId: const BrushPresetId('w2'),
      targetGroup: null,
      insertBeforeId: const BrushPresetId('b'),
    );

    expect(_ids(moved), ['a', 'w2', 'b', 'w1', 'w3']);
    expect(moved[1].group, isNull);
  });

  test('an unknown moved id returns the library unchanged', () {
    final moved = moveBrushPresetInLibrary(
      presets: library,
      movedId: const BrushPresetId('missing'),
      targetGroup: null,
    );

    expect(moved, same(library));
  });

  test('a missing anchor appends at the end of the library', () {
    final moved = moveBrushPresetInLibrary(
      presets: library,
      movedId: const BrushPresetId('a'),
      targetGroup: 'Watercolor',
      insertBeforeId: const BrushPresetId('missing'),
    );

    expect(_ids(moved), ['b', 'w1', 'w2', 'w3', 'a']);
  });
}
