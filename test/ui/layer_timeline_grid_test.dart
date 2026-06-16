import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_grid.dart';
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
  testWidgets(
    'vertical scrollbar does not read unsettled scroll metrics on first pump',
    (tester) async {
      final layers = List<Layer>.generate(
        12,
        (index) => _layer(id: 'layer-${index + 1}', name: 'Layer ${index + 1}'),
      );

      await tester.pumpWidget(_grid(layers: layers, frameCount: 40));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('timeline-vertical-scrollbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-vertical-scrollbar-thumb')),
        findsOneWidget,
      );
    },
  );

  testWidgets('sticky frame ruler lays out full content width without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_grid(frameCount: 96));

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-ruler')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-row')),
      findsOneWidget,
    );
  });

  testWidgets('renders fixed layer controls rail and frame scroll structure', (
    tester,
  ) async {
    await tester.pumpWidget(_grid());

    final stickyHeader = find.byKey(
      const ValueKey<String>('timeline-sticky-header-row'),
    );
    final rail = find.byKey(
      const ValueKey<String>('timeline-layer-controls-rail'),
    );
    final scrollbarArea = find.byKey(
      const ValueKey<String>('timeline-scrollbar-area'),
    );
    final horizontalScrollbar = find.byKey(
      const ValueKey<String>('timeline-horizontal-scrollbar'),
    );
    final scrollbarViewport = find.byKey(
      const ValueKey<String>('timeline-horizontal-scrollbar-viewport'),
    );
    final viewport = find.byKey(
      const ValueKey<String>('timeline-frame-scroll-viewport'),
    );
    final content = find.byKey(
      const ValueKey<String>('timeline-frame-scroll-content'),
    );
    final frameRuler = find.byKey(
      const ValueKey<String>('timeline-frame-ruler'),
    );
    final frameHeaderRow = find.byKey(
      const ValueKey<String>('timeline-frame-header-row'),
    );
    final frameGridArea = find.byKey(
      const ValueKey<String>('timeline-frame-grid-area'),
    );
    final bottomScrollbarRail = find.byKey(
      const ValueKey<String>('timeline-bottom-scrollbar-rail'),
    );
    final bottomScrollbarLeftSpacer = find.byKey(
      const ValueKey<String>('timeline-bottom-scrollbar-left-spacer'),
    );
    final horizontalScrollbarTrack = find.byKey(
      const ValueKey<String>('timeline-horizontal-scrollbar-track'),
    );
    final horizontalScrollbarThumb = find.byKey(
      const ValueKey<String>('timeline-horizontal-scrollbar-thumb'),
    );
    final verticalScrollbarSlot = find.byKey(
      const ValueKey<String>('timeline-vertical-scrollbar-slot'),
    );
    final verticalScrollbar = find.byKey(
      const ValueKey<String>('timeline-vertical-scrollbar'),
    );
    final verticalScrollbarTrack = find.byKey(
      const ValueKey<String>('timeline-vertical-scrollbar-track'),
    );
    final verticalScrollbarThumb = find.byKey(
      const ValueKey<String>('timeline-vertical-scrollbar-thumb'),
    );
    final verticalScrollbarBottomSpacer = find.byKey(
      const ValueKey<String>('timeline-vertical-scrollbar-bottom-spacer'),
    );
    final verticalScrollViewport = find.byKey(
      const ValueKey<String>('timeline-vertical-scroll-viewport'),
    );

    expect(stickyHeader, findsOneWidget);
    expect(rail, findsOneWidget);
    expect(scrollbarArea, findsOneWidget);
    expect(horizontalScrollbar, findsOneWidget);
    expect(scrollbarViewport, findsOneWidget);
    expect(viewport, findsOneWidget);
    expect(content, findsOneWidget);
    expect(frameRuler, findsOneWidget);
    expect(frameHeaderRow, findsOneWidget);
    expect(frameGridArea, findsOneWidget);
    expect(bottomScrollbarRail, findsOneWidget);
    expect(bottomScrollbarLeftSpacer, findsOneWidget);
    expect(horizontalScrollbarTrack, findsOneWidget);
    expect(horizontalScrollbarThumb, findsOneWidget);
    expect(verticalScrollbarSlot, findsOneWidget);
    expect(verticalScrollbar, findsOneWidget);
    expect(verticalScrollbarTrack, findsOneWidget);
    expect(verticalScrollbarThumb, findsOneWidget);
    expect(verticalScrollbarBottomSpacer, findsOneWidget);
    expect(verticalScrollViewport, findsOneWidget);
    expect(find.text('Layer 1'), findsOneWidget);
    expect(find.text('Layer 2'), findsOneWidget);
    expect(
      find.descendant(
        of: stickyHeader,
        matching: find.byKey(
          const ValueKey<String>('timeline-add-layer-button'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rail,
        matching: find.byKey(
          const ValueKey<String>('timeline-add-layer-button'),
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: viewport,
        matching: find.byKey(
          const ValueKey<String>('timeline-add-layer-button'),
        ),
      ),
      findsNothing,
    );
    expect(find.descendant(of: viewport, matching: rail), findsNothing);
    expect(
      find.descendant(of: scrollbarViewport, matching: viewport),
      findsOneWidget,
    );
    expect(
      find.descendant(of: verticalScrollViewport, matching: rail),
      findsOneWidget,
    );
    expect(
      find.descendant(of: verticalScrollViewport, matching: frameGridArea),
      findsOneWidget,
    );
    expect(
      find.descendant(of: horizontalScrollbar, matching: bottomScrollbarRail),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomScrollbarRail,
        matching: horizontalScrollbarTrack,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomScrollbarRail,
        matching: horizontalScrollbarThumb,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomScrollbarLeftSpacer,
        matching: horizontalScrollbarTrack,
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: bottomScrollbarLeftSpacer,
        matching: horizontalScrollbarThumb,
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: frameGridArea, matching: content),
      findsOneWidget,
    );
    expect(find.descendant(of: content, matching: frameRuler), findsNothing);
    expect(
      find.descendant(of: frameRuler, matching: frameHeaderRow),
      findsOneWidget,
    );
    expect(
      find.descendant(of: content, matching: bottomScrollbarRail),
      findsNothing,
    );
    expect(
      tester.getTopLeft(bottomScrollbarRail).dy,
      greaterThan(tester.getTopLeft(frameGridArea).dy),
    );

    final railRect = tester.getRect(rail);
    final frameGridAreaRect = tester.getRect(frameGridArea);
    final leftSpacerRect = tester.getRect(bottomScrollbarLeftSpacer);
    final bottomRailRect = tester.getRect(bottomScrollbarRail);
    final horizontalScrollbarRect = tester.getRect(horizontalScrollbar);
    final verticalSlotRect = tester.getRect(verticalScrollbarSlot);
    final verticalScrollbarRect = tester.getRect(verticalScrollbar);
    final verticalBottomSpacerRect = tester.getRect(
      verticalScrollbarBottomSpacer,
    );

    expect(leftSpacerRect.left, moreOrLessEquals(railRect.left));
    expect(leftSpacerRect.right, lessThanOrEqualTo(bottomRailRect.left));
    expect(leftSpacerRect.width, moreOrLessEquals(railRect.width));
    expect(leftSpacerRect.width, moreOrLessEquals(220));
    expect(verticalSlotRect.left, moreOrLessEquals(railRect.right));
    expect(verticalSlotRect.right, moreOrLessEquals(frameGridAreaRect.left));
    expect(verticalSlotRect.width, moreOrLessEquals(14));
    expect(verticalScrollbarRect.left, moreOrLessEquals(verticalSlotRect.left));
    expect(
      verticalScrollbarRect.width,
      moreOrLessEquals(verticalSlotRect.width),
    );
    expect(
      verticalBottomSpacerRect.left,
      moreOrLessEquals(leftSpacerRect.right),
    );
    expect(
      verticalBottomSpacerRect.width,
      moreOrLessEquals(verticalSlotRect.width),
    );
    expect(bottomRailRect.left, moreOrLessEquals(frameGridAreaRect.left));
    expect(bottomRailRect.width, moreOrLessEquals(frameGridAreaRect.width));
    expect(
      horizontalScrollbarRect.left,
      greaterThanOrEqualTo(leftSpacerRect.right),
    );
    expect(horizontalScrollbarRect.left, moreOrLessEquals(bottomRailRect.left));
    expect(
      horizontalScrollbarRect.width,
      moreOrLessEquals(bottomRailRect.width),
    );
    expect(
      tester.getRect(horizontalScrollbarTrack).width,
      moreOrLessEquals(bottomRailRect.width),
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-layer-visibility-layer-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-layer-opacity-layer-1')),
      findsOneWidget,
    );
  });

  testWidgets('keeps header and add-layer cell sticky during vertical scroll', (
    tester,
  ) async {
    final manyLayers = List<Layer>.generate(
      30,
      (index) => _layer(id: 'layer-${index + 1}', name: 'Layer ${index + 1}'),
    );

    await tester.pumpWidget(_grid(layers: manyLayers, frameCount: 48));

    final addLayer = find.byKey(
      const ValueKey<String>('timeline-add-layer-button'),
    );
    final frameHeader = find.byKey(
      const ValueKey<String>('timeline-frame-header-0'),
    );
    final firstLayerRow = find.byKey(
      const ValueKey<String>('timeline-layer-row-layer-1'),
    );
    final firstFrameRow = find.byKey(
      const ValueKey<String>('timeline-frame-row-area-layer-1'),
    );

    final initialAddLayerTop = tester.getTopLeft(addLayer).dy;
    final initialFrameHeaderTop = tester.getTopLeft(frameHeader).dy;
    final initialLayerRowTop = tester.getTopLeft(firstLayerRow).dy;
    final initialFrameRowTop = tester.getTopLeft(firstFrameRow).dy;

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-vertical-scroll-viewport')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(addLayer).dy, moreOrLessEquals(initialAddLayerTop));
    expect(
      tester.getTopLeft(frameHeader).dy,
      moreOrLessEquals(initialFrameHeaderTop),
    );
    expect(tester.getTopLeft(firstLayerRow).dy, lessThan(initialLayerRowTop));
    expect(tester.getTopLeft(firstFrameRow).dy, lessThan(initialFrameRowTop));
    expect(
      (tester.getTopLeft(firstLayerRow).dy -
              tester.getTopLeft(firstFrameRow).dy)
          .abs(),
      lessThan(0.1),
    );
  });

  testWidgets(
    'keeps layer controls and frame rows vertically aligned for many layers',
    (tester) async {
      final manyLayers = List<Layer>.generate(
        30,
        (index) => _layer(id: 'layer-${index + 1}', name: 'Layer ${index + 1}'),
      );

      await tester.pumpWidget(_grid(layers: manyLayers, frameCount: 48));

      final layerRow = find.byKey(
        const ValueKey<String>('timeline-layer-row-layer-24'),
      );
      final frameRow = find.byKey(
        const ValueKey<String>('timeline-frame-row-area-layer-24'),
      );

      expect(layerRow, findsOneWidget);
      expect(frameRow, findsOneWidget);
      expect(
        (tester.getTopLeft(layerRow).dy - tester.getTopLeft(frameRow).dy).abs(),
        lessThan(0.1),
      );

      final frameGridArea = find.byKey(
        const ValueKey<String>('timeline-frame-grid-area'),
      );
      final dragStart = tester.getTopLeft(frameGridArea) + const Offset(20, 20);

      await tester.dragFrom(dragStart, const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(layerRow, findsOneWidget);
      expect(frameRow, findsOneWidget);
      expect(
        (tester.getTopLeft(layerRow).dy - tester.getTopLeft(frameRow).dy).abs(),
        lessThan(0.1),
      );
    },
  );

  testWidgets('horizontal scrolling keeps layer controls rail mounted', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(frameCount: 48));

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('timeline-layer-controls-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-add-layer-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-layer-row-layer-1')),
      findsOneWidget,
    );
  });

  testWidgets('virtualizes large frame counts with spacer geometry', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(frameCount: 100000));

    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-header-leading-spacer'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-header-trailing-spacer'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-row-leading-spacer-layer-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-row-trailing-spacer-layer-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-99999')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-99999')),
      findsNothing,
    );

    final builtHeaderCount = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              ((widget.key as ValueKey<String>).value).startsWith(
                'timeline-frame-header-',
              ) &&
              !((widget.key as ValueKey<String>).value).contains('spacer'),
        )
        .evaluate()
        .length;
    final builtLayerOneCellCount = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              ((widget.key as ValueKey<String>).value).startsWith(
                'timeline-cell-layer-1-',
              ),
        )
        .evaluate()
        .length;

    expect(builtHeaderCount, lessThan(100));
    expect(builtLayerOneCellCount, lessThan(100));
  });

  testWidgets('horizontal scroll changes virtualized frame range', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(frameCount: 100000));

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-100')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-100')),
      findsNothing,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
      const Offset(-4800, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('timeline-layer-controls-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-100')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-100')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-0')),
      findsNothing,
    );
  });

  testWidgets('minimum visible frame cells still extends small frame counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        frameCount: 3,
        layers: [_layer(id: 'layer-1', name: 'Layer 1')],
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-3')),
      findsOneWidget,
    );
  });

  testWidgets('renders layer kind icons before layer names', (tester) async {
    await tester.pumpWidget(
      _grid(
        layers: [
          _layer(id: 'layer-1', name: 'Layer 1'),
          _layer(id: 'layer-2', name: 'Layer 2', kind: LayerKind.storyboard),
        ],
      ),
    );

    final animationIcon = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('timeline-layer-kind-icon-layer-1')),
    );
    final storyboardIcon = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('timeline-layer-kind-icon-layer-2')),
    );
    expect(animationIcon.icon, Icons.brush_outlined);
    expect(storyboardIcon.icon, Icons.auto_stories_outlined);
    expect(find.bySemanticsLabel('Animation layer'), findsOneWidget);
    expect(find.bySemanticsLabel('Storyboard layer'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('timeline-layer-name-layer-1')),
        matching: find.byKey(
          const ValueKey<String>('timeline-layer-kind-icon-layer-1'),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Layer 1'), findsOneWidget);
    expect(find.text('Layer 2'), findsOneWidget);
  });

  testWidgets('add layer button calls callback', (tester) async {
    var called = false;

    await tester.pumpWidget(_grid(onAddLayer: () => called = true));
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-add-layer-button')),
    );

    expect(called, isTrue);
  });

  testWidgets('visibility button calls callback', (tester) async {
    LayerId? toggledLayerId;

    await tester.pumpWidget(
      _grid(onToggleLayerVisibility: (layerId) => toggledLayerId = layerId),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-layer-visibility-layer-2')),
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
      find.byKey(const ValueKey<String>('timeline-layer-opacity-layer-1')),
      const Offset(-30, 0),
    );

    expect(changedLayerId, const LayerId('layer-1'));
    expect(changedOpacity, isNotNull);
  });

  testWidgets('renders frame headers and cells', (tester) async {
    await tester.pumpWidget(_grid());

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-2-0')),
      findsOneWidget,
    );
  });

  testWidgets('tapping frame ruler header selects zero-based frame index', (
    tester,
  ) async {
    int? selectedFrameIndex;

    await tester.pumpWidget(
      _grid(onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-frame-header-3')),
    );

    expect(selectedFrameIndex, 3);
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
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-3')),
    );

    expect(selectedLayerId, const LayerId('layer-1'));
    expect(selectedFrameIndex, 3);
  });

  testWidgets('selects layer from row controls', (tester) async {
    LayerId? selectedLayerId;

    await tester.pumpWidget(
      _grid(onSelectLayer: (layerId) => selectedLayerId = layerId),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-layer-name-layer-2')),
    );

    expect(selectedLayerId, const LayerId('layer-2'));
  });

  testWidgets('selects layer from layer row label area', (tester) async {
    LayerId? selectedLayerId;

    await tester.pumpWidget(
      _grid(onSelectLayer: (layerId) => selectedLayerId = layerId),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-layer-name-layer-2')),
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

    final cell = find.byKey(const ValueKey<String>('timeline-cell-layer-2-2'));
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

  testWidgets('playhead appears for visible current frame', (tester) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 3));

    expect(
      find.byKey(const ValueKey<String>('timeline-playhead')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-playhead-column')),
      findsOneWidget,
    );
  });

  testWidgets('playhead does not appear for non-visible current frame', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 5000, frameCount: 100000));

    expect(
      find.byKey(const ValueKey<String>('timeline-playhead')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-playhead-column')),
      findsNothing,
    );
  });

  testWidgets('playhead follows horizontal scroll range', (tester) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 100, frameCount: 100000));

    expect(
      find.byKey(const ValueKey<String>('timeline-playhead')),
      findsNothing,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
      const Offset(-4800, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-100')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-playhead')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-playhead-column')),
      findsOneWidget,
    );
  });

  testWidgets('playhead column keeps full frame width with one layer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        currentFrameIndex: 3,
        layers: [_layer(id: 'layer-1', name: 'Layer 1')],
      ),
    );

    final column = find.byKey(
      const ValueKey<String>('timeline-playhead-column'),
    );

    expect(column, findsOneWidget);
    expect(tester.getSize(column), const Size(48, 104));

    final container = tester.widget<Container>(column);
    expect(container.color, Colors.red.withValues(alpha: 0.18));
    expect(container.decoration, isNull);
  });

  testWidgets('playhead does not affect frame header tap', (tester) async {
    int? selectedFrameIndex;

    await tester.pumpWidget(
      _grid(
        currentFrameIndex: 3,
        onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-frame-header-3')),
    );

    expect(selectedFrameIndex, 3);
  });

  testWidgets('playhead does not affect frame cell selection', (tester) async {
    LayerId? selectedLayerId;
    int? selectedFrameIndex;

    await tester.pumpWidget(
      _grid(
        currentFrameIndex: 3,
        onSelectLayer: (layerId) => selectedLayerId = layerId,
        onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-3')),
    );

    expect(selectedLayerId, const LayerId('layer-1'));
    expect(selectedFrameIndex, 3);
  });

  testWidgets('current frame header uses plain text', (tester) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 3));

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-3')),
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

    final cell = find.byKey(const ValueKey<String>('timeline-cell-layer-2-2'));
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
      find.byKey(const ValueKey<String>('timeline-selected-cell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-selected-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-2-2')),
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
    var cell = find.byKey(const ValueKey<String>('timeline-cell-layer-1-0'));
    expect(find.descendant(of: cell, matching: find.text('○')), findsOneWidget);

    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.blankStart
            : TimelineCellExposureState.empty,
      ),
    );
    cell = find.byKey(const ValueKey<String>('timeline-cell-layer-1-0'));
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
    cell = find.byKey(const ValueKey<String>('timeline-cell-layer-1-0'));
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
    cell = find.byKey(const ValueKey<String>('timeline-cell-layer-1-0'));
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
    expect(selectedDrawing.border, Colors.red);
    expect(selectedDrawing.background, isNot(heldDrawing.background));
  });
}

Widget _grid({
  int currentFrameIndex = 0,
  int frameCount = 12,
  List<Layer>? layers,
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
        height: 260,
        child: LayerTimelineGrid(
          layers: layers ?? _layers,
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
  _layer(id: 'layer-1', name: 'Layer 1'),
  _layer(id: 'layer-2', name: 'Layer 2', opacity: 0.5),
];

Layer _layer({
  required String id,
  required String name,
  double opacity = 1,
  LayerKind kind = LayerKind.animation,
}) {
  final layerNumber = id.split('-').last;

  return Layer(
    id: LayerId(id),
    name: name,
    kind: kind,
    opacity: opacity,
    frames: [
      Frame(id: FrameId('frame-$layerNumber'), duration: 1, strokes: const []),
    ],
  );
}
