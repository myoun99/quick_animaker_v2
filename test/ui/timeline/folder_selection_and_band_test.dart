import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/folder_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_folder.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/ui/timeline/property_lane_model.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_folder_aggregate_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

/// R28 #11/#12: the folder row stops behaving like a second kind of row.
///
/// #11 — selection is ONE thing (a folder and a layer could both read as
/// selected), and the folder's frame band carries the empty-cel grey as
/// the UNION of its members.
/// #12 — a folder header row carries its first member as a REPRESENTATIVE
/// layer, which is why the block outline drew on the folder instead of
/// the member; row lookups must skip folder rows the way they skip lanes.
void main() {
  Layer member(String id, {bool drawn = true}) => Layer(
    id: LayerId(id),
    name: id,
    kind: LayerKind.animation,
    folderId: const FolderId('f'),
    frames: [Frame(id: FrameId('$id-f0'), duration: 1, strokes: const [])],
    timeline: {0: TimelineExposure.drawing(FrameId('$id-f0'), length: 4)},
  );

  test('R28 #12: display rows put the folder header BEFORE its members, so '
      'a lookup that matches the representative layer lands on the folder', () {
    final layers = [member('a'), member('b')];
    final rows = buildTimelineDisplayRows(
      layers: layers,
      expandedLayerIds: const {},
      lanesForLayer: (_) => const [],
      folders: [LayerFolder(id: const FolderId('f'), name: 'F')],
    );

    final folderIndex = rows.indexWhere((row) => row.isFolder);
    expect(folderIndex, isNot(-1));
    // The header's representative IS the first member — the exact shape
    // that made the naive "first row whose layer.id matches" search wrong.
    expect(rows[folderIndex].layer.id, const LayerId('a'));

    final memberIndex = rows.indexWhere(
      (row) => !row.isFolder && !row.isLane && row.layer.id == const LayerId('a'),
    );
    expect(
      memberIndex,
      greaterThan(folderIndex),
      reason: 'the member row sits BELOW its folder header — a search that '
          'does not skip folder rows selects the wrong row offset',
    );
  });

  test('R28 #11: the folder header carries its subtree members, so the band '
      'can grey frames no member has drawn', () {
    final layers = [member('a'), member('b')];
    final rows = buildTimelineDisplayRows(
      layers: layers,
      expandedLayerIds: const {},
      lanesForLayer: (_) => const [],
      folders: [LayerFolder(id: const FolderId('f'), name: 'F')],
    );
    final header = rows.firstWhere((row) => row.isFolder);
    expect(
      header.members.map((layer) => layer.id).toList(),
      [const LayerId('a'), const LayerId('b')],
    );
  });

  testWidgets('R28 #11: the band greys a frame only when NO member has '
      'artwork there', (tester) async {
    final layers = [member('a'), member('b')];

    // Member A drew frames 0..1, member B drew frame 2. Frame 3 is empty
    // in the whole subtree — the only one that may grey.
    bool hasContent(Layer layer, int frameIndex) =>
        layer.id == const LayerId('a')
        ? frameIndex < 2
        : frameIndex == 2;

    final probed = <(String, int)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 40,
            child: TimelineFolderAggregateRow(
              aggregateRuns: const [(start: 0, endExclusive: 4)],
              frameStartIndex: 0,
              frameEndIndexExclusive: 4,
              leadingFrameSpacerWidth: 0,
              trailingFrameSpacerWidth: 0,
              metrics: TimelineGridMetrics.defaults,
              members: layers,
              memberHasContentAt: (layer, frameIndex) {
                probed.add((layer.id.value, frameIndex));
                return hasContent(layer, frameIndex);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The band asked about the union, not just one member — the "다른곳에서
    // 해당위치에 그림그려진 하얀 블록 존재하면 하얗게" rule.
    expect(probed.any((entry) => entry.$1 == 'a'), isTrue);
    expect(
      probed.any((entry) => entry.$1 == 'b'),
      isTrue,
      reason: 'frame 2 is drawn only by member B — the band must consult it '
          'before greying',
    );
    // Frame 3 is the empty one; every member gets asked about it.
    expect(probed.contains(('a', 3)), isTrue);
    expect(probed.contains(('b', 3)), isTrue);
  });
}
