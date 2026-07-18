import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_repeat.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_row_cells_painter.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_sheet_mode.dart';

import 'timeline_cell_probe.dart';

/// UI-R23 feedback #1: the sheet-TEXT mode — notation (shorthand) vs DATA
/// (every covered cell prints its resolved frame name, the audit view).
TimelineCellExposureState _stateFor(Layer layer, int frameIndex) {
  final block = coveringDrawingBlockAt(layer.timeline, frameIndex);
  if (block == null) {
    return TimelineCellExposureState.uncovered;
  }
  return block.startIndex == frameIndex
      ? TimelineCellExposureState.drawingStart
      : TimelineCellExposureState.held;
}

String? _nameFor(Layer layer, int frameIndex) {
  final frameId = exposedFrameIdAt(layer.timeline, frameIndex);
  if (frameId == null) {
    return null;
  }
  for (final frame in layer.frames) {
    if (frame.id == frameId) {
      return frame.name;
    }
  }
  return null;
}

TimelineRowCellsPainter _painter(Layer layer, {required bool dataMode}) =>
    TimelineRowCellsPainter(
      layer: layer,
      playbackFrameCount: 24,
      frameStartIndex: 0,
      frameEndIndexExclusive: 24,
      leadingFrameSpacerWidth: 0,
      frameCellExtent: 48,
      crossAxisExtent: 28,
      exposureStateForLayer: _stateFor,
      frameNameForLayer: _nameFor,
      colorScheme: const ColorScheme.dark(),
      baseTextStyle: const TextStyle(),
      sheetDataMode: dataMode,
    );

void main() {
  tearDown(() => TimelineSheet.dataMode.value = false);

  test('a HELD cell prints nothing in notation and its resolved frame '
      'name in DATA mode; the block start prints the name in both', () {
    final layer = Layer(
      id: const LayerId('a'),
      name: 'a',
      frames: [
        Frame(
          id: const FrameId('cel'),
          name: 'A1',
          duration: 3,
          strokes: const [],
        ),
      ],
      timeline: const {
        0: TimelineExposure.drawing(FrameId('cel'), length: 3),
      },
    );

    final notation = _painter(layer, dataMode: false);
    expect(notation.cellModelAt(0).glyph, 'A1');
    expect(notation.cellModelAt(1).glyph, '');
    expect(notation.cellModelAt(2).glyph, '');
    expect(notation.cellModelAt(3).glyph, 'X', reason: 'empty-run X stays');

    final data = _painter(layer, dataMode: true);
    expect(data.cellModelAt(0).glyph, 'A1');
    expect(data.cellModelAt(1).glyph, 'A1');
    expect(data.cellModelAt(2).glyph, 'A1');
    expect(data.cellModelAt(3).glyph, 'X', reason: 'empty cells unchanged');
  });

  test('a HOLD-edge ghost prints the continuing dash in notation and the '
      'resolved name in DATA mode; repeat ghosts name in both', () {
    var layer = Layer(
      id: const LayerId('a'),
      name: 'a',
      frames: [
        Frame(
          id: const FrameId('cel'),
          name: 'B2',
          duration: 1,
          strokes: const [],
        ),
      ],
      timeline: const {
        0: TimelineExposure.drawing(FrameId('cel'), length: 1),
      },
      runBehaviors: const [
        TimelineRunBehavior(
          anchorFrameId: FrameId('cel'),
          side: TimelineRunEdgeSide.end,
          mode: TimelineRunEdgeMode.hold,
        ),
      ],
    );
    layer = rederiveRunBehaviors(layer, cutFrameCount: 6);
    expect(layer.timeline[1]!.ghost, isTrue, reason: 'hold ghost derived');

    final notation = _painter(layer, dataMode: false);
    expect(
      notation.cellModelAt(1).glyph,
      isNot('B2'),
      reason: 'notation holds keep the dash, not the name',
    );
    expect(notation.cellModelAt(1).glyph, isNotEmpty);

    final data = _painter(layer, dataMode: true);
    expect(data.cellModelAt(1).glyph, 'B2');
    expect(data.cellModelAt(2).glyph, 'B2');
    // Derivation flags stay — DATA changes the text, not the ghost dim.
    expect(data.cellModelAt(1).ghost, isTrue);
  });

  test('the toolbar toggle flips the LIVE mode notifier', () {
    expect(TimelineSheet.showsData, isFalse);
    TimelineSheet.dataMode.value = true;
    expect(TimelineSheet.showsData, isTrue);
  });

  testWidgets('tapping the toolbar toggle rebuilds the grids in DATA mode '
      '(held cells print their name) and back', (tester) async {
    final project = Project(
      id: const ProjectId('sheet-mode'),
      name: 'Sheet Mode',
      createdAt: DateTime.utc(2026, 7, 19),
      tracks: [
        Track(
          id: const TrackId('t'),
          name: 'Video Track',
          cuts: [
            Cut(
              id: const CutId('c'),
              name: '1',
              duration: 24,
              canvasSize: const CanvasSize(width: 1280, height: 720),
              layers: [
                Layer(
                  id: const LayerId('sheet-layer'),
                  name: 'Drawing',
                  frames: [
                    Frame(
                      id: const FrameId('cel'),
                      name: 'A1',
                      duration: 3,
                      strokes: const [],
                    ),
                  ],
                  timeline: const {
                    0: TimelineExposure.drawing(FrameId('cel'), length: 3),
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: HomePage(initialProject: project)));
    await tester.pumpAndSettle();

    expect(timelineCellModel(tester, 'sheet-layer', 0).glyph, 'A1');
    expect(timelineCellModel(tester, 'sheet-layer', 1).glyph, '');

    final toggle = find.byKey(const ValueKey<String>('sheet-data-mode-toggle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(timelineCellModel(tester, 'sheet-layer', 1).glyph, 'A1');
    expect(timelineCellModel(tester, 'sheet-layer', 2).glyph, 'A1');

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(timelineCellModel(tester, 'sheet-layer', 1).glyph, '');
  });
}
