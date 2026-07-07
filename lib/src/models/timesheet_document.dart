import 'cut.dart';
import 'frame_id.dart';
import 'layer.dart';
import 'layer_kind.dart';

/// What a timesheet column represents on the paper form.
enum TimesheetColumnKind { cel, se, camera }

/// One cell of a timesheet column (one frame row).
enum TimesheetCellKind {
  /// Nothing on this row (paper stays blank).
  empty,

  /// First row of an uncovered run inside the playback range — the sheet
  /// "X" cell (same rule as the timeline grids: marks continue a run).
  emptyRunStart,

  /// A drawing exposure starts here; [TimesheetCell.label] carries the cel
  /// number (Frame.name, 1-based position fallback — export naming rule).
  drawing,

  /// Covered by the drawing above (the hold line runs through this row).
  held,

  /// An inbetween mark (drawn as the sheet's ○).
  mark,

  /// A camera keyframe row (camera column only).
  cameraKey,

  /// Between two camera keyframes (the camera column's motion line).
  cameraSpan,
}

class TimesheetCell {
  const TimesheetCell(this.kind, {this.label});

  static const TimesheetCell blank = TimesheetCell(TimesheetCellKind.empty);

  final TimesheetCellKind kind;

  /// Cel number for [TimesheetCellKind.drawing] cells.
  final String? label;
}

/// One sheet column: a header label plus one cell per document row. Columns
/// without a backing layer (reserved SE/camera slots) hold blank cells —
/// the paper form always shows them.
class TimesheetColumn {
  const TimesheetColumn({
    required this.kind,
    required this.label,
    required this.cells,
  });

  final TimesheetColumnKind kind;
  final String label;
  final List<TimesheetCell> cells;
}

/// One paper page: [frameCount] rows starting at [startFrame].
class TimesheetPage {
  const TimesheetPage({
    required this.index,
    required this.startFrame,
    required this.frameCount,
  });

  final int index;
  final int startFrame;
  final int frameCount;
}

/// The timesheet as a pure document view-model: what the sheet painter
/// draws and what the sheet exporters (XDTS, auto-sheet, ...) read. Built
/// from the cut's unified timeline model; carries no widget or session
/// references, so a snapshot can cross windows/isolates later.
class TimesheetDocument {
  TimesheetDocument._({
    required this.projectName,
    required this.cutName,
    required this.fps,
    required this.playbackFrameCount,
    required this.pageFrameCount,
    required this.columns,
    required this.pages,
  });

  /// Builds the document for [cut].
  ///
  /// Columns follow the Japanese paper form: the onTimesheet cel layers in
  /// model order, then a FIXED number of SE slots ([seColumnCount], grown
  /// when more SE layers exist) filled from the onTimesheet SE layers, then
  /// [cameraColumnCount] camera-instruction slots with the cut's camera
  /// keyframes in the first. Unbacked slots stay blank like paper.
  factory TimesheetDocument.fromCut({
    required Cut cut,
    required String projectName,
    required int fps,
    int pageSeconds = 6,
    int seColumnCount = 2,
    int cameraColumnCount = 2,
  }) {
    if (fps <= 0) {
      throw ArgumentError.value(fps, 'fps', 'fps must be positive.');
    }
    if (pageSeconds <= 0) {
      throw ArgumentError.value(
        pageSeconds,
        'pageSeconds',
        'pageSeconds must be positive.',
      );
    }

    final playbackFrameCount = cut.duration < 1 ? 1 : cut.duration;
    final pageFrameCount = pageSeconds * fps;
    final pageCount =
        ((playbackFrameCount + pageFrameCount - 1) ~/ pageFrameCount).clamp(
          1,
          1 << 20,
        );
    final rowCount = pageCount * pageFrameCount;

    final celLayers = [
      for (final layer in cut.layers)
        if (layer.kind == LayerKind.animation && layer.onTimesheet) layer,
    ];
    final seLayers = [
      for (final layer in cut.layers)
        if (layer.kind == LayerKind.se && layer.onTimesheet) layer,
    ];

    final columns = <TimesheetColumn>[
      for (final layer in celLayers)
        TimesheetColumn(
          kind: TimesheetColumnKind.cel,
          label: layer.name,
          cells: _layerCells(
            layer: layer,
            rowCount: rowCount,
            playbackFrameCount: playbackFrameCount,
          ),
        ),
      // The paper form always shows the SE slots; extra SE layers grow the
      // section rather than dropping data.
      for (var slot = 0; slot < _slotCount(seColumnCount, seLayers); slot += 1)
        TimesheetColumn(
          kind: TimesheetColumnKind.se,
          label: slot < seLayers.length ? seLayers[slot].name : 'SE',
          cells: slot < seLayers.length
              ? _layerCells(
                  layer: seLayers[slot],
                  rowCount: rowCount,
                  playbackFrameCount: playbackFrameCount,
                )
              : _blankCells(rowCount),
        ),
      for (var slot = 0; slot < cameraColumnCount; slot += 1)
        TimesheetColumn(
          kind: TimesheetColumnKind.camera,
          label: 'CAMERA',
          cells: slot == 0
              ? _cameraCells(
                  cut: cut,
                  rowCount: rowCount,
                  playbackFrameCount: playbackFrameCount,
                )
              : _blankCells(rowCount),
        ),
    ];

    return TimesheetDocument._(
      projectName: projectName,
      cutName: cut.name,
      fps: fps,
      playbackFrameCount: playbackFrameCount,
      pageFrameCount: pageFrameCount,
      columns: List.unmodifiable(columns),
      pages: List.unmodifiable([
        for (var page = 0; page < pageCount; page += 1)
          TimesheetPage(
            index: page,
            startFrame: page * pageFrameCount,
            frameCount: pageFrameCount,
          ),
      ]),
    );
  }

  final String projectName;
  final String cutName;
  final int fps;

  /// The cut's playback length; rows beyond it (page padding) stay blank.
  final int playbackFrameCount;

  /// Rows per paper page (pageSeconds × fps).
  final int pageFrameCount;

  final List<TimesheetColumn> columns;
  final List<TimesheetPage> pages;

  /// Total document rows (pages × pageFrameCount).
  int get rowCount => pages.length * pageFrameCount;

  /// The cut duration in the sheet's `초+コマ` notation (e.g. '2+12').
  String get durationLabel =>
      '${playbackFrameCount ~/ fps}+${playbackFrameCount % fps}';

  static int _slotCount(int fixedSlots, List<Layer> layers) {
    return layers.length > fixedSlots ? layers.length : fixedSlots;
  }

  static List<TimesheetCell> _blankCells(int rowCount) {
    return List<TimesheetCell>.filled(rowCount, TimesheetCell.blank);
  }

  /// Derives one layer's column cells from the unified timeline model:
  /// drawing starts carry the cel number, covered rows hold, marks show ○,
  /// and the FIRST row of each uncovered run inside the playback range gets
  /// the X (marks continue a run — same rule as the timeline grids).
  static List<TimesheetCell> _layerCells({
    required Layer layer,
    required int rowCount,
    required int playbackFrameCount,
  }) {
    final cells = List<TimesheetCell>.filled(rowCount, TimesheetCell.blank);

    final labelsByFrameId = <FrameId, String>{
      for (var index = 0; index < layer.frames.length; index += 1)
        layer.frames[index].id:
            layer.frames[index].name ?? '${index + 1}',
    };

    // Drawing coverage + marks straight from the timeline entries.
    final covered = List<bool>.filled(rowCount, false);
    for (final entry in layer.timeline.entries) {
      final start = entry.key;
      if (start >= rowCount) {
        continue;
      }
      final exposure = entry.value;
      if (exposure.isMark) {
        cells[start] = const TimesheetCell(TimesheetCellKind.mark);
        continue;
      }
      final endExclusive = (start + exposure.length!).clamp(0, rowCount);
      cells[start] = TimesheetCell(
        TimesheetCellKind.drawing,
        label: labelsByFrameId[exposure.frameId] ?? '?',
      );
      covered[start] = true;
      for (var row = start + 1; row < endExclusive; row += 1) {
        cells[row] = const TimesheetCell(TimesheetCellKind.held);
        covered[row] = true;
      }
    }

    // X only at the first uncovered row of each run, only inside the
    // playback range; a mark row continues the run instead of restarting it.
    var inEmptyRun = false;
    for (var row = 0; row < playbackFrameCount && row < rowCount; row += 1) {
      if (covered[row]) {
        inEmptyRun = false;
        continue;
      }
      if (cells[row].kind == TimesheetCellKind.mark) {
        inEmptyRun = true;
        continue;
      }
      if (!inEmptyRun) {
        cells[row] = const TimesheetCell(TimesheetCellKind.emptyRunStart);
        inEmptyRun = true;
      }
    }

    return cells;
  }

  /// The first camera column: keyframe rows with motion lines between
  /// successive keyframes.
  static List<TimesheetCell> _cameraCells({
    required Cut cut,
    required int rowCount,
    required int playbackFrameCount,
  }) {
    final cells = List<TimesheetCell>.filled(rowCount, TimesheetCell.blank);
    final keyframeRows = [
      for (final frame in cut.camera.keyframes.keys)
        if (frame < rowCount) frame,
    ];
    for (var index = 0; index < keyframeRows.length; index += 1) {
      final row = keyframeRows[index];
      cells[row] = TimesheetCell(
        TimesheetCellKind.cameraKey,
        label: '${index + 1}',
      );
      if (index + 1 < keyframeRows.length) {
        final nextRow = keyframeRows[index + 1];
        for (var span = row + 1; span < nextRow; span += 1) {
          cells[span] = const TimesheetCell(TimesheetCellKind.cameraSpan);
        }
      }
    }
    return cells;
  }
}
