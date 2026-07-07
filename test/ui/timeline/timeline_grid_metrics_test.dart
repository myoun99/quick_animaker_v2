import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

void main() {
  group('TimelineGridMetrics', () {
    test('defaults match current LayerTimelineGrid behavior', () {
      const metrics = TimelineGridMetrics.defaults;

      expect(metrics.minimumVisibleFrameCells, 24);
      expect(metrics.layerControlsWidth, 264);
      expect(metrics.frameCellWidth, 48);
      expect(metrics.layerRowHeight, 52);
      expect(metrics.verticalScrollbarWidth, 14);
    });

    test('copyWith rescales only the frame cell extent', () {
      final zoomed = TimelineGridMetrics.defaults.copyWith(frameCellWidth: 24);

      expect(zoomed.frameCellWidth, 24);
      expect(
        zoomed.layerRowHeight,
        TimelineGridMetrics.defaults.layerRowHeight,
      );
      expect(
        zoomed.layerControlsWidth,
        TimelineGridMetrics.defaults.layerControlsWidth,
      );
    });

    test('frame label cadence adapts to the cell width', () {
      int cadenceAt(double width) =>
          TimelineGridMetrics(frameCellWidth: width).frameLabelEveryFrames;

      expect(cadenceAt(48), 1);
      expect(cadenceAt(28), 1);
      expect(cadenceAt(24), 2);
      expect(cadenceAt(8), 6);
      expect(cadenceAt(4), 12);
      expect(cadenceAt(2), 24);
    });

    test('custom metrics can be created', () {
      const metrics = TimelineGridMetrics(
        minimumVisibleFrameCells: 12,
        layerControlsWidth: 180,
        frameCellWidth: 32,
        layerRowHeight: 44,
        verticalScrollbarWidth: 12,
      );

      expect(metrics.minimumVisibleFrameCells, 12);
      expect(metrics.layerControlsWidth, 180);
      expect(metrics.frameCellWidth, 32);
      expect(metrics.layerRowHeight, 44);
      expect(metrics.verticalScrollbarWidth, 12);
    });
  });
}
