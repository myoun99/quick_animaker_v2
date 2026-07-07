import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/ui/timeline/property_lane_model.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_section_policy.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_section_runs.dart';

Layer _layer(String id, LayerKind kind) => Layer(
  id: LayerId(id),
  name: id,
  kind: kind,
  frames: const [],
  timeline: const {},
);

void main() {
  const metrics = TimelineGridMetrics(); // 52 rows, 22 collapsed strips

  group('timelineSectionRuns', () {
    test('groups consecutive rows by section; lanes join their layer', () {
      final camera = _layer('cam', LayerKind.camera);
      final rows = buildTimelineDisplayRows(
        layers: [
          _layer('cel-a', LayerKind.animation),
          _layer('se-1', LayerKind.se),
          _layer('se-2', LayerKind.se),
          camera,
        ],
        expandedLayerIds: {camera.id},
        lanesForLayer: (layer) => layer.kind == LayerKind.camera
            ? const [
                PropertyLaneRow(
                  laneId: 'position',
                  label: 'Position',
                  keyedFrames: {},
                ),
              ]
            : const [],
      );

      final runs = timelineSectionRuns(rows);

      expect(runs, [
        const TimelineSectionRun(
          section: TimelineSection.drawing,
          startRowIndex: 0,
          rowCount: 1,
          collapsed: false,
        ),
        const TimelineSectionRun(
          section: TimelineSection.se,
          startRowIndex: 1,
          rowCount: 2,
          collapsed: false,
        ),
        // Camera layer row + its expanded lane row.
        const TimelineSectionRun(
          section: TimelineSection.camera,
          startRowIndex: 3,
          rowCount: 2,
          collapsed: false,
        ),
      ]);
    });

    test('a collapsed section is a one-stub collapsed run with the slim '
        'extent', () {
      final rows = buildTimelineDisplayRows(
        layers: [
          _layer('cel-a', LayerKind.animation),
          _layer('se-1', LayerKind.se),
          _layer('cam', LayerKind.camera),
        ],
        expandedLayerIds: const {},
        lanesForLayer: (_) => const [],
        collapsedSections: const {TimelineSection.se},
      );

      final runs = timelineSectionRuns(rows);

      expect(runs, hasLength(3));
      expect(runs[1].section, TimelineSection.se);
      expect(runs[1].collapsed, isTrue);
      expect(runs[1].rowCount, 1);
      expect(
        timelineSectionRunExtent(runs[1], rows, metrics),
        metrics.collapsedSectionExtent,
      );
      expect(
        timelineSectionRunExtent(runs[2], rows, metrics),
        metrics.layerRowHeight,
      );
      expect(
        timelineDisplayRowsExtent(rows, metrics),
        metrics.layerRowHeight * 2 + metrics.collapsedSectionExtent,
      );
    });
  });
}
