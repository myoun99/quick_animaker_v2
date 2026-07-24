import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_cells_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

/// R26 #7 + R27 #3: every frame block prints ITS OWN length — one label
/// per block (never the glued run's total), bare number (no `f`), bold,
/// bottom-CENTRE of the block's last cell.
void main() {
  Layer drawingLayer(Map<int, TimelineExposure> timeline) => Layer(
    id: const LayerId('a-1'),
    name: 'A',
    kind: LayerKind.animation,
    frames: const [],
    timeline: timeline,
  );

  TimelineCellExposureState stateFor(Layer layer, int frameIndex) =>
      TimelineCellExposureState.uncovered;

  const cellWidth = 48.0;

  Widget harness({required Layer layer, bool showSeconds = false}) {
    return MaterialApp(
      home: Scaffold(
        body: Material(
          child: TimelineFrameCellsRow(
            layer: layer,
            active: true,
            playbackFrameCount: 12,
            frameStartIndex: 0,
            frameEndIndexExclusive: 12,
            leadingFrameSpacerWidth: 0,
            trailingFrameSpacerWidth: 0,
            metrics: const TimelineGridMetrics(
              frameCellWidth: cellWidth,
              layerRowHeight: 52,
            ),
            exposureStateForLayer: stateFor,
            onSelectLayer: (_) {},
            onSelectFrame: (_) {},
            showSeconds: showSeconds,
          ),
        ),
      ),
    );
  }

  testWidgets('a block prints its frame count as a bare bold number', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        layer: drawingLayer({
          2: const TimelineExposure.drawing(FrameId('f1'), length: 6),
        }),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-run-duration-a-1-2')),
      findsOneWidget,
    );
    expect(find.text('6'), findsOneWidget);
    expect(find.text('6f'), findsNothing);

    final label = tester.widget<Text>(find.text('6'));
    expect(label.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('the seconds toggle switches the label to seconds+frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        layer: drawingLayer({
          2: const TimelineExposure.drawing(FrameId('f1'), length: 6),
        }),
        showSeconds: true,
      ),
    );
    // 6 frames at the default 24-base: under a second.
    expect(find.text('0+06'), findsOneWidget);
    expect(find.text('6'), findsNothing);
  });

  testWidgets('R27 #3: GLUED blocks each label their own length', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        layer: drawingLayer({
          // Two blocks that touch — the glued run totals 5, which must
          // NOT be what shows.
          0: const TimelineExposure.drawing(FrameId('f1'), length: 2),
          2: const TimelineExposure.drawing(FrameId('f2'), length: 3),
        }),
      ),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('R27 #3: the label centres on the block LAST cell', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        layer: drawingLayer({
          0: const TimelineExposure.drawing(FrameId('f1'), length: 4),
        }),
      ),
    );
    // Block spans frames 0..4 → last cell is [144, 192), centre 168.
    final centre = tester.getCenter(find.text('4'));
    expect(centre.dx, closeTo(168, 1.5));

    // Bottom-anchored inside the row (52 tall, 1px padding).
    final bottom = tester.getRect(find.text('4')).bottom;
    expect(bottom, greaterThan(40));
  });

  testWidgets('separate blocks label separately; SE rows stay clean', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        layer: drawingLayer({
          0: const TimelineExposure.drawing(FrameId('f1'), length: 2),
          4: const TimelineExposure.drawing(FrameId('f2'), length: 3),
        }),
      ),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(
      harness(
        layer: Layer(
          id: const LayerId('se-1'),
          name: 'S1',
          kind: LayerKind.se,
          frames: const [],
          timeline: {
            0: const TimelineExposure.drawing(FrameId('f1'), length: 4),
          },
        ),
      ),
    );
    expect(
      find.text('4'),
      findsNothing,
      reason:
          'SE sheet rows carry dialogue and waveforms, not exposure durations',
    );
  });
}
