import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_style.dart';

bool _isGray(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  return red == green && green == blue;
}

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
            : TimelineCellExposureState.empty,
      ),
    );

    expect(find.text('○'), findsOneWidget);
  });

  testWidgets('shows held exposure marker', (tester) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.heldExposure
            : TimelineCellExposureState.empty,
      ),
    );

    expect(find.bySemanticsLabel('held exposure'), findsOneWidget);
  });

  testWidgets('blank start shows X with low-emphasis background', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.blankStart
            : TimelineCellExposureState.empty,
      ),
    );

    expect(find.text('X'), findsOneWidget);
    expect(find.bySemanticsLabel('blank exposure start'), findsOneWidget);
  });

  testWidgets('shows inbetween mark with priority over exposure marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.empty,
        hasMarkForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2,
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
            ? TimelineCellExposureState.blankHeld
            : TimelineCellExposureState.empty,
        hasMarkForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2,
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
            : TimelineCellExposureState.empty,
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
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.empty,
        hasMarkForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2,
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
            : TimelineCellExposureState.empty,
      ),
    );
    var cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0'));
    expect(find.descendant(of: cell, matching: find.text('○')), findsOneWidget);

    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.blankStart
            : TimelineCellExposureState.empty,
      ),
    );
    cell = find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0'));
    expect(find.descendant(of: cell, matching: find.text('X')), findsOneWidget);

    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.empty,
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
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.empty,
        hasMarkForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0,
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
      exposureState: TimelineCellExposureState.heldExposure,
      active: true,
      selected: false,
    );
    final blankStart = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: TimelineCellExposureState.blankStart,
      active: true,
      selected: false,
    );
    final blankHeld = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: TimelineCellExposureState.blankHeld,
      active: true,
      selected: false,
    );
    final selectedDrawing = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: TimelineCellExposureState.heldExposure,
      active: true,
      selected: true,
    );

    expect(heldDrawing.background, timelineDrawingHeldColor);
    expect(drawingStart.background, timelineDrawingStartColor);
    expect(drawingStart.background, heldDrawing.background);
    expect(drawingStart.border, timelineDrawingStartBorderColor);
    expect(_isGray(blankStart.background), isTrue);
    expect(blankStart.background, timelineBlankStartColor);
    expect(blankHeld.background, timelineBlankHeldColor);
    expect(blankStart.background, blankHeld.background);
    expect(blankStart.background, isNot(heldDrawing.background));
    expect(blankStart.background.toARGB32() & 0xff, lessThan(0xe0));
    expect(selectedDrawing.border, colorScheme.primary);
    expect(selectedDrawing.background, isNot(heldDrawing.background));
  });
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
  bool Function(Layer layer, int frameIndex)? hasMarkForLayer,
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
              (_, _) => TimelineCellExposureState.empty,
          hasMarkForLayer: hasMarkForLayer,
          frameNameForLayer: frameNameForLayer,
          onSelectLayer: onSelectLayer ?? (_) {},
          onSelectFrame: onSelectFrame ?? (_) {},
          onAddLayer: onAddLayer ?? () {},
          onToggleLayerVisibility: onToggleLayerVisibility ?? (_) {},
          onLayerOpacityChanged: onLayerOpacityChanged ?? (_, _) {},
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
