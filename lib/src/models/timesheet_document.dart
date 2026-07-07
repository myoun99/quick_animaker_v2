import 'cut.dart';
import 'frame_id.dart';
import 'layer.dart';
import 'layer_kind.dart';
import 'timesheet_info.dart';

/// What a timesheet column represents on the paper form.
enum TimesheetColumnKind {
  /// A column of the form's left ACTION block — the animation layers land
  /// here in order, headed by their real names; slots without a backing
  /// layer stay blank handwriting space (no placeholder letters).
  action,

  /// A CELL block form column — blank paper space with no printed letters;
  /// its role (cel re-assignment) is still user-undecided.
  cel,

  /// A dialogue/SE column (the S1/S2 slots between the rail and CELL).
  se,

  /// A camera-instruction column.
  camera,
}

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

/// One sheet column: the printed column header plus one cell per document
/// row. Slots without a backing layer hold blank cells — the paper form
/// always shows them.
class TimesheetColumn {
  const TimesheetColumn({
    required this.kind,
    required this.label,
    required this.cells,
    this.layerName,
  });

  final TimesheetColumnKind kind;

  /// The printed column header: the backing layer's REAL name for
  /// layer-backed slots, 'S1'/'S2'/camera indices for form slots, and empty
  /// for unbacked slots (nothing prints — no placeholder letters).
  final String label;

  /// The backing layer's name (action/SE slots only); null for empty slots.
  final String? layerName;

  final List<TimesheetCell> cells;
}

/// One paper page: [frameCount] rows starting at [startFrame], laid out in
/// two side-by-side halves of [TimesheetDocument.halfFrameCount] rows.
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
///
/// The column set follows the Japanese paper form: the ACTION block carries
/// the onTimesheet animation layers (headed by their real names, leftover
/// slots blank), then the frame rail, S1/S2 dialogue-SE slots, a blank CELL
/// block and the camera columns — fixed slots that stay blank when
/// unbacked, with no placeholder letters anywhere.
class TimesheetDocument {
  TimesheetDocument._({
    required this.title,
    required this.episode,
    required this.artist,
    required this.cutName,
    required this.fps,
    required this.playbackFrameCount,
    required this.pageFrameCount,
    required this.columns,
    required this.pages,
  });

  factory TimesheetDocument.fromCut({
    required Cut cut,
    required String projectName,
    required int fps,
    TimesheetInfo info = TimesheetInfo.empty,
    int pageSeconds = 6,
    int actionColumnCount = 8,
    int celColumnCount = 8,
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

    // Art cels (BG/BOOK) ride the ACTION block alongside animation cels —
    // the user keeps them behaviorally identical, only the kind differs.
    final animationLayers = [
      for (final layer in cut.layers)
        if ((layer.kind == LayerKind.animation ||
                layer.kind == LayerKind.art) &&
            layer.onTimesheet)
          layer,
    ];
    final seLayers = [
      for (final layer in cut.layers)
        if (layer.kind == LayerKind.se && layer.onTimesheet) layer,
    ];

    final columns = <TimesheetColumn>[
      // Animation layers fill the ACTION block in order, headed by their
      // real names; unbacked slots stay blank handwriting space.
      for (
        var slot = 0;
        slot < _slotCount(actionColumnCount, animationLayers);
        slot += 1
      )
        TimesheetColumn(
          kind: TimesheetColumnKind.action,
          label: slot < animationLayers.length
              ? animationLayers[slot].name
              : '',
          layerName: slot < animationLayers.length
              ? animationLayers[slot].name
              : null,
          cells: slot < animationLayers.length
              ? _layerCells(
                  layer: animationLayers[slot],
                  rowCount: rowCount,
                  playbackFrameCount: playbackFrameCount,
                )
              : _blankCells(rowCount),
        ),
      for (var slot = 0; slot < _slotCount(seColumnCount, seLayers); slot += 1)
        TimesheetColumn(
          kind: TimesheetColumnKind.se,
          label: 'S${slot + 1}',
          layerName: slot < seLayers.length ? seLayers[slot].name : null,
          cells: slot < seLayers.length
              ? _layerCells(
                  layer: seLayers[slot],
                  rowCount: rowCount,
                  playbackFrameCount: playbackFrameCount,
                  // SE columns stay blank between entries on paper — no X.
                  markEmptyRuns: false,
                )
              : _blankCells(rowCount),
        ),
      // The CELL block stays blank form space — no printed letters; its
      // role is user-undecided (see plan backlog).
      for (var slot = 0; slot < celColumnCount; slot += 1)
        TimesheetColumn(
          kind: TimesheetColumnKind.cel,
          label: '',
          cells: _blankCells(rowCount),
        ),
      for (var slot = 0; slot < cameraColumnCount; slot += 1)
        TimesheetColumn(
          kind: TimesheetColumnKind.camera,
          label: '${slot + 1}',
          cells: slot == 0
              ? _cameraCells(cut: cut, rowCount: rowCount)
              : _blankCells(rowCount),
        ),
    ];

    return TimesheetDocument._(
      title: info.title.isEmpty ? projectName : info.title,
      episode: info.episode,
      artist: info.artist,
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

  /// Sheet-header text: production title (project name unless overridden),
  /// episode label and artist name from [TimesheetInfo].
  final String title;
  final String episode;
  final String artist;

  final String cutName;
  final int fps;

  /// The cut's playback length; rows beyond it (page padding) stay blank.
  final int playbackFrameCount;

  /// Rows per paper page (pageSeconds × fps).
  final int pageFrameCount;

  final List<TimesheetColumn> columns;
  final List<TimesheetPage> pages;

  /// Rows per page HALF: the paper page splits into two side-by-side
  /// columns of this many rows (the second half takes any odd remainder).
  int get halfFrameCount => pageFrameCount ~/ 2;

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
    bool markEmptyRuns = true,
  }) {
    final cells = List<TimesheetCell>.filled(rowCount, TimesheetCell.blank);

    final labelsByFrameId = <FrameId, String>{
      for (var index = 0; index < layer.frames.length; index += 1)
        layer.frames[index].id: layer.frames[index].name ?? '${index + 1}',
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
    if (!markEmptyRuns) {
      return cells;
    }
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
