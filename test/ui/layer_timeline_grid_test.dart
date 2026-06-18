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
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_range_policy.dart';

bool _isGray(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  return red == green && green == blue;
}

final Matcher _isInsideTestRoot = isA<Rect>()
    .having((rect) => rect.left, 'left', greaterThanOrEqualTo(0))
    .having((rect) => rect.top, 'top', greaterThanOrEqualTo(0))
    .having((rect) => rect.right, 'right', lessThanOrEqualTo(800))
    .having((rect) => rect.bottom, 'bottom', lessThanOrEqualTo(600));

Future<void> _scrollFrameGridUntilKeyVisible(
  WidgetTester tester,
  ValueKey<String> key,
) async {
  final finder = find.byKey(key);
  final viewport = find.byKey(
    const ValueKey<String>('timeline-frame-scroll-viewport'),
  );
  final testRootSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final testRootRect = Offset.zero & testRootSize;

  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (finder.evaluate().isNotEmpty) {
      final targetRect = tester.getRect(finder);
      if (testRootRect.contains(targetRect.topLeft) &&
          testRootRect.contains(targetRect.bottomRight)) {
        return;
      }
    }

    await tester.drag(viewport, const Offset(-240, 0));
    await tester.pump();
  }

  fail('Expected $key to be rendered inside the test root after scrolling.');
}

void main() {
  testWidgets(
    'vertical scrollbar does not read unsettled scroll metrics on first pump',
    (tester) async {
      final layers = List<Layer>.generate(
        12,
        (index) => _layer(id: 'layer-${index + 1}', name: 'Layer ${index + 1}'),
      );

      await tester.pumpWidget(_grid(layers: layers, playbackFrameCount: 40));

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

  testWidgets(
    'sticky frame ruler lays out full content width without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 260));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_grid(playbackFrameCount: 96));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('timeline-frame-ruler')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-frame-header-row')),
        findsOneWidget,
      );
    },
  );

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

    await tester.pumpWidget(_grid(layers: manyLayers, playbackFrameCount: 48));

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

    expect(
      tester.getTopLeft(addLayer).dy,
      moreOrLessEquals(initialAddLayerTop),
    );
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

      await tester.pumpWidget(
        _grid(layers: manyLayers, playbackFrameCount: 48),
      );

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
    await tester.pumpWidget(_grid(playbackFrameCount: 48));

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
    await tester.pumpWidget(_grid(playbackFrameCount: 100000));

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
    await tester.pumpWidget(_grid(playbackFrameCount: 100000));

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
        playbackFrameCount: 3,
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

  testWidgets(
    'work-area frame header tap selects visible outside-playback frame',
    (tester) async {
      final selectedFrameIndices = <int>[];

      await tester.pumpWidget(
        _grid(
          playbackFrameCount: 3,
          layers: [_layer(id: 'layer-1', name: 'Layer 1')],
          onSelectFrame: selectedFrameIndices.add,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('timeline-frame-header-3')),
      );

      expect(selectedFrameIndices, isNotEmpty);
      expect(selectedFrameIndices.last, 3);
    },
  );

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

  testWidgets('displays playback frames plus safety work-area frames', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(playbackFrameCount: 24));

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-0')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
      const Offset(-520, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-23')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-24')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
      const Offset(-1200, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-47')),
      findsOneWidget,
    );
  });

  testWidgets('renders cut end boundary after playback frames', (tester) async {
    await tester.pumpWidget(_grid(playbackFrameCount: 24));

    final boundary = find.byKey(
      const ValueKey<String>('timeline-cut-end-boundary'),
    );
    final rulerBoundary = find.byKey(
      const ValueKey<String>('timeline-cut-end-boundary-ruler'),
    );
    expect(boundary, findsOneWidget);
    expect(rulerBoundary, findsOneWidget);

    final contentLeft = tester
        .getTopLeft(
          find.byKey(const ValueKey<String>('timeline-frame-scroll-content')),
        )
        .dx;
    final boundaryLeft = tester.getTopLeft(boundary).dx;
    expect(boundaryLeft - contentLeft, 24 * 48);
    expect(tester.getTopLeft(rulerBoundary).dx, boundaryLeft);
  });

  testWidgets(
    'clamps horizontal offset after viewport widens and keeps ruler/body aligned',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_grid(width: 500, playbackFrameCount: 100));
      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-2400, 0),
      );
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(4600, 320));
      await tester.pumpWidget(_grid(width: 4600, playbackFrameCount: 100));
      await tester.pump();
      await tester.pump();

      final frameGridArea = find.byKey(
        const ValueKey<String>('timeline-frame-grid-area'),
      );
      final header = find.byKey(
        const ValueKey<String>('timeline-frame-header-10'),
      );
      final cell = find.byKey(
        const ValueKey<String>('timeline-cell-layer-1-10'),
      );
      final leadingSpacer = find.byKey(
        const ValueKey<String>('timeline-frame-row-leading-spacer-layer-1'),
      );

      expect(header, findsOneWidget);
      expect(cell, findsOneWidget);
      expect(
        tester.getTopLeft(cell).dx,
        moreOrLessEquals(tester.getTopLeft(header).dx, epsilon: 1),
      );
      expect(
        tester.getTopLeft(leadingSpacer).dx,
        lessThanOrEqualTo(tester.getTopLeft(frameGridArea).dx + 1),
      );
      expect(
        tester.getTopLeft(cell).dx,
        lessThan(tester.getTopRight(frameGridArea).dx),
      );
    },
  );

  testWidgets(
    'selected exposure outline follows body cells after viewport widens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _grid(
          width: 500,
          currentFrameIndex: 10,
          playbackFrameCount: 100,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              10 => TimelineCellExposureState.drawingStart,
              11 || 12 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-2400, 0),
      );
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(4600, 320));
      await tester.pumpWidget(
        _grid(
          width: 4600,
          currentFrameIndex: 10,
          playbackFrameCount: 100,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              10 => TimelineCellExposureState.drawingStart,
              11 || 12 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      final outline = find.byKey(
        const ValueKey<String>(
          'timeline-selected-exposure-range-outline-layer-1',
        ),
      );
      final firstCell = find.byKey(
        const ValueKey<String>('timeline-cell-layer-1-10'),
      );
      final lastCell = find.byKey(
        const ValueKey<String>('timeline-cell-layer-1-12'),
      );

      expect(outline, findsOneWidget);
      expect(firstCell, findsOneWidget);
      expect(lastCell, findsOneWidget);
      expect(
        tester.getTopLeft(outline).dx,
        moreOrLessEquals(tester.getTopLeft(firstCell).dx, epsilon: 1),
      );
      expect(
        tester.getTopRight(outline).dx,
        moreOrLessEquals(tester.getTopRight(lastCell).dx, epsilon: 1),
      );
    },
  );

  testWidgets(
    'keeps ruler and body cut boundaries aligned after horizontal scroll',
    (tester) async {
      await tester.pumpWidget(_grid(playbackFrameCount: 24));

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-900, 0),
      );
      await tester.pumpAndSettle();

      final bodyBoundary = find.byKey(
        const ValueKey<String>('timeline-cut-end-boundary'),
      );
      final rulerBoundary = find.byKey(
        const ValueKey<String>('timeline-cut-end-boundary-ruler'),
      );
      expect(bodyBoundary, findsOneWidget);
      expect(rulerBoundary, findsOneWidget);
      expect(
        tester.getTopLeft(rulerBoundary).dx,
        moreOrLessEquals(tester.getTopLeft(bodyBoundary).dx),
      );
    },
  );

  testWidgets(
    'authored data outside playback is visible inside visible range',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          playbackFrameCount: 24,
          exposureStateForLayer: (_, frameIndex) => frameIndex == 45
              ? TimelineCellExposureState.drawingStart
              : TimelineCellExposureState.empty,
          frameNameForLayer: (_, frameIndex) => frameIndex == 45 ? 'A45' : null,
        ),
      );

      const cellKey = ValueKey<String>('timeline-cell-layer-1-45');
      await _scrollFrameGridUntilKeyVisible(tester, cellKey);

      final cell = find.byKey(cellKey);
      expect(cell, findsOneWidget);
      expect(
        find.descendant(of: cell, matching: find.text('A45')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'authored data outside visible range is hidden until visible range includes it',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          playbackFrameCount: 5,
          exposureStateForLayer: (_, frameIndex) => frameIndex == 45
              ? TimelineCellExposureState.drawingStart
              : TimelineCellExposureState.empty,
          frameNameForLayer: (_, frameIndex) => frameIndex == 45 ? 'A45' : null,
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-2400, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('timeline-cell-layer-1-45')),
        findsNothing,
      );
      expect(find.text('A45'), findsNothing);

      await tester.pumpWidget(
        _grid(
          playbackFrameCount: 24,
          exposureStateForLayer: (_, frameIndex) => frameIndex == 45
              ? TimelineCellExposureState.drawingStart
              : TimelineCellExposureState.empty,
          frameNameForLayer: (_, frameIndex) => frameIndex == 45 ? 'A45' : null,
        ),
      );
      const cellKey = ValueKey<String>('timeline-cell-layer-1-45');
      await _scrollFrameGridUntilKeyVisible(tester, cellKey);

      final cell = find.byKey(cellKey);
      expect(cell, findsOneWidget);
      expect(
        find.descendant(of: cell, matching: find.text('A45')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'outside-playback visible cell and header taps select their real frames',
    (tester) async {
      final selectedFrameIndices = <int>[];

      await tester.pumpWidget(
        _grid(onSelectFrame: selectedFrameIndices.add, playbackFrameCount: 24),
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-900, 0),
      );
      await tester.pumpAndSettle();

      final outsidePlaybackCell = find.byKey(
        const ValueKey<String>('timeline-cell-layer-1-24'),
      );
      expect(outsidePlaybackCell, findsOneWidget);
      expect(tester.getRect(outsidePlaybackCell), _isInsideTestRoot);
      await tester.tap(outsidePlaybackCell);

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-900, 0),
      );
      await tester.pumpAndSettle();

      final outsidePlaybackHeader = find.byKey(
        const ValueKey<String>('timeline-frame-header-40'),
      );
      expect(outsidePlaybackHeader, findsOneWidget);
      expect(tester.getRect(outsidePlaybackHeader), _isInsideTestRoot);
      await tester.tap(outsidePlaybackHeader);

      expect(selectedFrameIndices, isNotEmpty);
      expect(selectedFrameIndices, contains(24));
      expect(selectedFrameIndices.last, 40);
    },
  );

  testWidgets('clicking different ruler positions selects different frames', (
    tester,
  ) async {
    final selectedFrameIndices = <int>[];

    await tester.pumpWidget(
      _grid(onSelectFrame: selectedFrameIndices.add, playbackFrameCount: 20),
    );

    final scrubArea = find.byKey(
      const ValueKey<String>('timeline-frame-ruler-scrub-area'),
    );
    final scrubAreaTopLeft = tester.getTopLeft(scrubArea);

    await tester.tapAt(scrubAreaTopLeft + const Offset(12, 20));
    await tester.tapAt(scrubAreaTopLeft + const Offset(48 * 4 + 12, 20));
    await tester.tapAt(scrubAreaTopLeft + const Offset(48 * 9 + 12, 20));

    expect(selectedFrameIndices, containsAllInOrder(<int>[0, 4, 9]));
    expect(selectedFrameIndices.toSet(), containsAll(<int>{0, 4, 9}));
  });

  testWidgets('ruler tap updates stateful current frame selection', (
    tester,
  ) async {
    var currentFrameIndex = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _grid(
            currentFrameIndex: currentFrameIndex,
            playbackFrameCount: 20,
            onSelectFrame: (frameIndex) {
              setState(() => currentFrameIndex = frameIndex);
            },
          );
        },
      ),
    );

    final scrubArea = find.byKey(
      const ValueKey<String>('timeline-frame-ruler-scrub-area'),
    );
    await tester.tapAt(
      tester.getTopLeft(scrubArea) + const Offset(48 * 9 + 12, 20),
    );
    await tester.pump();

    expect(currentFrameIndex, 9);
    final selectedHeader = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('timeline-frame-header-9')),
        matching: find.byType(Container),
      ),
    );
    final decoration = selectedHeader.decoration as BoxDecoration;
    final border = decoration.border as Border;

    expect(decoration.color, isNotNull);
    expect(border.top.color, isNot(timelineSelectedFrameBorderColor));
    expect(border.top.width, 1);
  });

  testWidgets('dragging frame ruler scrub area scrubs changed frames', (
    tester,
  ) async {
    final selectedFrameIndices = <int>[];

    await tester.pumpWidget(
      _grid(onSelectFrame: selectedFrameIndices.add, playbackFrameCount: 20),
    );

    final scrubArea = find.byKey(
      const ValueKey<String>('timeline-frame-ruler-scrub-area'),
    );
    final start = tester.getTopLeft(scrubArea) + const Offset(48 + 8, 20);
    final gesture = await tester.startGesture(start);

    await gesture.moveBy(const Offset(48 * 4, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectedFrameIndices, containsAllInOrder(<int>[1, 5]));
    expect(selectedFrameIndices.last, 5);
  });

  testWidgets('frame ruler scrub respects horizontal scroll offset', (
    tester,
  ) async {
    final selectedFrameIndices = <int>[];

    await tester.pumpWidget(
      _grid(
        onSelectFrame: selectedFrameIndices.add,
        playbackFrameCount: 100000,
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
      const Offset(-4800, 0),
    );
    await tester.pumpAndSettle();

    final scrubArea = find.byKey(
      const ValueKey<String>('timeline-frame-ruler-scrub-area'),
    );
    await tester.tapAt(tester.getTopLeft(scrubArea) + const Offset(10, 20));

    expect(selectedFrameIndices.last, greaterThanOrEqualTo(99));
  });

  testWidgets('frame ruler scrub clamps selected frame to visible range', (
    tester,
  ) async {
    final selectedFrameIndices = <int>[];

    await tester.pumpWidget(
      _grid(onSelectFrame: selectedFrameIndices.add, playbackFrameCount: 3),
    );

    final scrubArea = find.byKey(
      const ValueKey<String>('timeline-frame-ruler-scrub-area'),
    );
    final scrubAreaRect = tester.getRect(scrubArea);

    await tester.tapAt(scrubAreaRect.centerRight - const Offset(1, 0));

    expect(selectedFrameIndices.last, greaterThanOrEqualTo(3));
    expect(selectedFrameIndices.last, lessThan(27));
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
    await tester.pumpWidget(
      _grid(currentFrameIndex: 5000, playbackFrameCount: 100000),
    );

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
    await tester.pumpWidget(
      _grid(currentFrameIndex: 100, playbackFrameCount: 100000),
    );

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

  testWidgets('current frame header keeps tint without red outline', (
    tester,
  ) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 3));

    final decoration = _headerDecoration(tester, 3);
    final border = decoration.border! as Border;

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-3')),
      findsOneWidget,
    );
    expect(decoration.color, isNotNull);
    expect(border.top.color, isNot(timelineSelectedFrameBorderColor));
    expect(border.top.width, 1);
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
    final selectedBorder =
        _cellDecoration(tester, 'timeline-cell-layer-1-2').border as Border;
    expect(selectedBorder.top.width, 3);
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

  testWidgets('drawing exposure cells keep divider-safe block radius rules', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (_, frameIndex) => switch (frameIndex) {
          0 => TimelineCellExposureState.drawingStart,
          1 || 2 => TimelineCellExposureState.heldExposure,
          _ => TimelineCellExposureState.empty,
        },
      ),
    );

    final startDecoration = _cellDecoration(tester, 'timeline-cell-layer-1-0');
    final middleDecoration = _cellDecoration(tester, 'timeline-cell-layer-1-1');
    final endDecoration = _cellDecoration(tester, 'timeline-cell-layer-1-2');

    expect(
      startDecoration.borderRadius,
      const BorderRadius.horizontal(left: Radius.circular(6)),
    );
    expect(middleDecoration.borderRadius, BorderRadius.zero);
    expect(
      endDecoration.borderRadius,
      const BorderRadius.horizontal(right: Radius.circular(6)),
    );
    expect(startDecoration.border, isA<Border>());
    expect(middleDecoration.border, isA<Border>());
    expect(endDecoration.border, isA<Border>());
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('timeline-cell-layer-1-1')),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('blank exposure cells keep divider-safe block radius rules', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        exposureStateForLayer: (_, frameIndex) => switch (frameIndex) {
          4 => TimelineCellExposureState.blankStart,
          5 || 6 => TimelineCellExposureState.blankHeld,
          _ => TimelineCellExposureState.empty,
        },
      ),
    );

    expect(
      _cellDecoration(tester, 'timeline-cell-layer-1-4').borderRadius,
      const BorderRadius.horizontal(left: Radius.circular(6)),
    );
    expect(
      _cellDecoration(tester, 'timeline-cell-layer-1-5').borderRadius,
      BorderRadius.zero,
    );
    expect(
      _cellDecoration(tester, 'timeline-cell-layer-1-6').borderRadius,
      const BorderRadius.horizontal(right: Radius.circular(6)),
    );
    final startBorder =
        _cellDecoration(tester, 'timeline-cell-layer-1-4').border as Border;
    expect(startBorder.top.color, startBorder.right.color);
    expect(startBorder.top.color, startBorder.bottom.color);
    expect(startBorder.top.color, startBorder.left.color);
  });

  testWidgets(
    'selecting drawingStart highlights the active drawing exposure range',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 0,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              0 => TimelineCellExposureState.drawingStart,
              1 || 2 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      _expectSelectedExposureRangeCells(tester, 'layer-1', const [0, 1, 2]);
      _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-1-3');
    },
  );

  testWidgets(
    'selecting heldExposure resolves back to the active drawing start range',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 2,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              0 => TimelineCellExposureState.drawingStart,
              1 || 2 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      _expectSelectedExposureRangeCells(tester, 'layer-1', const [0, 1, 2]);
    },
  );

  testWidgets(
    'selecting blankStart highlights the active blank exposure range',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 4,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              4 => TimelineCellExposureState.blankStart,
              5 || 6 => TimelineCellExposureState.blankHeld,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      _expectSelectedExposureRangeCells(tester, 'layer-1', const [4, 5, 6]);
      _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-1-3');
    },
  );

  testWidgets(
    'selecting blankHeld resolves back to the active blank start range',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 6,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              4 => TimelineCellExposureState.blankStart,
              5 || 6 => TimelineCellExposureState.blankHeld,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      _expectSelectedExposureRangeCells(tester, 'layer-1', const [4, 5, 6]);
    },
  );

  testWidgets('empty selected cells do not highlight an exposure range', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        currentFrameIndex: 3,
        exposureStateForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-1') && frameIndex == 0
            ? TimelineCellExposureState.drawingStart
            : TimelineCellExposureState.empty,
      ),
    );

    _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-1-0');
    expect(
      find.byKey(
        const ValueKey<String>(
          'timeline-selected-exposure-range-outline-layer-1',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('inactive layers do not show selected exposure range highlight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        currentFrameIndex: 2,
        exposureStateForLayer: (layer, frameIndex) {
          if (layer.id == const LayerId('layer-2')) {
            return switch (frameIndex) {
              1 => TimelineCellExposureState.drawingStart,
              2 || 3 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          }
          return TimelineCellExposureState.empty;
        },
      ),
    );

    _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-2-1');
    _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-2-2');
    _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-2-3');
    expect(
      find.byKey(
        const ValueKey<String>(
          'timeline-selected-exposure-range-outline-layer-2',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'outside-playback visible authored range can show selected highlight',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 45,
          playbackFrameCount: 24,
          authoredTimelineExtentFrameCount: 47,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              45 => TimelineCellExposureState.drawingStart,
              46 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      await _scrollFrameGridUntilKeyVisible(
        tester,
        const ValueKey<String>('timeline-cell-layer-1-45'),
      );

      _expectSelectedExposureRangeCells(tester, 'layer-1', const [45, 46]);
    },
  );

  testWidgets(
    'selected Blank held does not outline safety tail when viewport is widened',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _grid(
          width: 1800,
          currentFrameIndex: 4,
          playbackFrameCount: 24,
          authoredTimelineExtentFrameCount: 24,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              2 => TimelineCellExposureState.blankStart,
              >= 3 && <= 8 => TimelineCellExposureState.blankHeld,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-1700, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'timeline-selected-exposure-range-outline-layer-1',
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'selected drawing exposure outline survives horizontal virtualization',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 6,
          playbackFrameCount: 100,
          authoredTimelineExtentFrameCount: 21,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              6 => TimelineCellExposureState.drawingStart,
              >= 7 && <= 20 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-960, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('timeline-cell-layer-1-6')),
        findsNothing,
      );
      _expectSelectedExposureRangeOutline(tester, 'layer-1', const [
        17,
        18,
        19,
        20,
      ]);
    },
  );

  testWidgets(
    'selected held and blank held exposure outlines survive horizontal virtualization',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 16,
          playbackFrameCount: 100,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              12 => TimelineCellExposureState.drawingStart,
              >= 13 && <= 24 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-1200, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('timeline-cell-layer-1-16')),
        findsNothing,
      );
      _expectSelectedExposureRangeOutline(tester, 'layer-1', const [
        22,
        23,
        24,
      ]);

      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 16,
          playbackFrameCount: 100,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              12 => TimelineCellExposureState.blankStart,
              >= 13 && <= 24 => TimelineCellExposureState.blankHeld,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('timeline-cell-layer-1-16')),
        findsNothing,
      );
      _expectSelectedExposureRangeOutline(tester, 'layer-1', const [
        22,
        23,
        24,
      ]);
    },
  );

  testWidgets(
    'selected exposure outline is hidden when range has no visible intersection',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 6,
          playbackFrameCount: 100,
          authoredTimelineExtentFrameCount: 11,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              6 => TimelineCellExposureState.drawingStart,
              >= 7 && <= 10 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-1440, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'timeline-selected-exposure-range-outline-layer-1',
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('authored outside-playback selected range remains outlined', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        currentFrameIndex: 28,
        playbackFrameCount: 24,
        authoredTimelineExtentFrameCount: 33,
        exposureStateForLayer: (layer, frameIndex) {
          if (layer.id != const LayerId('layer-1')) {
            return TimelineCellExposureState.empty;
          }
          return switch (frameIndex) {
            28 => TimelineCellExposureState.drawingStart,
            >= 29 && <= 32 => TimelineCellExposureState.heldExposure,
            _ => TimelineCellExposureState.empty,
          };
        },
      ),
    );

    await _scrollFrameGridUntilKeyVisible(
      tester,
      const ValueKey<String>('timeline-cell-layer-1-28'),
    );

    _expectSelectedExposureRangeOutline(tester, 'layer-1', const [
      28,
      29,
      30,
      31,
      32,
    ]);
  });

  testWidgets('body frame content width stays aligned with ruler width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _grid(
        width: 1600,
        playbackFrameCount: 12,
        currentFrameIndex: 2,
        exposureStateForLayer: (layer, frameIndex) {
          if (layer.id != const LayerId('layer-1')) {
            return TimelineCellExposureState.empty;
          }
          return switch (frameIndex) {
            2 => TimelineCellExposureState.drawingStart,
            3 || 4 => TimelineCellExposureState.heldExposure,
            _ => TimelineCellExposureState.empty,
          };
        },
      ),
    );

    final expectedFrameRange = TimelineFrameRange.fromPlaybackDuration(
      playbackFrameCount: 12,
      minimumVisibleFrameCells:
          TimelineGridMetrics.defaults.minimumVisibleFrameCells,
    );

    final expectedContentWidth =
        expectedFrameRange.visibleFrameCount *
        TimelineGridMetrics.defaults.frameCellWidth;
    final content = find.byKey(
      const ValueKey<String>('timeline-frame-scroll-content'),
    );
    final headerZero = find.byKey(
      const ValueKey<String>('timeline-frame-header-0'),
    );
    final cellZero = find.byKey(
      const ValueKey<String>('timeline-cell-layer-1-0'),
    );

    expect(tester.getSize(content).width, closeTo(expectedContentWidth, 1.0));
    expect(
      tester.getTopLeft(cellZero).dx,
      closeTo(tester.getTopLeft(headerZero).dx, 1.0),
    );
    _expectSelectedExposureRangeOutline(tester, 'layer-1', const [2, 3, 4]);
  });

  testWidgets(
    'selecting frame 10 drawingStart does not highlight previous drawing block',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          currentFrameIndex: 10,
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              6 => TimelineCellExposureState.drawingStart,
              7 || 8 || 9 => TimelineCellExposureState.heldExposure,
              10 => TimelineCellExposureState.drawingStart,
              11 => TimelineCellExposureState.heldExposure,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-1-6');
      _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-1-7');
      _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-1-8');
      _expectNoSelectedExposureRangeBorder(tester, 'timeline-cell-layer-1-9');
      _expectSelectedExposureRangeCells(tester, 'layer-1', const [10, 11]);
    },
  );

  testWidgets(
    'previous block end before a new drawingStart gets right radius',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          exposureStateForLayer: (layer, frameIndex) {
            if (layer.id != const LayerId('layer-1')) {
              return TimelineCellExposureState.empty;
            }
            return switch (frameIndex) {
              6 => TimelineCellExposureState.drawingStart,
              7 || 8 || 9 => TimelineCellExposureState.heldExposure,
              10 => TimelineCellExposureState.drawingStart,
              _ => TimelineCellExposureState.empty,
            };
          },
        ),
      );

      expect(
        _cellDecoration(tester, 'timeline-cell-layer-1-9').borderRadius,
        const BorderRadius.horizontal(right: Radius.circular(6)),
      );
      expect(
        _cellDecoration(tester, 'timeline-cell-layer-1-10').borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );
    },
  );

  testWidgets(
    'visible authored data outside playback still renders as a block',
    (tester) async {
      await tester.pumpWidget(
        _grid(
          playbackFrameCount: 24,
          exposureStateForLayer: (_, frameIndex) => switch (frameIndex) {
            45 => TimelineCellExposureState.drawingStart,
            46 => TimelineCellExposureState.heldExposure,
            _ => TimelineCellExposureState.empty,
          },
        ),
      );

      await _scrollFrameGridUntilKeyVisible(
        tester,
        const ValueKey<String>('timeline-cell-layer-1-45'),
      );

      expect(
        _cellDecoration(tester, 'timeline-cell-layer-1-45').borderRadius,
        const BorderRadius.horizontal(left: Radius.circular(6)),
      );
      expect(
        _cellDecoration(tester, 'timeline-cell-layer-1-46').borderRadius,
        const BorderRadius.horizontal(right: Radius.circular(6)),
      );
    },
  );

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

BoxDecoration _cellDecoration(WidgetTester tester, String key) {
  final inkWell = tester.widget<InkWell>(find.byKey(ValueKey<String>(key)));
  final container = inkWell.child! as Container;
  return container.decoration! as BoxDecoration;
}

void _expectSelectedExposureRangeCells(
  WidgetTester tester,
  String layerId,
  List<int> frameIndices,
) {
  _expectSelectedExposureRangeOutline(tester, layerId, frameIndices);

  for (final frameIndex in frameIndices) {
    final key = 'timeline-cell-$layerId-$frameIndex';
    final decoration = _cellDecoration(tester, key);
    final border = decoration.border! as Border;

    expect(border.top.width, 1.0);
    expect(border.right.width, 1.0);
    expect(border.bottom.width, 1.0);
    expect(border.left.width, 1.0);
  }
}

void _expectNoSelectedExposureRangeBorder(WidgetTester tester, String key) {
  final decoration = _cellDecoration(tester, key);
  final border = decoration.border! as Border;

  expect(border.top.width, 1.0);
  expect(border.right.width, 1.0);
  expect(border.bottom.width, 1.0);
  expect(border.left.width, 1.0);
}

BoxDecoration _headerDecoration(WidgetTester tester, int frameIndex) {
  final inkWell = tester.widget<InkWell>(
    find.byKey(ValueKey<String>('timeline-frame-header-$frameIndex')),
  );
  final container = inkWell.child! as Container;
  return container.decoration! as BoxDecoration;
}

void _expectSelectedExposureRangeOutline(
  WidgetTester tester,
  String layerId,
  List<int> frameIndices,
) {
  final outlineFinder = find.byKey(
    ValueKey<String>('timeline-selected-exposure-range-outline-$layerId'),
  );
  expect(outlineFinder, findsOneWidget);

  final positioned = tester.widget<Positioned>(outlineFinder);
  final expectedWidth =
      frameIndices.length * TimelineGridMetrics.defaults.frameCellWidth;
  expect(positioned.width, expectedWidth);

  final firstCellRect = tester.getRect(
    find.byKey(
      ValueKey<String>('timeline-cell-$layerId-${frameIndices.first}'),
    ),
  );
  final outlineRect = tester.getRect(outlineFinder);
  expect(outlineRect.left, closeTo(firstCellRect.left, 1.0));
  expect(outlineRect.width, closeTo(expectedWidth, 1.0));

  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(of: outlineFinder, matching: find.byType(DecoratedBox)),
  );
  final decoration = decoratedBox.decoration as BoxDecoration;
  final border = decoration.border! as Border;
  expect(decoration.color, Colors.transparent);
  expect(border.top.color, timelineSelectedFrameBorderColor);
  expect(border.top.width, 2);
  expect(decoration.borderRadius, const BorderRadius.all(Radius.circular(6)));
  expect(
    find.descendant(of: outlineFinder, matching: find.byType(CustomPaint)),
    findsNothing,
  );
}

Widget _grid({
  int currentFrameIndex = 0,
  int playbackFrameCount = 12,
  int? authoredTimelineExtentFrameCount,
  double width = 900,
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
        width: width,
        height: 260,
        child: LayerTimelineGrid(
          layers: layers ?? _layers,
          activeLayerId: const LayerId('layer-1'),
          currentFrameIndex: currentFrameIndex,
          playbackFrameCount: playbackFrameCount,
          authoredTimelineExtentFrameCount: authoredTimelineExtentFrameCount,
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
