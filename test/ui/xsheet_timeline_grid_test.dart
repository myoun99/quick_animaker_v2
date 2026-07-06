import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_mark.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_style.dart';

void main() {
  testWidgets('renders integrated layer controls in headers', (tester) async {
    await tester.pumpWidget(_grid());

    expect(find.text('Layer 1'), findsOneWidget);
    expect(find.text('Layer 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('xsheet-add-layer-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-layer-visibility-layer-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-layer-opacity-layer-1')),
      findsOneWidget,
    );
  });

  testWidgets('does not render a dedicated add layer grid column', (
    tester,
  ) async {
    await tester.pumpWidget(_grid());

    expect(
      find.byKey(const ValueKey<String>('xsheet-add-layer-button')),
      findsNothing,
    );
  });

  testWidgets('visibility button calls callback', (tester) async {
    LayerId? toggledLayerId;

    await tester.pumpWidget(
      _grid(onToggleLayerVisibility: (layerId) => toggledLayerId = layerId),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-layer-visibility-layer-2')),
    );

    expect(toggledLayerId, const LayerId('layer-2'));
  });

  testWidgets('opacity control calls callback', (tester) async {
    LayerId? changedLayerId;
    double? changedOpacity;

    await tester.pumpWidget(
      _grid(
        onLayerOpacityChanged: (layerId, opacity) {
          changedLayerId = layerId;
          changedOpacity = opacity;
        },
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('xsheet-layer-opacity-layer-1')),
      const Offset(-30, 0),
    );

    expect(changedLayerId, const LayerId('layer-1'));
    expect(changedOpacity, isNotNull);
  });

  testWidgets('timesheet toggle calls callback from the header', (
    tester,
  ) async {
    LayerId? toggledLayerId;

    await tester.pumpWidget(
      _grid(onToggleLayerTimesheet: (layerId) => toggledLayerId = layerId),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-layer-timesheet-layer-2')),
    );

    expect(toggledLayerId, const LayerId('layer-2'));
  });

  testWidgets('mark chip popup reports the selected mark', (tester) async {
    LayerId? markedLayerId;
    LayerMark? selectedMark;

    await tester.pumpWidget(
      _grid(
        onLayerMarkSelected: (layerId, mark) {
          markedLayerId = layerId;
          selectedMark = mark;
        },
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-layer-mark-layer-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('layer-mark-option-red')),
    );
    await tester.pumpAndSettle();

    expect(markedLayerId, const LayerId('layer-1'));
    expect(selectedMark, LayerMark.red);
  });

  testWidgets('renders frame rows and cells', (tester) async {
    await tester.pumpWidget(_grid());

    expect(
      find.byKey(const ValueKey<String>('xsheet-frame-row-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-2-0')),
      findsOneWidget,
    );
  });

  testWidgets('selecting a cell selects layer and frame', (tester) async {
    LayerId? selectedLayerId;
    int? selectedFrameIndex;

    await tester.pumpWidget(
      _grid(
        onSelectLayer: (layerId) => selectedLayerId = layerId,
        onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-3')),
    );

    expect(selectedLayerId, const LayerId('layer-1'));
    expect(selectedFrameIndex, 3);
  });

  testWidgets('selects layer from header', (tester) async {
    LayerId? selectedLayerId;

    await tester.pumpWidget(
      _grid(onSelectLayer: (layerId) => selectedLayerId = layerId),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-layer-name-layer-2')),
    );

    expect(selectedLayerId, const LayerId('layer-2'));
  });

  testWidgets('shows drawing marker', (tester) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.uncovered,
      ),
    );

    expect(find.text('○'), findsOneWidget);
  });

  testWidgets('shows held exposure marker', (tester) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.held
            : TimelineCellExposureState.uncovered,
      ),
    );

    expect(find.bySemanticsLabel('held exposure'), findsOneWidget);
  });

  testWidgets('only the first cell of an empty run shows the timesheet X', (
    tester,
  ) async {
    await tester.pumpWidget(_grid());

    final runStart = find.byKey(
      const ValueKey<String>('xsheet-cell-layer-2-0'),
    );
    final runBody = find.byKey(const ValueKey<String>('xsheet-cell-layer-2-2'));
    expect(
      find.descendant(of: runStart, matching: find.text('X')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: runBody, matching: find.text('X')),
      findsNothing,
    );
  });

  testWidgets('shows inbetween mark with priority over exposure marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.markHeld
            : TimelineCellExposureState.uncovered,
      ),
    );

    final cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-2-2'));
    expect(find.descendant(of: cell, matching: find.text('●')), findsOneWidget);
    expect(find.descendant(of: cell, matching: find.text('○')), findsNothing);
    expect(find.bySemanticsLabel('inbetween mark'), findsOneWidget);
  });

  testWidgets('shows inbetween mark on blank held cell', (tester) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.markUncovered
            : TimelineCellExposureState.uncovered,
      ),
    );

    expect(find.text('●'), findsOneWidget);
    expect(find.bySemanticsLabel('inbetween mark'), findsOneWidget);
  });

  testWidgets('empty cells stay blank', (tester) async {
    await tester.pumpWidget(_grid());

    expect(find.text('○'), findsNothing);
    expect(find.bySemanticsLabel('held exposure'), findsNothing);
  });

  testWidgets('current frame row uses plain text', (tester) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 3));

    expect(
      find.byKey(const ValueKey<String>('xsheet-frame-row-3')),
      findsOneWidget,
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('▶ 4'), findsNothing);
  });

  testWidgets('named drawing start displays name and mark has priority', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.uncovered,
        frameNameForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? 'A1'
            : null,
      ),
    );

    final cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-2-2'));
    expect(
      find.descendant(of: cell, matching: find.text('A1')),
      findsOneWidget,
    );
    expect(find.descendant(of: cell, matching: find.text('○')), findsNothing);

    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.markHeld
            : TimelineCellExposureState.uncovered,
        frameNameForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? 'A1'
            : null,
      ),
    );

    expect(find.descendant(of: cell, matching: find.text('●')), findsOneWidget);
    expect(find.descendant(of: cell, matching: find.text('A1')), findsNothing);
  });

  testWidgets('marks only the active current cell as selected', (tester) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 2));

    expect(
      find.byKey(const ValueKey<String>('xsheet-selected-cell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-selected-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-2-2')),
      findsOneWidget,
    );
  });

  testWidgets('selected cell preserves symbol display priority', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.uncovered,
      ),
    );
    var cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0'));
    expect(find.descendant(of: cell, matching: find.text('○')), findsOneWidget);

    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.uncovered
            : TimelineCellExposureState.uncovered,
      ),
    );
    cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0'));
    expect(find.descendant(of: cell, matching: find.text('X')), findsOneWidget);

    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.uncovered,
        frameNameForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? 'A1'
            : null,
      ),
    );
    cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0'));
    expect(
      find.descendant(of: cell, matching: find.text('A1')),
      findsOneWidget,
    );
    expect(find.descendant(of: cell, matching: find.text('○')), findsNothing);

    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.markHeld
            : TimelineCellExposureState.uncovered,
        frameNameForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? 'A1'
            : null,
      ),
    );
    cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0'));
    expect(find.descendant(of: cell, matching: find.text('●')), findsOneWidget);
    expect(find.descendant(of: cell, matching: find.text('A1')), findsNothing);
    expect(find.descendant(of: cell, matching: find.text('○')), findsNothing);
  });

  testWidgets('held exposure run renders as one vertical block', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        frameCount: 4,
        exposureStateForLayer: (layer, frameIndex) {
          if (layer.id != const LayerId('layer-1')) {
            return TimelineCellExposureState.uncovered;
          }
          return switch (frameIndex) {
            0 => TimelineCellExposureState.drawingStart,
            1 || 2 => TimelineCellExposureState.held,
            _ => TimelineCellExposureState.uncovered,
          };
        },
      ),
    );

    final startRadius =
        _cellDecoration(tester, 'xsheet-cell-layer-1-0').borderRadius!
            as BorderRadius;
    expect(startRadius.topLeft, const Radius.circular(6));
    expect(startRadius.bottomLeft, Radius.zero);

    final midRadius =
        _cellDecoration(tester, 'xsheet-cell-layer-1-1').borderRadius
            as BorderRadius?;
    expect(midRadius, BorderRadius.zero);

    final endRadius =
        _cellDecoration(tester, 'xsheet-cell-layer-1-2').borderRadius!
            as BorderRadius;
    expect(endRadius.topLeft, Radius.zero);
    expect(endRadius.bottomLeft, const Radius.circular(6));
  });

  testWidgets('shows the shared playhead row tint at the current frame', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 2));

    expect(
      find.byKey(const ValueKey<String>('timeline-playhead-column')),
      findsOneWidget,
    );
  });

  testWidgets('shows cut-end boundary lines past the playback range', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(frameCount: 12));

    expect(
      find.byKey(const ValueKey<String>('timeline-cut-end-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cut-end-boundary-ruler')),
      findsOneWidget,
    );
  });

  testWidgets('outlines the selected exposure run', (tester) async {
    await tester.pumpWidget(
      _grid(
        frameCount: 4,
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.uncovered,
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>(
          'timeline-selected-exposure-range-outline-layer-1',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('virtualizes long cuts to the visible frame window', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(frameCount: 500));

    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-499')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-frame-rail-trailing-spacer')),
      findsOneWidget,
    );
  });

  testWidgets('dims frames beyond the playback range like the timeline', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(frameCount: 12));

    // The visible window extends to the shared 24-frame minimum, so frames
    // past the 12-frame playback range render dimmed (on the inactive layer
    // to keep the active-layer tint out of the comparison).
    final inside = _cellDecoration(tester, 'xsheet-cell-layer-2-0').color;
    final outside = _cellDecoration(tester, 'xsheet-cell-layer-2-13').color;
    expect(outside, isNot(inside));
  });

  testWidgets('dragging the frame rail scrubs the current frame', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(_grid(onSelectFrame: selected.add));

    await tester.drag(
      find.byKey(const ValueKey<String>('xsheet-frame-rail-scrub-area')),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();

    expect(selected, isNotEmpty);
  });

  test('cell style keeps drawing cells neutral and blank cells muted', () {
    const colorScheme = ColorScheme.light();

    final drawingStart = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: TimelineCellExposureState.drawingStart,
      active: true,
      selected: false,
    );
    final heldDrawing = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: TimelineCellExposureState.held,
      active: true,
      selected: false,
    );
    final uncovered = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: TimelineCellExposureState.uncovered,
      active: true,
      selected: false,
    );
    final selectedDrawing = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: TimelineCellExposureState.held,
      active: true,
      selected: true,
    );

    expect(heldDrawing.background, timelineDrawingHeldColor);
    expect(drawingStart.background, timelineDrawingStartColor);
    expect(drawingStart.background, heldDrawing.background);
    expect(drawingStart.border, timelineDrawingStartBorderColor);
    expect(uncovered.background, isNot(heldDrawing.background));
    expect(selectedDrawing.border, timelineSelectedFrameBorderColor);
    expect(selectedDrawing.background, isNot(heldDrawing.background));
  });
}

BoxDecoration _cellDecoration(WidgetTester tester, String key) {
  final inkWell = tester.widget<InkWell>(find.byKey(ValueKey<String>(key)));
  final container = inkWell.child! as Container;
  return container.decoration! as BoxDecoration;
}

Widget _grid({
  int currentFrameIndex = 0,
  int frameCount = 12,
  TimelineCellExposureState Function(Layer layer, int frameIndex)?
  exposureStateForLayer,
  ValueChanged<LayerId>? onSelectLayer,
  ValueChanged<int>? onSelectFrame,
  VoidCallback? onAddLayer,
  ValueChanged<LayerId>? onToggleLayerVisibility,
  void Function(LayerId layerId, double opacity)? onLayerOpacityChanged,
  ValueChanged<LayerId>? onToggleLayerTimesheet,
  void Function(LayerId layerId, LayerMark mark)? onLayerMarkSelected,
  String? Function(Layer layer, int frameIndex)? frameNameForLayer,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 600,
        child: XSheetTimelineGrid(
          layers: _layers,
          activeLayerId: const LayerId('layer-1'),
          currentFrameIndex: currentFrameIndex,
          frameCount: frameCount,
          exposureStateForLayer:
              exposureStateForLayer ??
              (_, _) => TimelineCellExposureState.uncovered,
          frameNameForLayer: frameNameForLayer,
          onSelectLayer: onSelectLayer ?? (_) {},
          onSelectFrame: onSelectFrame ?? (_) {},
          onAddLayer: onAddLayer ?? () {},
          onToggleLayerVisibility: onToggleLayerVisibility ?? (_) {},
          onLayerOpacityChanged: onLayerOpacityChanged ?? (_, _) {},
          onToggleLayerTimesheet: onToggleLayerTimesheet ?? (_) {},
          onLayerMarkSelected: onLayerMarkSelected ?? (_, _) {},
        ),
      ),
    ),
  );
}

final _layers = [
  Layer(
    id: const LayerId('layer-1'),
    name: 'Layer 1',
    frames: [
      Frame(id: const FrameId('frame-1'), duration: 1, strokes: const []),
    ],
  ),
  Layer(
    id: const LayerId('layer-2'),
    name: 'Layer 2',
    opacity: 0.5,
    frames: [
      Frame(id: const FrameId('frame-2'), duration: 1, strokes: const []),
    ],
  ),
];
