import 'package:flutter/material.dart';

import '../../models/brush_frame_key.dart';
import '../../models/canvas_viewport.dart';
import '../../models/cut_id.dart';
import '../../services/cache_invalidation_executor.dart';
import '../../services/history_manager.dart';
import '../brush/brush_tool_state.dart';
import '../canvas/interactive_brush_edit_canvas_view.dart';
import 'timesheet_document_painter.dart';
import 'timesheet_ink_controller.dart';

/// One on-sheet ink input/display window: a document-space rect that shows
/// (and draws into) a region of an ink surface.
///
/// The same strip band surface appears through TWO windows on a paged
/// sheet (the page's left and right halves), so [id] — not the frame key —
/// identifies a window.
class TimesheetInkWindow {
  const TimesheetInkWindow({
    required this.id,
    required this.plane,
    required this.key,
    required this.documentRect,
    required this.inkOffset,
  });

  final String id;
  final TimesheetInkPlane plane;
  final BrushFrameKey key;

  /// The window's rect in sheet document space.
  final Rect documentRect;

  /// Ink-surface pixel coordinate that maps to [documentRect]'s top-left.
  final Offset inkOffset;

  /// The viewport the interactive brush view needs so ink pixel (x, y)
  /// lands exactly where the document paints this window: the panel
  /// transform composed with the window placement and the ink scale.
  CanvasViewport inkViewport(CanvasViewport panelViewport) {
    final inkZoom = panelViewport.zoom / TimesheetInkController.inkScale;
    return CanvasViewport(
      zoom: inkZoom,
      panX:
          panelViewport.panX +
          panelViewport.zoom * documentRect.left -
          inkZoom * inkOffset.dx,
      panY:
          panelViewport.panY +
          panelViewport.zoom * documentRect.top -
          inkZoom * inkOffset.dy,
    );
  }

  /// The window's on-screen rect under the panel transform (the input hit
  /// region and display clip).
  Rect screenRect(CanvasViewport panelViewport) {
    return Rect.fromLTWH(
      panelViewport.panX + panelViewport.zoom * documentRect.left,
      panelViewport.panY + panelViewport.zoom * documentRect.top,
      panelViewport.zoom * documentRect.width,
      panelViewport.zoom * documentRect.height,
    );
  }
}

/// Computes the ink windows for the current view mode, bottom-of-stack
/// first: page ink lies under the strip windows, so a stroke STARTING on
/// the column grid goes to the frame-anchored strip plane and everything
/// else (header, memo band, margins, gaps) goes to the page plane. A
/// stroke keeps its start plane for its whole duration (pointer capture) —
/// simpler than per-segment routing and closer to how a pen behaves.
List<TimesheetInkWindow> timesheetInkWindows({
  required TimesheetDocumentLayout layout,
  required TimesheetDocumentLayout pagedLayout,
  required CutId cutId,
}) {
  final document = layout.document;
  final windows = <TimesheetInkWindow>[];
  const rowHeight = TimesheetDocumentLayout.rowHeight;

  if (layout.continuous) {
    // Page ink: page 1's surface over the identical header/memo geometry
    // (later pages' page ink is paged-view only).
    windows.add(
      TimesheetInkWindow(
        id: 'page-0-continuous',
        plane: TimesheetInkPlane.page,
        key: TimesheetInkController.pageKey(cutId, 0),
        documentRect: Rect.fromLTWH(
          layout.paperLeft,
          layout.pageTop(0),
          pagedLayout.paperWidth,
          pagedLayout.paperHeight,
        ),
        inkOffset: Offset.zero,
      ),
    );
    // Strip ink: the page bands stacked seamlessly down the single strip.
    final bandHeight = document.pageFrameCount * rowHeight;
    for (var band = 0; band < document.pages.length; band += 1) {
      windows.add(
        TimesheetInkWindow(
          id: 'strip-$band-continuous',
          plane: TimesheetInkPlane.strip,
          key: TimesheetInkController.stripBandKey(cutId, band),
          documentRect: Rect.fromLTWH(
            layout.halfLeft(0, 0),
            layout.halfRowsTop(0) + band * bandHeight,
            layout.halfWidth,
            bandHeight,
          ),
          inkOffset: Offset.zero,
        ),
      );
    }
    return windows;
  }

  for (final page in document.pages) {
    windows.add(
      TimesheetInkWindow(
        id: 'page-${page.index}',
        plane: TimesheetInkPlane.page,
        key: TimesheetInkController.pageKey(cutId, page.index),
        documentRect: layout.pageRect(page.index),
        inkOffset: Offset.zero,
      ),
    );
  }
  for (final page in document.pages) {
    for (var half = 0; half < 2; half += 1) {
      final rowCount = layout.halfRowCount(half);
      if (rowCount <= 0) {
        continue;
      }
      windows.add(
        TimesheetInkWindow(
          id: 'strip-${page.index}-h$half',
          plane: TimesheetInkPlane.strip,
          key: TimesheetInkController.stripBandKey(cutId, page.index),
          documentRect: Rect.fromLTWH(
            layout.halfLeft(page.index, half),
            layout.halfRowsTop(page.index),
            layout.halfWidth,
            rowCount * rowHeight,
          ),
          inkOffset: Offset(
            0,
            half *
                document.halfFrameCount *
                rowHeight *
                TimesheetInkController.inkScale,
          ),
        ),
      );
    }
  }
  return windows;
}

/// The sheet's ink input/display stack: every window hosts the SAME
/// interactive brush view the drawing canvas uses (current brush/eraser,
/// live overlay, dab commit), windowed onto its ink surface by a derived
/// viewport and clipped to its on-screen rect so pointer-downs outside it
/// fall through to the window below.
class TimesheetInkLayer extends StatelessWidget {
  const TimesheetInkLayer({
    super.key,
    required this.controller,
    required this.layout,
    required this.pagedLayout,
    required this.cutId,
    required this.brushToolState,
    required this.historyManager,
    required this.viewport,
    required this.strokeActive,
    this.cacheInvalidationSink,
  });

  final TimesheetInkController controller;
  final TimesheetDocumentLayout layout;
  final TimesheetDocumentLayout pagedLayout;
  final CutId cutId;
  final BrushToolState brushToolState;
  final HistoryManager historyManager;

  /// The live panel viewport (the same transform the document painter
  /// applies).
  final CanvasViewport viewport;

  /// Raised while any window has a stroke in progress, so the panel's
  /// gesture layer holds navigation exactly as it does for canvas strokes.
  final ValueNotifier<bool> strokeActive;

  final CacheInvalidationSink? cacheInvalidationSink;

  @override
  Widget build(BuildContext context) {
    final windows = timesheetInkWindows(
      layout: layout,
      pagedLayout: pagedLayout,
      cutId: cutId,
    );
    final inputSettings = brushToolState.toInputSettings();

    return Stack(
      children: [
        for (final window in windows)
          Positioned.fill(
            child: ClipRect(
              clipper: _WindowRectClipper(window.screenRect(viewport)),
              child: RepaintBoundary(
                child: InteractiveBrushEditCanvasView(
                  key: ValueKey<String>('timesheet-ink-${window.id}'),
                  sessionState: controller.sessionStateFor(
                    window.plane,
                    window.key,
                  ),
                  layerId: window.key.layerId,
                  frameId: window.key.frameId,
                  inputSettings: inputSettings,
                  viewport: window.inkViewport(viewport),
                  // The sheet paper is painted below this stack; an opaque
                  // background here would cover it.
                  showTransparentBackground: false,
                  onActiveStrokeChanged: (active) {
                    strokeActive.value = active;
                  },
                  onSourceStrokeCommitted: (strokeData) {
                    controller.commitStroke(
                      plane: window.plane,
                      key: window.key,
                      strokeData: strokeData,
                      historyManager: historyManager,
                      cacheInvalidationSink: cacheInvalidationSink,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WindowRectClipper extends CustomClipper<Rect> {
  const _WindowRectClipper(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(covariant _WindowRectClipper oldClipper) =>
      oldClipper.rect != rect;
}
