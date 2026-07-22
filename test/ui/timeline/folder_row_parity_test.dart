import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/folder_id.dart';
import 'package:quick_animaker_v2/src/models/layer_blend_mode.dart';
import 'package:quick_animaker_v2/src/models/layer_folder.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_folder_controls_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

/// R27 #23~#29: the folder row is a LAYER ROW that holds a folder —
/// same surface, same columns, its own opacity/blend, selectable, and
/// folding it with a member selected takes the selection.
void main() {
  LayerFolder folder({
    bool collapsed = false,
    double opacity = 1,
    LayerBlendMode blend = LayerBlendMode.normal,
  }) => LayerFolder(
    id: const FolderId('f'),
    name: 'F',
    collapsed: collapsed,
    opacity: opacity,
    blendMode: blend,
  );

  Widget host(
    LayerFolder value, {
    bool active = false,
    void Function(FolderId, double)? onOpacity,
    void Function(FolderId, LayerBlendMode)? onBlend,
    ValueChanged<FolderId>? onSelect,
  }) => MaterialApp(
    home: Scaffold(
      body: TimelineFolderControlsRow(
        folder: value,
        depth: 0,
        metrics: TimelineGridMetrics.defaults,
        active: active,
        onSelect: onSelect,
        onToggleCollapsed: (_) {},
        onToggleVisibility: (_) {},
        onToggleLanes: (_) {},
        onOpacityChanged: onOpacity,
        onOpacityChangeEnd: onOpacity,
        onBlendModeSelected: onBlend,
      ),
    ),
  );

  testWidgets('R27 #23/#29: the row carries the layer columns — fx, eye, '
      'opacity and blend, in the layer rows\' slots', (tester) async {
    await tester.pumpWidget(
      host(folder(), onOpacity: (_, _) {}, onBlend: (_, _) {}),
    );

    for (final key in [
      'timeline-folder-twirl-f',
      'timeline-folder-icon-f',
      'timeline-folder-lanes-f',
      'timeline-folder-visibility-f',
      'timeline-folder-opacity-f',
      'timeline-folder-blend-f',
    ]) {
      expect(
        find.byKey(ValueKey<String>(key)),
        findsOneWidget,
        reason: '$key must be present',
      );
    }
    // R27 #26: the fx column reads `fx`, exactly like a layer row's.
    expect(find.text('fx'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
  });

  testWidgets('R27 #24: the row selects, and the selected row wears the '
      'layer rows\' selection background', (tester) async {
    FolderId? selected;
    await tester.pumpWidget(host(folder(), onSelect: (id) => selected = id));
    await tester.tap(find.byKey(const ValueKey<String>('timeline-folder-row-f')));
    await tester.pump();
    expect(selected, const FolderId('f'));

    Color? rowColor(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('timeline-folder-row-f')),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color;
    }

    final resting = rowColor(tester);
    await tester.pumpWidget(host(folder(), active: true));
    expect(rowColor(tester), isNot(resting));
  });

  testWidgets('R27 #29: the blend flyout commits the folder\'s mode', (
    tester,
  ) async {
    LayerBlendMode? picked;
    await tester.pumpWidget(host(folder(), onBlend: (_, mode) => picked = mode));
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-folder-blend-f')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('timeline-folder-blend-option-multiply'),
      ),
    );
    await tester.pumpAndSettle();
    expect(picked, LayerBlendMode.multiply);
  });

  test('R27 #24: folding a folder whose member is active selects the '
      'FOLDER; selecting a layer releases it', () {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(s.dispose);
    s.createDrawingAtCurrentFrame();
    final layerId = s.activeLayer!.id;
    s.groupActiveLayerIntoFolder();
    final folderId = s.activeCutOrNull!.folders.single.id;
    expect(s.activeFolderId, isNull);

    s.toggleFolderCollapsed(folderId);
    expect(s.activeFolderId, folderId);

    s.selectLayer(layerId);
    expect(s.activeFolderId, isNull);
  });

  test('R27 #29: the folder blend round-trips through JSON and the '
      'session commit', () {
    final plain = folder();
    expect(plain.toJson().containsKey('blendMode'), isFalse);
    final blended = plain.copyWith(blendMode: LayerBlendMode.screen);
    expect(
      LayerFolder.fromJson(blended.toJson()).blendMode,
      LayerBlendMode.screen,
    );

    final s = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(s.dispose);
    s.createDrawingAtCurrentFrame();
    s.groupActiveLayerIntoFolder();
    final folderId = s.activeCutOrNull!.folders.single.id;
    s.setFolderBlendMode(folderId, LayerBlendMode.multiply);
    expect(
      s.activeCutOrNull!.folders.single.blendMode,
      LayerBlendMode.multiply,
    );
  });
}
