import 'camera_instruction.dart';
import 'cut.dart';
import 'frame_id.dart';
import 'layer.dart';
import 'layer_kind.dart';
import 'timesheet_info.dart';
import 'track_se_window.dart';

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

  /// A camera-work instruction span starts here (instruction CAM columns);
  /// [TimesheetCell.label] carries the writing (event text or vocabulary
  /// name), [TimesheetCell.valueA] the A endpoint.
  instructionStart,

  /// Inside an instruction span (the duration line runs through this row).
  instructionSpan,

  /// The instruction span's last covered row (line end tick + B endpoint).
  instructionEnd,
}

class TimesheetCell {
  const TimesheetCell(
    this.kind, {
    this.label,
    this.spanLength,
    this.spanOffset,
    this.markType,
    this.valueA,
    this.valueB,
    this.seName,
  });

  static const TimesheetCell blank = TimesheetCell(TimesheetCellKind.empty);

  final TimesheetCellKind kind;

  /// Cel number for [TimesheetCellKind.drawing] cells; the writing for
  /// [TimesheetCellKind.instructionStart] cells.
  final String? label;

  /// Rows the span covers. Drawing spans set it on the start cell only
  /// (vertical text fitting); instruction spans set it on EVERY covered
  /// row — the painter re-derives the whole mark per row so spans crossing
  /// page halves keep painting.
  final int? spanLength;

  /// This row's distance from its instruction span's start row (instruction
  /// cells only) — with [spanLength] it places the row inside the span's
  /// mark geometry.
  final int? spanOffset;

  /// The span's mark shape from its def (instruction cells only); null
  /// paints as [CameraInstructionMarkType.bar].
  final CameraInstructionMarkType? markType;

  /// The sheet's A → B endpoint values (instruction start cells only; the
  /// painter prints A at the start and B at the end row).
  final String? valueA;
  final String? valueB;

  /// SE drawing start cells only: the entry's speaker/effect name — method
  /// A prints it across the whole start row (accent box + underline, Toei
  /// style) with the dialogue distributing below.
  final String? seName;
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
    required this.scene,
    required this.artist,
    required this.memoText,
    required this.visibleHeaderFields,
    required this.exposureBarThreshold,
    required this.seEmptyFill,
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
    CameraInstructionDef? Function(String instructionId)? instructionDefById,
    // TRACK-owned SE rows (global-frame timelines) shown windowed to this
    // cut; [cutStartFrame] is the cut's global start on its track.
    List<Layer> trackSeLayers = const [],
    int cutStartFrame = 0,
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
    // SE rows are track-owned: window their global timelines to this cut
    // (spill-in synthesizes a display block; cut-crossing blocks clip at
    // the sheet's frame rows naturally). Cut-owned SE layers remain for
    // legacy fixtures.
    final seWindow = TrackSeWindow(
      cutStartFrame: cutStartFrame,
      cutDurationFrames: cut.duration,
    );
    final seLayers = [
      for (final layer in cut.layers)
        if (layer.kind == LayerKind.se && layer.onTimesheet) layer,
      for (final layer in trackSeLayers)
        if (layer.onTimesheet) seWindow.displayLayer(layer),
    ];
    final instructionLayers = [
      for (final layer in cut.layers)
        if (layer.kind == LayerKind.instruction && layer.onTimesheet) layer,
    ];
    // The CAM keyframe column obeys the camera layer's timesheet toggle
    // (unified layer controls); toggled off it stays printed blank form
    // space, like an unbacked slot.
    final cameraOnSheet = cut.layers
        .where((layer) => layer.kind == LayerKind.camera)
        .every((layer) => layer.onTimesheet);
    // CAM slots: the camera-keyframe column plus one per instruction row.
    final cameraSlotCount = 1 + instructionLayers.length > cameraColumnCount
        ? 1 + instructionLayers.length
        : cameraColumnCount;

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
          // The layer's stored name — the same label the timeline and
          // storyboard rows show (W3 ordering unification).
          label: slot < seLayers.length ? seLayers[slot].name : 'S${slot + 1}',
          layerName: slot < seLayers.length ? seLayers[slot].name : null,
          cells: slot < seLayers.length
              ? _layerCells(
                  layer: seLayers[slot],
                  rowCount: rowCount,
                  playbackFrameCount: playbackFrameCount,
                  // SE columns stay blank between entries on paper — no X;
                  // the speaker name rides along for the method-A name row.
                  markEmptyRuns: false,
                  includeSeNames: true,
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
      // CAM block: slot 0 keeps the camera transform keyframes; the
      // instruction rows (CAM 2 …) follow in layer order, growing the block
      // past the fixed count when a cut carries more.
      for (var slot = 0; slot < cameraSlotCount; slot += 1)
        TimesheetColumn(
          kind: TimesheetColumnKind.camera,
          label: '${slot + 1}',
          layerName: slot >= 1 && slot - 1 < instructionLayers.length
              ? instructionLayers[slot - 1].name
              : null,
          cells: slot == 0
              ? (cameraOnSheet
                    ? _cameraCells(cut: cut, rowCount: rowCount)
                    : _blankCells(rowCount))
              : slot - 1 < instructionLayers.length
              ? _instructionCells(
                  layer: instructionLayers[slot - 1],
                  rowCount: rowCount,
                  defById: instructionDefById,
                )
              : _blankCells(rowCount),
        ),
    ];

    return TimesheetDocument._(
      title: info.title.isEmpty ? projectName : info.title,
      episode: info.episode,
      scene: info.scene,
      artist: info.artist,
      memoText: cut.metadata.note,
      visibleHeaderFields: List.unmodifiable(info.visibleFields),
      exposureBarThreshold: info.exposureBarThreshold,
      seEmptyFill: info.seEmptyFill,
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
  /// episode label, scene label and artist name from [TimesheetInfo].
  final String title;
  final String episode;
  final String scene;
  final String artist;

  /// The cut's Direction memo (the cut note) printed in the memo band —
  /// per-cut data, editable in place on the sheet. Instruction shorthand
  /// lines land HERE (auto-written once at creation, R5-⑥) instead of a
  /// derived read-only list.
  final String memoText;

  /// The ACTION hold-bar setting mirrored from [TimesheetInfo]
  /// (null = bars off, N = bars from the (N+1)th comma of N+ holds).
  final int? exposureBarThreshold;

  /// Whether SE columns wash their empty stretches light gray (mirrored
  /// from [TimesheetInfo.seEmptyFill]).
  final bool seEmptyFill;

  /// The header boxes the form prints, in printing order (the user hides
  /// boxes per project via [TimesheetInfo.hiddenFields]).
  final List<TimesheetHeaderField> visibleHeaderFields;

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
    bool includeSeNames = false,
  }) {
    final cells = List<TimesheetCell>.filled(rowCount, TimesheetCell.blank);

    final labelsByFrameId = <FrameId, String>{
      // The sheet writes the frame NAME verbatim; unnamed cels print the
      // in-between division mark — never an invented number (R5-④, same
      // glyph the mark rows use).
      for (final frame in layer.frames) frame.id: frame.name ?? '○',
    };
    final seNamesByFrameId = <FrameId, String?>{
      if (includeSeNames)
        for (final frame in layer.frames) frame.id: frame.seName,
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
        spanLength: endExclusive - start,
        seName: seNamesByFrameId[exposure.frameId],
      );
      covered[start] = true;
      for (var row = start + 1; row < endExclusive; row += 1) {
        // Held rows know their place in the span so the painter can gate
        // the ACTION hold bar per the exposure-bar setting (drawn from the
        // (N+1)th comma of N+ holds only).
        cells[row] = TimesheetCell(
          TimesheetCellKind.held,
          spanLength: endExclusive - start,
          spanOffset: row - start,
        );
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

  /// An instruction row's CAM column: each event prints its writing (free
  /// text, vocabulary-name fallback) at the start with the A endpoint, its
  /// def's mark through the covered rows (straight duration line, FI/FO
  /// wedge or O.L bowtie) and the B endpoint on the last one — the paper
  /// sheet's camera-work notation. Every covered row carries the span's
  /// mark geometry so the painter can re-derive it row by row.
  static List<TimesheetCell> _instructionCells({
    required Layer layer,
    required int rowCount,
    CameraInstructionDef? Function(String instructionId)? defById,
  }) {
    final cells = List<TimesheetCell>.filled(rowCount, TimesheetCell.blank);
    for (final entry in layer.instructions.entries) {
      final start = entry.key;
      if (start >= rowCount) {
        continue;
      }
      final event = entry.value;
      final endExclusive = (start + event.length).clamp(0, rowCount);
      final spanLength = endExclusive - start;
      final markType = defById?.call(event.instructionId)?.markType;
      cells[start] = TimesheetCell(
        TimesheetCellKind.instructionStart,
        label: event.displayLabel(defById?.call(event.instructionId)),
        spanLength: spanLength,
        spanOffset: 0,
        markType: markType,
        valueA: event.valueA,
        valueB: event.valueB,
      );
      for (var row = start + 1; row < endExclusive; row += 1) {
        cells[row] = TimesheetCell(
          row == endExclusive - 1
              ? TimesheetCellKind.instructionEnd
              : TimesheetCellKind.instructionSpan,
          // The writing rides EVERY covered row (like the mark geometry):
          // the painter prints it on the span's middle row, which may sit
          // in another page half than the start.
          label: cells[start].label,
          spanLength: spanLength,
          spanOffset: row - start,
          markType: markType,
          valueB: row == endExclusive - 1 ? event.valueB : null,
        );
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

/// One memo-band line for an instruction event — the sheet shorthand the
/// user writes by hand: `<A><mark><B> <name> <memo>`, e.g. 'A⋈ O.L' or
/// 'C⋈D O.L カットO.L' (a single space before the memo — R4 dropped the
/// parentheses). The mark glyph mirrors the def's markType (⋈ = the O.L
/// bowtie, → = the bar); blank parts simply drop out.
String timesheetMemoInstructionLine(
  InstructionEvent event,
  CameraInstructionDef? def,
) {
  final markGlyph =
      (def?.markType ?? CameraInstructionMarkType.bar) ==
          CameraInstructionMarkType.ol
      ? '⋈'
      : '→';
  final endpoints = '${event.valueA ?? ''}$markGlyph${event.valueB ?? ''}';
  final memo = event.memo;
  final label =
      '${event.displayLabel(def)}${memo == null || memo.isEmpty ? '' : ' $memo'}';
  return label.isEmpty ? endpoints : '$endpoints $label';
}
