import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

void main() {
  group('TimelineGridMetrics', () {
    test('defaults match current LayerTimelineGrid behavior', () {
      const metrics = TimelineGridMetrics.defaults;

      expect(metrics.minimumVisibleFrameCells, 24);
      expect(metrics.layerControlsWidth, 220);
      expect(metrics.frameCellWidth, 48);
      expect(metrics.layerRowHeight, 52);
    });

    test('custom metrics can be created', () {
      const metrics = TimelineGridMetrics(
        minimumVisibleFrameCells: 12,
        layerControlsWidth: 180,
        frameCellWidth: 32,
        layerRowHeight: 44,
      );

      expect(metrics.minimumVisibleFrameCells, 12);
      expect(metrics.layerControlsWidth, 180);
      expect(metrics.frameCellWidth, 32);
      expect(metrics.layerRowHeight, 44);
    });
  });
}
