import 'package:flutter/material.dart';

import '../models/canvas_size.dart';
import '../models/canvas_viewport.dart';
import '../models/timesheet_document.dart';
import 'brush/brush_canvas_panel.dart';
import 'brush/brush_edit_cache_invalidation_sink.dart';
import 'editor_session_manager.dart';
import 'timesheet/timesheet_document_painter.dart';

/// The Timesheet tab's content: the active cut rendered as a paper
/// timesheet DOCUMENT (not an editing grid) inside the canvas panel shell,
/// so navigation feels exactly like the drawing canvas — wheel zoom,
/// middle-drag/two-finger pan, panbars, Fit. Read-only in S1; ink
/// annotation with the current brush arrives on top of this host.
class TimesheetTabHost extends StatefulWidget {
  const TimesheetTabHost({
    super.key,
    required this.session,
    required this.continuous,
    required this.onContinuousChanged,
    this.viewport,
    this.onViewportChanged,
  });

  final EditorSessionManager session;

  /// Page-split (false, paper default) ⟷ continuous view.
  final bool continuous;
  final ValueChanged<bool> onContinuousChanged;

  /// Owned above the tab group so zoom/pan survive tab switches.
  final CanvasViewport? viewport;
  final ValueChanged<CanvasViewport>? onViewportChanged;

  @override
  State<TimesheetTabHost> createState() => _TimesheetTabHostState();
}

class _TimesheetTabHostState extends State<TimesheetTabHost> {
  /// Commit sink required by the panel API; the sheet host never commits
  /// strokes in S1 (contentOverride only), so it stays untouched.
  final BrushEditCacheInvalidationSink _cacheInvalidationSink =
      BrushEditCacheInvalidationSink();

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<int?>(
      valueListenable: session.playback.globalFrameIndexListenable,
      builder: (context, playbackGlobalFrame, _) {
        final document = TimesheetDocument.fromCut(
          cut: session.activeCut,
          projectName: session.repository.requireProject().name,
          fps: session.projectFps,
        );
        final layout = TimesheetDocumentLayout(
          document: document,
          continuous: widget.continuous,
        );
        final documentSize = layout.documentSize;
        final playheadFrame = playbackGlobalFrame == null
            ? session.currentFrameIndex
            : session.playback.position?.localFrameIndex ??
                  session.currentFrameIndex;
        final playheadPage =
            (playheadFrame ~/ document.pageFrameCount).clamp(
              0,
              document.pages.length - 1,
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
                  projectLabel: document.projectName,
                  cutLabel: document.cutName,
                  layerLabel: 'Timesheet',
                  frameLabel: '${playheadFrame + 1}',
                ),
                // Fit frames the page the playhead is on.
                fitFocusRect: layout.pageRect(playheadPage),
                contentOverride: (context, viewport) => CustomPaint(
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
            ),
          ],
        );
      },
    );
  }
}
