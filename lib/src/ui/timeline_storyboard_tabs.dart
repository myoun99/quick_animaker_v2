import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_size.dart';
import '../models/cut.dart';
import 'editor_session_manager.dart';
import 'export/export_frame_renderer.dart';
import 'export/export_plan.dart';
import 'panels/editor_panel_tabs.dart';
import 'storyboard_cut_thumbnail_store.dart';
import 'storyboard_playhead_mapping.dart';
import 'storyboard_tab_host.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart' show TimelinePanel;
import 'timeline_tab_host.dart';

/// The bottom panel region: Timeline and Storyboard as CSP-style tabs.
///
/// Owns the view state that must survive tab switches (tab selection,
/// per-view zoom, orientation, the frames↔seconds toggle and the thumbnail
/// cache); each tab's WIRING lives in its own host file.
class TimelineStoryboardTabs extends StatefulWidget {
  const TimelineStoryboardTabs({super.key, required this.session});

  final EditorSessionManager session;

  static const double height = 350;

  @override
  State<TimelineStoryboardTabs> createState() => _TimelineStoryboardTabsState();
}

class _TimelineStoryboardTabsState extends State<TimelineStoryboardTabs> {
  static const String _timelineTabId = 'timeline';
  static const String _storyboardTabId = 'storyboard';

  String _activeTabId = _timelineTabId;
  TimelineOrientation _timelineOrientation = TimelineOrientation.horizontal;

  // One shared zoom slider drives whichever view is shown; the values are
  // kept per view so each keeps a sensible default scale.
  double _timelinePixelsPerFrame = TimelinePanel.defaultPixelsPerFrame;
  double _storyboardPixelsPerFrame = 8;

  /// Shared frames↔seconds display toggle (conte-sheet 초+コマ notation).
  bool _showSecondsDisplay = false;

  late final StoryboardCutThumbnailStore _storyboardThumbnails;

  @override
  void initState() {
    super.initState();
    _storyboardThumbnails = StoryboardCutThumbnailStore(
      render: _renderStoryboardThumbnail,
      invalidationHub: widget.session.cacheInvalidationHub,
    )..addListener(_onThumbnailsChanged);
  }

  @override
  void dispose() {
    _storyboardThumbnails.removeListener(_onThumbnailsChanged);
    _storyboardThumbnails.dispose();
    super.dispose();
  }

  void _onThumbnailsChanged() {
    setState(() {});
  }

  /// Thumbnails render the cut's first frame THROUGH THE CAMERA (what the
  /// shot actually frames — conte-sheet style), scaled to a small output;
  /// always current (a fresh renderer replays surfaces straight from the
  /// brush store).
  Future<ui.Image?> _renderStoryboardThumbnail(Cut cut) {
    const thumbnailWidth = 128;
    final cameraSize = widget.session.cameraFrameSize;
    final height = math.max(
      1,
      (thumbnailWidth * cameraSize.height / cameraSize.width).round(),
    );
    return ExportFrameRenderer(session: widget.session).renderComposite(
      ExportFrameTask(cut: cut, frameIndex: 0),
      ExportSizeMode.camera,
      outputSize: CanvasSize(width: thumbnailWidth, height: height),
    );
  }

  void _selectTab(String tabId) {
    if (tabId == _activeTabId) {
      return;
    }
    if (tabId == _storyboardTabId) {
      clampPlayheadForStoryboard(widget.session);
    }
    setState(() => _activeTabId = tabId);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimelineStoryboardTabs.height,
      child: EditorPanelTabs(
        activeTabId: _activeTabId,
        onTabSelected: _selectTab,
        tabs: [
          EditorPanelTab(
            id: _timelineTabId,
            label: 'Timeline',
            icon: Icons.view_timeline_outlined,
            // The legacy mode-toggle keys stay on the tab buttons so every
            // existing flow (and test helper) keeps working.
            buttonKey: const ValueKey<String>('timeline-mode-timeline-button'),
            builder: (context) => TimelineTabHost(
              session: widget.session,
              orientation: _timelineOrientation,
              onOrientationChanged: (orientation) {
                setState(() => _timelineOrientation = orientation);
              },
              pixelsPerFrame: _timelinePixelsPerFrame,
              onPixelsPerFrameChanged: (value) {
                setState(() => _timelinePixelsPerFrame = value);
              },
              showSeconds: _showSecondsDisplay,
              onShowSecondsChanged: (show) {
                setState(() => _showSecondsDisplay = show);
              },
            ),
          ),
          EditorPanelTab(
            id: _storyboardTabId,
            label: 'Storyboard',
            icon: Icons.movie_outlined,
            buttonKey: const ValueKey<String>(
              'timeline-mode-storyboard-button',
            ),
            builder: (context) => StoryboardTabHost(
              session: widget.session,
              pixelsPerFrame: _storyboardPixelsPerFrame,
              onPixelsPerFrameChanged: (value) {
                setState(() => _storyboardPixelsPerFrame = value);
              },
              showSeconds: _showSecondsDisplay,
              onShowSecondsChanged: (show) {
                setState(() => _showSecondsDisplay = show);
              },
              thumbnailFor: _storyboardThumbnails.thumbnailFor,
            ),
          ),
        ],
      ),
    );
  }
}
