import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/folder_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_folder.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/ui/timeline/property_lane_model.dart';

/// Folder rows in the timeline display list (L5): the header sits above
/// its first member, depth drives the tree indent, collapsing swallows
/// member rows (the active layer stays), and the header's frame band is
/// the members' exposure UNION (the TVP-latest aggregate block).
void main() {
  Layer layer(
    String id, {
    String? folder,
    Map<int, TimelineExposure> timeline = const {},
  }) => Layer(
    id: LayerId(id),
    name: id,
    frames: const [],
    timeline: timeline,
    folderId: folder == null ? null : FolderId(folder),
  );

  test('folder headers sit above their first member with tree depths; '
      'members carry their nesting depth', () {
    final rows = buildTimelineDisplayRows(
      layers: [
        layer('top'),
        layer('a', folder: 'outer'),
        layer('b', folder: 'inner'),
      ],
      expandedLayerIds: const {},
      lanesForLayer: (_) => const [],
      folders: [
        LayerFolder(id: const FolderId('outer'), name: 'O'),
        LayerFolder(
          id: const FolderId('inner'),
          name: 'I',
          parentId: const FolderId('outer'),
        ),
      ],
    );

    expect(rows.map((row) => row.isFolder ? 'F:${row.folder!.name}' : row.layer.id.value),
        ['top', 'F:O', 'a', 'F:I', 'b']);
    expect(rows[1].depth, 0);
    expect(rows[2].depth, 1, reason: 'outer member indents one level');
    expect(rows[3].depth, 1, reason: 'nested folder header indents');
    expect(rows[4].depth, 2, reason: 'nested member indents two levels');
  });

  test('a collapsed folder keeps its header and swallows member rows — '
      'except the ACTIVE layer', () {
    final folders = [
      LayerFolder(id: const FolderId('f'), name: 'F', collapsed: true),
    ];
    final rows = buildTimelineDisplayRows(
      layers: [layer('a', folder: 'f'), layer('b', folder: 'f')],
      expandedLayerIds: const {},
      lanesForLayer: (_) => const [],
      folders: folders,
    );
    expect(rows.length, 1);
    expect(rows.single.isFolder, isTrue);

    final withActive = buildTimelineDisplayRows(
      layers: [layer('a', folder: 'f'), layer('b', folder: 'f')],
      expandedLayerIds: const {},
      lanesForLayer: (_) => const [],
      folders: folders,
      activeLayerId: const LayerId('b'),
    );
    expect(
      withActive.map(
        (row) => row.isFolder ? 'F' : row.layer.id.value,
      ),
      ['F', 'b'],
      reason: 'collapsing never hides the layer being edited',
    );
  });

  test('the aggregate band is the subtree exposure UNION, holds merged', () {
    final rows = buildTimelineDisplayRows(
      layers: [
        layer(
          'a',
          folder: 'f',
          timeline: {
            0: TimelineExposure.drawing(const FrameId('x'), length: 3),
          },
        ),
        layer(
          'b',
          folder: 'f',
          timeline: {
            2: TimelineExposure.drawing(const FrameId('y'), length: 2),
            8: TimelineExposure.drawing(const FrameId('z'), length: 1),
          },
        ),
      ],
      expandedLayerIds: const {},
      lanesForLayer: (_) => const [],
      folders: [LayerFolder(id: const FolderId('f'), name: 'F')],
    );
    expect(rows.first.isFolder, isTrue);
    expect(rows.first.aggregateRuns, [
      (start: 0, endExclusive: 4),
      (start: 8, endExclusive: 9),
    ]);
  });
}
