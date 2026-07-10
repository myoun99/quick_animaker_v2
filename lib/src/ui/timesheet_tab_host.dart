import 'package:flutter/material.dart';

import '../models/canvas_size.dart';
import '../models/canvas_viewport.dart';
import '../models/timesheet_document.dart';
import '../models/timesheet_info.dart';
import 'brush/brush_canvas_panel.dart';
import 'brush/brush_edit_cache_invalidation_sink.dart';
import 'brush/brush_tool_state.dart';
import 'dialogs/timesheet_info_dialog.dart';
import 'editor_session_manager.dart';
import 'timesheet/timesheet_document_painter.dart';
import 'timesheet/timesheet_header_edit_layer.dart';
import 'timesheet/timesheet_ink_controller.dart';
import 'timesheet/timesheet_ink_layer.dart';

/// The Timesheet tab's content: the active cut rendered as a paper
/// timesheet DOCUMENT (not an editing grid) inside the canvas panel shell,
/// so navigation feels exactly like the drawing canvas — wheel zoom,
/// middle-drag/two-finger pan, panbars, Fit. With an [inkController] and
/// [brushToolState] the sheet takes freehand ink memos with the current
/// brush/eraser (S2): frame-anchored strip ink over the column grid,
/// paper-anchored page ink everywhere else.
class TimesheetTabHost extends StatefulWidget {
  const TimesheetTabHost({
    super.key,
    required this.session,
    required this.continuous,
    required this.onContinuousChanged,
    this.viewport,
    this.onViewportChanged,
    this.inkController,
    this.brushToolState,
    this.inkEnabled = true,
    this.onInkEnabledChanged,
  });

  final EditorSessionManager session;

  /// Page-split (false, paper default) ⟷ continuous view.
  final bool continuous;
  final ValueChanged<bool> onContinuousChanged;

  /// Owned above the tab group so zoom/pan survive tab switches.
  final CanvasViewport? viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;

  /// Sheet ink stores, owned above the tab group so annotations survive
  /// tab switches. Null renders the sheet read-only.
  final TimesheetInkController? inkController;

  /// The editor's current brush/eraser; required for ink input.
  final BrushToolState? brushToolState;

  /// The sheet-ink allow toggle (owned above the tab group): blocked ink
  /// protects the sheet from stray pen marks AND turns taps into
  /// header/memo text editing (the edit layer sits under the ink windows).
  final bool inkEnabled;
  final ValueChanged<bool>? onInkEnabledChanged;

  @override
  State<TimesheetTabHost> createState() => _TimesheetTabHostState();
}

class _TimesheetTabHostState extends State<TimesheetTabHost> {
  /// Commit sink required by the panel API; sheet ink invalidations stay
  /// local (synthetic ink keys never reach the playback caches).
  final BrushEditCacheInvalidationSink _cacheInvalidationSink =
      BrushEditCacheInvalidationSink();

  // Memoized sheet document + layouts: building them is the expensive part
  // of this host's rebuild, and most session notifies (fx toggles, waveform
  // loads, selections, committed seeks) change none of their inputs — the
  // model objects are immutable, so identity is the staleness check.
  TimesheetDocument? _document;
  TimesheetDocumentLayout? _layout;
  TimesheetDocumentLayout? _pagedLayout;
  Object? _documentCut;
  Object? _documentInfo;
  Object? _documentInstructionSet;
  String? _documentProjectName;
  int? _documentFps;
  bool? _layoutContinuous;

  TimesheetDocumentLayout _resolveLayouts(EditorSessionManager session) {
    final cut = session.activeCut;
    final info = session.timesheetInfo;
    final projectName = session.repository.requireProject().name;
    final instructionSet = session.cameraInstructionSet;
    if (_document == null ||
        !identical(_documentCut, cut) ||
        !identical(_documentInfo, info) ||
        !identical(_documentInstructionSet, instructionSet) ||
        _documentProjectName != projectName ||
        _documentFps != session.projectFps) {
      _documentCut = cut;
      _documentInfo = info;
      _documentInstructionSet = instructionSet;
      _documentProjectName = projectName;
      _documentFps = session.projectFps;
      _document = TimesheetDocument.fromCut(
        cut: cut,
        projectName: projectName,
        fps: session.projectFps,
        info: info,
        instructionDefById: instructionSet.defById,
      );
      _layout = null;
      _pagedLayout = null;
    }
    if (_layout == null || _layoutContinuous != widget.continuous) {
      _layoutContinuous = widget.continuous;
      _layout = TimesheetDocumentLayout(
        document: _document!,
        continuous: widget.continuous,
      );
      _pagedLayout = widget.continuous
          ? TimesheetDocumentLayout(document: _document!)
          : _layout;
    }
    return _layout!;
  }

  /// Raised while an ink stroke is in progress so the panel gesture layer
  /// holds navigation.
  final ValueNotifier<bool> _inkStrokeActive = ValueNotifier<bool>(false);

  @override
  void didUpdateWidget(covariant TimesheetTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Blocking ink unmounts the windows mid-stroke; clear the hold so the
    // gesture layer never stays pinned on a stroke that can't finish.
    if (!widget.inkEnabled && oldWidget.inkEnabled) {
      _inkStrokeActive.value = false;
    }
  }

  @override
  void dispose() {
    _inkStrokeActive.dispose();
    super.dispose();
  }

  void _commitHeaderField(TimesheetHeaderField field, String text) {
    final info = widget.session.timesheetInfo;
    final next = switch (field) {
      TimesheetHeaderField.title => info.copyWith(title: text),
      TimesheetHeaderField.episode => info.copyWith(episode: text),
      TimesheetHeaderField.scene => info.copyWith(scene: text),
      TimesheetHeaderField.name => info.copyWith(artist: text),
      _ => info,
    };
    widget.session.updateTimesheetInfo(next);
  }

  Future<void> _editSheetInfo() async {
    final session = widget.session;
    final nextInfo = await showDialog(
      context: context,
      builder: (context) =>
          TimesheetInfoDialog(initialInfo: session.timesheetInfo),
    );
    if (!mounted || nextInfo == null) {
      return;
    }
    session.updateTimesheetInfo(nextInfo);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final colorScheme = Theme.of(context).colorScheme;
    final inkController = widget.inkController;
    final brushToolState = widget.brushToolState;

    // Session changes (incl. undo/redo of sheet strokes) rebuild the sheet
    // data and hand the windows fresh ink session surfaces; ink commits
    // notify through the controller. Committed seeks (no longer session
    // notifies) move the playhead row/page.
    final listenable = Listenable.merge([
      session,
      session.frameSeekCommitted,
      session.playback.globalFrameIndexListenable,
      ?inkController,
    ]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final playbackGlobalFrame =
            session.playback.globalFrameIndexListenable.value;
        final layout = _resolveLayouts(session);
        final document = _document!;
        final pagedLayout = _pagedLayout!;
        inkController?.syncGeometry(pagedLayout);
        final documentSize = layout.documentSize;
        final playheadFrame = playbackGlobalFrame == null
            ? session.currentFrameIndex
            : session.playback.position?.localFrameIndex ??
                  session.currentFrameIndex;
        final playheadPage = (playheadFrame ~/ document.pageFrameCount).clamp(
          0,
          document.pages.length - 1,
        );
        // Playback follows the sheet (③): page view turns to the playhead's
        // page like flipping paper; continuous view scrolls the playhead
        // row into view without touching the zoom. Idle keeps the viewport
        // fully user-owned.
        final autoFrame = playbackGlobalFrame == null
            ? null
            : widget.continuous
            ? CanvasAutoFrameRequest(
                token: (
                  'timesheet-reveal',
                  session.activeCut.id,
                  playheadFrame,
                ),
                rect: Rect.fromLTWH(
                  layout.paperLeft,
                  layout.frameRowTop(playheadFrame),
                  layout.paperWidth,
                  TimesheetDocumentLayout.rowHeight,
                ),
                panOnly: true,
              )
            : CanvasAutoFrameRequest(
                token: ('timesheet-page', session.activeCut.id, playheadPage),
                rect: layout.pageRect(playheadPage),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Row(
                children: [
                  Text(
                    '${document.cutName} · ${document.durationLabel}',
                    key: const ValueKey<String>('timesheet-header-label'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onInkEnabledChanged != null)
                    IconButton(
                      key: const ValueKey<String>(
                        'timesheet-ink-toggle-button',
                      ),
                      tooltip: widget.inkEnabled
                          ? 'Block Sheet Ink'
                          : 'Allow Sheet Ink',
                      onPressed: () =>
                          widget.onInkEnabledChanged!(!widget.inkEnabled),
                      isSelected: widget.inkEnabled,
                      icon: const Icon(Icons.edit_off, size: 18),
                      selectedIcon: const Icon(Icons.draw, size: 18),
                    ),
                  IconButton(
                    key: const ValueKey<String>('timesheet-info-button'),
                    tooltip: 'Sheet Info',
                    onPressed: _editSheetInfo,
                    icon: const Icon(Icons.edit_note, size: 18),
                  ),
                  IconButton(
                    key: const ValueKey<String>(
                      'timesheet-page-mode-toggle-button',
                    ),
                    tooltip: widget.continuous
                        ? 'Page View'
                        : 'Continuous View',
                    onPressed: () =>
                        widget.onContinuousChanged(!widget.continuous),
                    icon: Icon(
                      widget.continuous
                          ? Icons.auto_stories_outlined
                          : Icons.view_agenda_outlined,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BrushCanvasPanel(
                coordinator: null,
                availableFrameKeys: const [],
                cacheInvalidationSink: _cacheInvalidationSink,
                canvasSize: CanvasSize(
                  width: documentSize.width.ceil(),
                  height: documentSize.height.ceil(),
                ),
                viewport: widget.viewport,
                onViewportChanged: widget.onViewportChanged,
                selectionLabels: CanvasEditorSelectionLabels(
                  projectLabel: document.title,
                  cutLabel: document.cutName,
                  layerLabel: 'Timesheet',
                  frameLabel: '${playheadFrame + 1}',
                ),
                // Fit frames the page the playhead is on.
                fitFocusRect: layout.pageRect(playheadPage),
                autoFrame: autoFrame,
                contentStrokeActive: inkController == null || !widget.inkEnabled
                    ? null
                    : _inkStrokeActive,
                contentOverride: (context, viewport) => Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const ValueKey<String>('timesheet-document-paint'),
                        painter: TimesheetDocumentPainter(
                          document: document,
                          layout: layout,
                          viewport: viewport,
                          playheadFrame: playheadFrame,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Under the ink windows: reachable exactly when ink is
                    // blocked (the toggle doubles as the edit-mode switch).
                    Positioned.fill(
                      child: TimesheetHeaderEditLayer(
                        key: const ValueKey<String>(
                          'timesheet-header-edit-layer',
                        ),
                        layout: layout,
                        viewport: viewport,
                        onHeaderFieldCommitted: _commitHeaderField,
                        onMemoCommitted: session.updateActiveCutNote,
                      ),
                    ),
                    if (inkController != null &&
                        brushToolState != null &&
                        widget.inkEnabled)
                      Positioned.fill(
                        child: TimesheetInkLayer(
                          key: const ValueKey<String>('timesheet-ink-layer'),
                          controller: inkController,
                          layout: layout,
                          pagedLayout: pagedLayout,
                          cutId: session.activeCut.id,
                          brushToolState: brushToolState,
                          historyManager: session.historyManager,
                          viewport: viewport,
                          strokeActive: _inkStrokeActive,
                          cacheInvalidationSink: _cacheInvalidationSink,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
