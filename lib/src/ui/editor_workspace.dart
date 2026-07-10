import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../models/brush_preset.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/layer_id.dart';
import '../services/brush_preset_file_service.dart';
import 'brush/brush_preset_library.dart';
import 'brush/brush_preset_panel.dart';
import 'brush/brush_settings_panel.dart';
import 'brush/brush_tool_state.dart';
import 'color/color_wheel_panel.dart';
import 'brush/tools_panel.dart';
import 'camera/camera_panel.dart';
import 'editor_canvas_area.dart';
import 'editor_session_manager.dart';
import 'export/ae_keyframe_data.dart';
import 'export/export_frame_renderer.dart';
import 'export/export_plan.dart';
import 'media/media_browser_panel.dart';
import 'panels/editor_dock_host.dart';
import 'panels/editor_panel_dock.dart';
import 'panels/editor_panel_layout.dart';
import 'panels/editor_panel_tabs.dart';
import 'panels/workspace_layout_store.dart';
import 'panels/workspace_panels_menu.dart';
import 'storyboard_cut_thumbnail_store.dart';
import 'storyboard_playhead_mapping.dart';
import 'timeline/timeline_section_policy.dart';
import '../models/onion_skin_settings.dart';
import '../services/color_palette_file_service.dart';
import 'color/color_palette_strip.dart';
import 'panels/onion_skin_panel.dart';
import 'storyboard_tab_host.dart';
import '../models/canvas_viewport.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart' show TimelinePanel;
import 'timeline_tab_host.dart';
import 'timesheet/timesheet_ink_controller.dart';
import 'timesheet_tab_host.dart';

/// The editor workspace: side docks and the canvas' center dock over the
/// bottom dock, plus the slim edge docks that home the PS/CSP-style tool
/// bar (left OR right — left-handed choice). Every panel, the canvas and
/// the tool bar included, is a tab in one dock section of an
/// [EditorPanelLayoutModel]; tabs drag between docks with Photoshop/AE
/// style drop feedback (hover lights up the region the panel would take),
/// docks resize via splitters, and the whole arrangement persists to the
/// app-data workspace file.
///
/// This widget is the COMMON OWNER of all dockable-panel view state (brush
/// tool, preset library, camera view, timeline view state): a panel keeps
/// working wherever its tab is docked. Hot values (slider drags, zooms) are
/// ValueNotifiers consumed per-tab, so dragging a brush slider never
/// rebuilds the timeline and vice versa; this widget itself only rebuilds
/// on layout changes.
class EditorWorkspace extends StatefulWidget {
  const EditorWorkspace({
    super.key,
    required this.session,
    this.presetFileService,
    this.brushFilePicker,
    this.layoutStore,
    this.panelsMenu,
    this.brushTool,
  });

  final EditorSessionManager session;

  /// The active-tool notifier, owned by the shell (HomePage) so the tool
  /// shortcuts (B/E) and the workspace panels drive one state. Null keeps
  /// a workspace-local notifier (focused widget tests).
  final ValueNotifier<BrushToolState>? brushTool;

  /// Injectable preset persistence; defaults to the app-data preset file.
  final BrushPresetFileService? presetFileService;

  /// Injectable workspace-layout persistence; defaults to the app-data
  /// layout file outside tests (`FLUTTER_TEST` disables it so widget tests
  /// never read a developer's saved arrangement).
  final WorkspaceLayoutStore? layoutStore;

  /// Injectable brush-file picker; defaults to the platform file dialog.
  final BrushFilePicker? brushFilePicker;

  /// The AppBar's Panels menu bridge: lists every panel with visibility
  /// and reopens closed (X-ed) ones.
  final WorkspacePanelsMenuController? panelsMenu;

  static const double bottomPanelHeight = 350;
  static const double sideDockWidth = 260;

  static const String leftGroupId = 'left';
  static const String rightGroupId = 'right';
  static const String centerGroupId = 'center';
  static const String bottomGroupId = 'bottom';

  /// The slim edge docks homing the vertical tool bar (one per workspace
  /// edge; only narrow-fit panels may dock there).
  static const String toolLeftGroupId = 'tool-left';
  static const String toolRightGroupId = 'tool-right';

  static const String toolsTabId = 'tools';
  static const String canvasTabId = 'canvas';
  static const String brushesTabId = 'brushes';
  static const String brushSettingsTabId = 'brush-settings';
  static const String colorWheelTabId = 'color-wheel';
  static const String onionSkinTabId = 'onion-skin';
  static const String cameraTabId = 'camera';
  static const String mediaTabId = 'media';
  static const String timelineTabId = 'timeline';
  static const String storyboardTabId = 'storyboard';
  static const String timesheetTabId = 'timesheet';

  /// The size frame-axis panels lay out at when docked somewhere smaller
  /// (their label rails and toolbars assume a wide region); the tab shell
  /// hosts them inside scrollers then.
  static const double _frameAxisMinContentWidth = 640;
  static const double _frameAxisMinContentHeight = 280;

  @override
  State<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends State<EditorWorkspace> {
  /// The factory-default arrangement (also the validation baseline when a
  /// saved layout is restored: it names every known tab and its home dock).
  static Map<String, List<DockSection>> _defaultDocks() => {
    EditorWorkspace.toolLeftGroupId: [
      DockSection(tabs: [EditorWorkspace.toolsTabId]),
    ],
    EditorWorkspace.toolRightGroupId: <DockSection>[],
    EditorWorkspace.leftGroupId: [
      DockSection(
        tabs: [
          EditorWorkspace.brushesTabId,
          EditorWorkspace.brushSettingsTabId,
          EditorWorkspace.colorWheelTabId,
          EditorWorkspace.cameraTabId,
          EditorWorkspace.mediaTabId,
          // Trailing so the long-standing tab positions (and every test
          // tapping them) stay put; the strip scrolls to reach it.
          EditorWorkspace.onionSkinTabId,
        ],
        activeTabId: EditorWorkspace.brushesTabId,
      ),
    ],
    EditorWorkspace.rightGroupId: <DockSection>[],
    EditorWorkspace.centerGroupId: [
      DockSection(tabs: [EditorWorkspace.canvasTabId]),
    ],
    EditorWorkspace.bottomGroupId: [
      DockSection(
        tabs: [
          EditorWorkspace.timelineTabId,
          EditorWorkspace.storyboardTabId,
          EditorWorkspace.timesheetTabId,
        ],
        activeTabId: EditorWorkspace.timelineTabId,
      ),
    ],
  };

  /// Only narrow-fit panels may live in the slim edge docks.
  static const Set<String> _edgeDockTabIds = {EditorWorkspace.toolsTabId};

  late final EditorPanelLayoutModel _layout = EditorPanelLayoutModel(
    docks: _defaultDocks(),
  );

  /// The tab in flight (null = none) — docks reveal their drop zones for
  /// an eligible tab only while this is set.
  final ValueNotifier<EditorPanelTabDragData?> _draggingTab = ValueNotifier(
    null,
  );

  /// Drag-locked tabs (the canvas by default: a stray drag must not undock
  /// the drawing surface — unlock via the lock glyph on its tab).
  Set<String> _lockedTabIds = {EditorWorkspace.canvasTabId};

  /// Layout persistence: null in tests (see [EditorWorkspace.layoutStore]).
  WorkspaceLayoutStore? _layoutStore;
  Timer? _layoutSaveTimer;

  /// Keeps the canvas element (and its viewport state) alive when the
  /// canvas tab re-docks.
  final GlobalKey _canvasAreaKey = GlobalKey();

  late final ValueNotifier<BrushToolState> _brushTool =
      widget.brushTool ?? ValueNotifier(BrushToolState.defaults);

  /// The color wheel's spare (background) slot; the foreground IS the
  /// brush color. Held here so it survives tab switches.
  final ValueNotifier<int> _colorWheelBackground = ValueNotifier(0xFFFFFFFF);

  /// The pinned palette + recent colors (P4), persisted app-side.
  final ValueNotifier<ColorPaletteState> _colorPalette = ValueNotifier(
    const ColorPaletteState(),
  );
  ColorPaletteFileService? _paletteService;

  void _setColorPalette(ColorPaletteState next) {
    _colorPalette.value = next;
    unawaited(_paletteService?.save(next));
  }

  void _recordRecentColor() {
    _setColorPalette(
      _colorPalette.value.withRecentColor(_brushTool.value.color),
    );
  }

  late final BrushPresetLibrary _presetLibrary;

  /// Camera view mode: overlay shown with the outside dimmed.
  final ValueNotifier<bool> _cameraViewEnabled = ValueNotifier(false);
  final ValueNotifier<double> _cameraDimOpacity = ValueNotifier(0.5);

  final ValueNotifier<TimelineOrientation> _timelineOrientation = ValueNotifier(
    TimelineOrientation.horizontal,
  );

  // One shared zoom slider drives whichever view is shown; the values are
  // kept per view so each keeps a sensible default scale.
  final ValueNotifier<double> _timelinePixelsPerFrame = ValueNotifier(
    TimelinePanel.defaultPixelsPerFrame,
  );
  final ValueNotifier<double> _storyboardPixelsPerFrame = ValueNotifier(8);

  /// Shared frames↔seconds display toggle (conte-sheet 초+コマ notation).
  final ValueNotifier<bool> _showSecondsDisplay = ValueNotifier(false);

  /// Layers whose AE-style property-lane twirl-down is open (view state —
  /// survives tab switches, session-only).
  final ValueNotifier<Set<LayerId>> _expandedLaneLayerIds = ValueNotifier(
    const <LayerId>{},
  );

  void _toggleLayerLanes(LayerId layerId) {
    final next = Set<LayerId>.of(_expandedLaneLayerIds.value);
    if (!next.remove(layerId)) {
      next.add(layerId);
    }
    _expandedLaneLayerIds.value = next;
  }

  /// Layers whose Transform GROUP is twirled open inside the twirl-down
  /// (AE group collapse — default collapsed; view state, survives tab
  /// switches, session-only).
  final ValueNotifier<Set<LayerId>> _expandedTransformGroupLayerIds =
      ValueNotifier(const <LayerId>{});

  void _toggleTransformGroup(LayerId layerId) {
    final next = Set<LayerId>.of(_expandedTransformGroupLayerIds.value);
    if (!next.remove(layerId)) {
      next.add(layerId);
    }
    _expandedTransformGroupLayerIds.value = next;
  }

  /// SE/camera timeline sections hidden from the grids (view state —
  /// survives tab switches, session-only; toggled from the timeline
  /// toolbar, the retired fold/collapse UI's replacement).
  final ValueNotifier<Set<TimelineSection>> _hiddenTimelineSections =
      ValueNotifier(const <TimelineSection>{});

  void _toggleTimelineSection(TimelineSection section) {
    final next = Set<TimelineSection>.of(_hiddenTimelineSections.value);
    if (!next.remove(section)) {
      next.add(section);
    }
    _hiddenTimelineSections.value = next;
  }

  /// Timesheet tab view state: paper page-split ⟷ continuous, the sheet
  /// viewport (zoom/pan) and the sheet-ink allow toggle — owned here so
  /// they survive tab switches.
  final ValueNotifier<bool> _timesheetContinuous = ValueNotifier(false);
  final ValueNotifier<CanvasViewport?> _timesheetViewport = ValueNotifier(null);
  final ValueNotifier<bool> _timesheetInkEnabled = ValueNotifier(true);

  /// Sheet ink stores (S2 annotations) — owned here so freehand memos
  /// survive tab switches; separate from the session's cel stroke store.
  final TimesheetInkController _timesheetInk = TimesheetInkController();

  late final StoryboardCutThumbnailStore _storyboardThumbnails;

  @override
  void initState() {
    super.initState();
    _presetLibrary = BrushPresetLibrary(
      fileService: widget.presetFileService,
      filePicker: widget.brushFilePicker,
    );
    unawaited(_presetLibrary.load());
    _paletteService = Platform.environment['FLUTTER_TEST'] == 'true'
        ? null
        : ColorPaletteFileService();
    unawaited(
      _paletteService?.loadOrDefaults().then((palette) {
        if (mounted) {
          _colorPalette.value = palette;
        }
      }),
    );
    // Recent colors record on COMMITTED work (history changes) — the color
    // actually drawn with, not every wheel drag sample (P4).
    widget.session.historyManager.addListener(_recordRecentColor);
    _storyboardThumbnails = StoryboardCutThumbnailStore(
      render: _renderStoryboardThumbnail,
      invalidationHub: widget.session.cacheInvalidationHub,
    );
    _layoutStore =
        widget.layoutStore ??
        (Platform.environment['FLUTTER_TEST'] == 'true'
            ? null
            : WorkspaceLayoutStore());
    unawaited(_restoreLayout());
    _layout.addListener(_scheduleLayoutSave);
    widget.panelsMenu?.attach(
      entriesProvider: _panelMenuEntries,
      toggler: _togglePanelVisibility,
      relay: _layout,
      layoutReset: _resetWorkspaceLayout,
    );
  }

  /// Window > Reset Workspace Layout: back to the factory docks, extents
  /// and locks (the debounced save persists the reset like any edit).
  void _resetWorkspaceLayout() {
    setState(() {
      _lockedTabIds = {EditorWorkspace.canvasTabId};
    });
    _mutatingLayout(() {
      _layout.restore(docks: _defaultDocks());
    });
  }

  /// Every known panel in default-dock order, with its live visibility.
  List<WorkspacePanelEntry> _panelMenuEntries() => [
    for (final sections in _defaultDocks().values)
      for (final section in sections)
        for (final tabId in section.tabs)
          (
            tabId: tabId,
            label: _tabFor(tabId).label,
            visible: _layout.locateTab(tabId) != null,
          ),
  ];

  String _defaultDockOf(String tabId) {
    for (final entry in _defaultDocks().entries) {
      for (final section in entry.value) {
        if (section.tabs.contains(tabId)) {
          return entry.key;
        }
      }
    }
    return EditorWorkspace.leftGroupId;
  }

  void _closeTab(String tabId) {
    _mutatingLayout(() => _layout.removeTab(tabId));
  }

  void _togglePanelVisibility(String tabId) {
    if (_layout.locateTab(tabId) != null) {
      _closeTab(tabId);
    } else {
      _mutatingLayout(() {
        _layout.addTab(tabId, toDockId: _defaultDockOf(tabId));
      });
    }
  }

  Future<void> _restoreLayout() async {
    final store = _layoutStore;
    if (store == null) {
      return;
    }
    final payload = await store.load();
    if (payload == null || !mounted) {
      return;
    }
    final restored = restoreWorkspaceLayout(
      payload: payload,
      defaults: _defaultDocks(),
    );
    if (restored == null || !mounted) {
      return;
    }
    setState(() {
      _lockedTabIds = restored.lockedTabIds;
      _layout.restore(docks: restored.docks, dockExtents: restored.dockExtents);
    });
  }

  /// Debounced fire-and-forget save: layout changes come in bursts (drags,
  /// splitter moves) and persistence must never block or crash the editor.
  void _scheduleLayoutSave() {
    final store = _layoutStore;
    if (store == null) {
      return;
    }
    _layoutSaveTimer?.cancel();
    _layoutSaveTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(
        store
            .save({
              'layout': _layout.toJson(),
              'lockedTabs': _lockedTabIds.toList(),
              // Closed panels stay closed across restarts (restore only
              // returns tabs missing WITHOUT this marker to their docks —
              // i.e. panels added by an update).
              'hiddenTabs': [
                for (final entry in _panelMenuEntries())
                  if (!entry.visible) entry.tabId,
              ],
            })
            .catchError((Object _) {}),
      );
    });
  }

  @override
  void dispose() {
    widget.session.historyManager.removeListener(_recordRecentColor);
    _colorPalette.dispose();
    _storyboardThumbnails.dispose();
    _presetLibrary.dispose();
    // An injected tool notifier belongs to the shell; only a local
    // fallback is ours to dispose.
    if (widget.brushTool == null) {
      _brushTool.dispose();
    }
    _colorWheelBackground.dispose();
    _cameraViewEnabled.dispose();
    _cameraDimOpacity.dispose();
    _timelineOrientation.dispose();
    _timelinePixelsPerFrame.dispose();
    _storyboardPixelsPerFrame.dispose();
    _showSecondsDisplay.dispose();
    _expandedLaneLayerIds.dispose();
    _expandedTransformGroupLayerIds.dispose();
    _hiddenTimelineSections.dispose();
    _timesheetContinuous.dispose();
    _timesheetViewport.dispose();
    _timesheetInkEnabled.dispose();
    _timesheetInk.dispose();
    _draggingTab.dispose();
    widget.panelsMenu?.detach();
    _layoutSaveTimer?.cancel();
    _layout.removeListener(_scheduleLayoutSave);
    _layout.dispose();
    super.dispose();
  }

  /// Thumbnails render the cut's thumbnail frame THROUGH THE CAMERA (what
  /// the shot actually frames — conte-sheet style), scaled to a small
  /// output; always current (a fresh renderer replays surfaces straight
  /// from the brush store).
  Future<ui.Image?> _renderStoryboardThumbnail(Cut cut) {
    const thumbnailWidth = 128;
    final cameraSize = widget.session.cameraFrameSize;
    final height = math.max(
      1,
      (thumbnailWidth * cameraSize.height / cameraSize.width).round(),
    );
    // The pinned frame when set (clamped so a later trim never breaks it),
    // the first frame otherwise.
    final frameIndex = (cut.metadata.thumbnailFrameIndex ?? 0)
        .clamp(0, math.max(0, cut.duration - 1))
        .toInt();
    return ExportFrameRenderer(session: widget.session).renderComposite(
      ExportFrameTask(cut: cut, frameIndex: frameIndex),
      ExportSizeMode.camera,
      outputSize: CanvasSize(width: thumbnailWidth, height: height),
    );
  }

  /// Copies the active cut's camera work to the clipboard as AE keyframe
  /// data (baked per frame; paste onto the canvas-sequence layer in a
  /// camera-frame-sized comp).
  void _copyCameraAeKeyframes() {
    final session = widget.session;
    final cut = session.activeCut;
    final cameraSize = session.cameraFrameSize;
    final text = buildAeTransformKeyframeData(
      framesPerSecond: session.projectFps,
      sourceWidth: cameraSize.width,
      sourceHeight: cameraSize.height,
      samples: bakeCameraAeSamples(
        camera: cut.camera,
        canvasSize: cut.canvasSize,
        frameCount: session.activeCutPlaybackFrameCount,
      ),
    );
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera keyframes copied for After Effects.'),
      ),
    );
  }

  void _applyPreset(BrushPreset preset) {
    // The stabilizer is a hand-feel setting, not preset payload (P7): it
    // carries over unchanged when a preset applies.
    _brushTool.value = BrushToolState.fromBrushSettings(
      preset.settings,
    ).copyWith(stabilizerStrength: _brushTool.value.stabilizerStrength);
    _presetLibrary.markActive(preset.id);
  }

  Future<void> _importBrushFile() async {
    final message = await _presetLibrary.importFromFile();
    if (message == null || !mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Whether the storyboard tab is the active tab of any section (visible
  /// on screen).
  bool get _isStoryboardVisible =>
      _layout.activeTabs.contains(EditorWorkspace.storyboardTabId);

  /// Runs a layout mutation and clamps the playhead when the storyboard
  /// just came on screen (over-end playheads on non-last cuts must land
  /// back on the counter frame — timeline parity).
  void _mutatingLayout(VoidCallback mutate) {
    final wasVisible = _isStoryboardVisible;
    mutate();
    if (!wasVisible && _isStoryboardVisible) {
      clampPlayheadForStoryboard(widget.session);
    }
  }

  void _toggleTabLock(String tabId) {
    setState(() {
      if (!_lockedTabIds.remove(tabId)) {
        _lockedTabIds.add(tabId);
      }
    });
    _scheduleLayoutSave();
  }

  EditorPanelTab _tabFor(String tabId) {
    final locked = _lockedTabIds.contains(tabId);
    switch (tabId) {
      case EditorWorkspace.toolsTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Tools',
          icon: Icons.handyman_outlined,
          locked: locked,
          builder: (context) => ValueListenableBuilder<BrushToolState>(
            valueListenable: _brushTool,
            builder: (context, toolState, _) => ToolsPanel(
              tool: toolState.tool,
              onToolChanged: (tool) {
                _brushTool.value = _brushTool.value.copyWith(tool: tool);
              },
            ),
          ),
        );
      case EditorWorkspace.canvasTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Canvas',
          icon: Icons.image_outlined,
          locked: locked,
          builder: (context) => EditorCanvasArea(
            key: _canvasAreaKey,
            session: widget.session,
            brushToolState: _brushTool,
            cameraViewEnabled: _cameraViewEnabled,
            cameraDimOpacity: _cameraDimOpacity,
            expandedLaneLayerIds: _expandedLaneLayerIds,
          ),
        );
      case EditorWorkspace.brushesTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Brushes',
          icon: Icons.brush_outlined,
          locked: locked,
          builder: (context) => ListenableBuilder(
            listenable: _presetLibrary,
            builder: (context, _) => BrushPresetPanel(
              presets: _presetLibrary.presets,
              selectedPresetId: _presetLibrary.activePresetId,
              onPresetApplied: _applyPreset,
              onPresetSaveRequested: () {
                _presetLibrary.saveCurrent(_brushTool.value.toBrushSettings());
              },
              onPresetDeleted: _presetLibrary.delete,
              onPresetRenamed: _presetLibrary.rename,
              onPresetsReordered: _presetLibrary.reorder,
              onPresetImportRequested: () {
                unawaited(_importBrushFile());
              },
            ),
          ),
        );
      case EditorWorkspace.brushSettingsTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Brush Settings',
          icon: Icons.tune,
          locked: locked,
          builder: (context) => ValueListenableBuilder<BrushToolState>(
            valueListenable: _brushTool,
            builder: (context, toolState, _) => BrushSettingsPanel(
              state: toolState,
              onChanged: (state) => _brushTool.value = state,
            ),
          ),
        );
      case EditorWorkspace.colorWheelTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Color',
          icon: Icons.palette_outlined,
          locked: locked,
          builder: (context) => ValueListenableBuilder<BrushToolState>(
            valueListenable: _brushTool,
            builder: (context, toolState, _) => ValueListenableBuilder<int>(
              valueListenable: _colorWheelBackground,
              builder: (context, background, _) => Column(
                children: [
                  Expanded(
                    child: ColorWheelPanel(
                      color: toolState.color,
                      backgroundColor: background,
                      onColorChanged: (color) =>
                          _brushTool.value = toolState.copyWith(color: color),
                      onBackgroundColorChanged: (color) =>
                          _colorWheelBackground.value = color,
                    ),
                  ),
                  // The palette rows (P4) sit under the wheel; squat
                  // panels scroll them instead of overflowing.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: ValueListenableBuilder<ColorPaletteState>(
                        valueListenable: _colorPalette,
                        builder: (context, palette, _) => ColorPaletteStrip(
                          palette: palette,
                          currentColor: toolState.color,
                          onColorSelected: (color) => _brushTool.value =
                              toolState.copyWith(color: color),
                          onPaletteChanged: _setColorPalette,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case EditorWorkspace.onionSkinTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Onion Skin',
          icon: Icons.layers_outlined,
          locked: locked,
          builder: (context) => ValueListenableBuilder<OnionSkinSettings>(
            valueListenable: widget.session.onionSkinSettings,
            builder: (context, settings, _) => OnionSkinPanel(
              settings: settings,
              onChanged: (next) =>
                  widget.session.onionSkinSettings.value = next,
            ),
          ),
        );
      case EditorWorkspace.cameraTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Camera',
          icon: Icons.videocam_outlined,
          locked: locked,
          builder: (context) => ListenableBuilder(
            // The session subscription lives HERE now (HomePage no longer
            // setStates the world); the pose readout additionally tracks
            // committed seeks, which are no longer session notifies.
            listenable: Listenable.merge([
              widget.session,
              widget.session.frameSeekCommitted,
              _cameraViewEnabled,
              _cameraDimOpacity,
            ]),
            builder: (context, _) => CameraPanel(
              cameraViewEnabled: _cameraViewEnabled.value,
              onCameraViewChanged: (enabled) {
                _cameraViewEnabled.value = enabled;
              },
              dimOpacity: _cameraDimOpacity.value,
              onDimOpacityChanged: (opacity) {
                _cameraDimOpacity.value = opacity;
              },
              isCameraLayerActive: widget.session.isCameraLayerActive,
              pose: widget.session.cameraPoseAtCurrentFrame,
              hasKeyframeAtCurrentFrame:
                  widget.session.hasCameraKeyframeAtCurrentFrame,
              onPoseCommitted: widget.session.setCameraKeyframeAtCurrentFrame,
              onRemoveKeyframe:
                  widget.session.removeCameraKeyframeAtCurrentFrame,
              onCopyAeKeyframes: _copyCameraAeKeyframes,
            ),
          ),
        );
      case EditorWorkspace.mediaTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Media',
          icon: Icons.library_music_outlined,
          locked: locked,
          builder: (context) => ListenableBuilder(
            listenable: widget.session,
            builder: (context, _) => MediaBrowserPanel(
              assets: widget.session.mediaAssets,
              isAssetReferenced: widget.session.isMediaAssetReferenced,
              onImportPaths: widget.session.addMediaAssets,
              onRenameAsset: widget.session.renameMediaAsset,
              onRelinkAsset: widget.session.relinkMediaAsset,
              onRemoveAsset: widget.session.removeMediaAsset,
            ),
          ),
        );
      case EditorWorkspace.timelineTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Timeline',
          icon: Icons.view_timeline_outlined,
          // The legacy mode-toggle keys stay on the tab buttons so every
          // existing flow (and test helper) keeps working.
          buttonKey: const ValueKey<String>('timeline-mode-timeline-button'),
          minContentWidth: EditorWorkspace._frameAxisMinContentWidth,
          minContentHeight: EditorWorkspace._frameAxisMinContentHeight,
          locked: locked,
          builder: (context) => ListenableBuilder(
            // The session subscription lives HERE now (HomePage no longer
            // setStates the world). Seeks are NOT session notifies — the
            // grids ride the frame cursor and never rebuild for them.
            listenable: Listenable.merge([
              widget.session,
              _timelineOrientation,
              _timelinePixelsPerFrame,
              _showSecondsDisplay,
              _expandedLaneLayerIds,
              _expandedTransformGroupLayerIds,
              _hiddenTimelineSections,
            ]),
            builder: (context, _) => TimelineTabHost(
              session: widget.session,
              orientation: _timelineOrientation.value,
              onOrientationChanged: (orientation) {
                _timelineOrientation.value = orientation;
              },
              pixelsPerFrame: _timelinePixelsPerFrame.value,
              onPixelsPerFrameChanged: (value) {
                _timelinePixelsPerFrame.value = value;
              },
              showSeconds: _showSecondsDisplay.value,
              onShowSecondsChanged: (show) {
                _showSecondsDisplay.value = show;
              },
              expandedLaneLayerIds: _expandedLaneLayerIds.value,
              onToggleLayerLanes: _toggleLayerLanes,
              expandedTransformGroupLayerIds:
                  _expandedTransformGroupLayerIds.value,
              onToggleTransformGroup: _toggleTransformGroup,
              hiddenSections: _hiddenTimelineSections.value,
              onToggleSection: _toggleTimelineSection,
              // Unified layer controls: the camera row's visibility/opacity
              // drive the same camera-view state as the canvas overlay and
              // the camera panel.
              cameraViewEnabled: _cameraViewEnabled,
              cameraDimOpacity: _cameraDimOpacity,
            ),
          ),
        );
      case EditorWorkspace.storyboardTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Storyboard',
          icon: Icons.movie_outlined,
          buttonKey: const ValueKey<String>('timeline-mode-storyboard-button'),
          minContentWidth: EditorWorkspace._frameAxisMinContentWidth,
          minContentHeight: EditorWorkspace._frameAxisMinContentHeight,
          locked: locked,
          builder: (context) => ListenableBuilder(
            // Session subscription (see the timeline tab) + COMMITTED
            // seeks only (W4 perf pass): scrub moves and playback ticks
            // ride the host's playhead notifier straight into the panel's
            // playhead overlay + ruler — the panel never rebuilds per
            // tick anymore.
            listenable: Listenable.merge([
              widget.session,
              widget.session.frameSeekCommitted,
              _storyboardPixelsPerFrame,
              _showSecondsDisplay,
              _storyboardThumbnails,
            ]),
            builder: (context, _) => StoryboardTabHost(
              session: widget.session,
              pixelsPerFrame: _storyboardPixelsPerFrame.value,
              onPixelsPerFrameChanged: (value) {
                _storyboardPixelsPerFrame.value = value;
              },
              showSeconds: _showSecondsDisplay.value,
              onShowSecondsChanged: (show) {
                _showSecondsDisplay.value = show;
              },
              thumbnailFor: _storyboardThumbnails.thumbnailFor,
            ),
          ),
        );
      case EditorWorkspace.timesheetTabId:
        return EditorPanelTab(
          id: tabId,
          label: 'Timesheet',
          icon: Icons.table_chart_outlined,
          locked: locked,
          builder: (context) => ListenableBuilder(
            listenable: Listenable.merge([
              _timesheetContinuous,
              _timesheetViewport,
              _timesheetInkEnabled,
              _brushTool,
            ]),
            builder: (context, _) => TimesheetTabHost(
              session: widget.session,
              continuous: _timesheetContinuous.value,
              onContinuousChanged: (continuous) {
                _timesheetContinuous.value = continuous;
              },
              viewport: _timesheetViewport.value,
              onViewportChanged: (viewport) {
                _timesheetViewport.value = viewport;
              },
              inkController: _timesheetInk,
              brushToolState: _brushTool.value,
              inkEnabled: _timesheetInkEnabled.value,
              onInkEnabledChanged: (enabled) {
                _timesheetInkEnabled.value = enabled;
              },
            ),
          ),
        );
      default:
        throw ArgumentError.value(tabId, 'tabId', 'Unknown panel tab');
    }
  }

  bool _canDockAccept(String dockId, EditorPanelTabDragData data) {
    // The slim edge docks only host narrow-fit panels (the tool bar);
    // everything else docks anywhere.
    if ((dockId == EditorWorkspace.toolLeftGroupId ||
            dockId == EditorWorkspace.toolRightGroupId) &&
        !_EditorWorkspaceState._edgeDockTabIds.contains(data.tabId)) {
      return false;
    }
    return _layout.canMoveTab(tabId: data.tabId, toDockId: dockId);
  }

  /// A dock's stacked sections with the PS/AE-style drop feedback.
  Widget _buildDockHost(String dockId, {bool compact = false}) {
    return EditorDockHost(
      layout: _layout,
      dockId: dockId,
      tabResolver: _tabFor,
      draggingTab: _draggingTab,
      compact: compact,
      canAcceptTab: (data) => _canDockAccept(dockId, data),
      onTabSelected: (sectionIndex, tabId) => _mutatingLayout(() {
        _layout.selectTab(dockId, sectionIndex, tabId);
      }),
      onTabMovedToSection: (data, sectionIndex, insertIndex) =>
          _mutatingLayout(() {
            _layout.moveTabToSection(
              tabId: data.tabId,
              toDockId: dockId,
              toSectionIndex: sectionIndex,
              insertIndex: insertIndex,
            );
          }),
      onTabMovedToNewSection: (data, atSectionIndex) => _mutatingLayout(() {
        _layout.moveTabToNewSection(
          tabId: data.tabId,
          toDockId: dockId,
          atSectionIndex: atSectionIndex,
        );
      }),
      onTabDragChanged: (data) => _draggingTab.value = data,
      onToggleLock: _toggleTabLock,
      onCloseTab: _closeTab,
    );
  }

  void _dropIntoEmptyDock(String dockId, EditorPanelTabDragData data) {
    _mutatingLayout(() {
      _layout.moveTabToNewSection(
        tabId: data.tabId,
        toDockId: dockId,
        atSectionIndex: 0,
      );
    });
  }

  EditorDockDropZone _emptyDockZone(
    String dockId,
    Axis axis, {
    bool expandToFill = false,
  }) {
    return EditorDockDropZone(
      dockId: dockId,
      axis: axis,
      draggingTab: _draggingTab,
      canAcceptTab: (data) => _canDockAccept(dockId, data),
      expandToFill: expandToFill,
      onDropped: (data) => _dropIntoEmptyDock(dockId, data),
    );
  }

  /// A slim edge dock homing the vertical tool bar on either workspace
  /// edge (left-handed choice); collapsed when empty.
  Widget _buildEdgeDock(String dockId, EditorPanelDockSide side) {
    if (_layout.sectionsIn(dockId).isEmpty) {
      return _emptyDockZone(dockId, Axis.vertical);
    }
    return EditorPanelDock.filled(
      side: side,
      width: ToolsPanel.dockWidth,
      dockId: dockId,
      child: _buildDockHost(dockId, compact: true),
    );
  }

  /// A side dock: full tab dock when populated, collapsed otherwise (a
  /// glowing drop rail appears while an eligible tab is in flight).
  /// [width] is the extent AFTER the workspace clamped both side docks to
  /// what the window can actually spare.
  Widget _buildSideDock(
    String dockId,
    EditorPanelDockSide side, {
    required double width,
  }) {
    if (_layout.sectionsIn(dockId).isEmpty) {
      return _emptyDockZone(dockId, Axis.vertical);
    }
    return EditorPanelDock.filled(
      side: side,
      width: width,
      // Panel names stay visible in every dock (the strip scrolls when
      // they overflow); only the slim edge docks go icon-only.
      child: _buildDockHost(dockId),
    );
  }

  Widget _buildBottomDock() {
    if (_layout.sectionsIn(EditorWorkspace.bottomGroupId).isEmpty) {
      return _emptyDockZone(EditorWorkspace.bottomGroupId, Axis.horizontal);
    }
    return SizedBox(
      height: _layout.dockExtent(
        EditorWorkspace.bottomGroupId,
        fallback: EditorWorkspace.bottomPanelHeight,
      ),
      child: _buildDockHost(EditorWorkspace.bottomGroupId),
    );
  }

  /// The center dock hosts the canvas tab by default. Unlike the edge
  /// docks it always occupies its region — when emptied it stays a
  /// full-size drop surface.
  Widget _buildCenterDock() {
    if (_layout.sectionsIn(EditorWorkspace.centerGroupId).isEmpty) {
      return _emptyDockZone(
        EditorWorkspace.centerGroupId,
        Axis.vertical,
        expandToFill: true,
      );
    }
    return _buildDockHost(EditorWorkspace.centerGroupId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _layout,
      builder: (context, _) {
        final hasLeftDock = _layout
            .sectionsIn(EditorWorkspace.leftGroupId)
            .isNotEmpty;
        final hasRightDock = _layout
            .sectionsIn(EditorWorkspace.rightGroupId)
            .isNotEmpty;
        final hasBottomDock = _layout
            .sectionsIn(EditorWorkspace.bottomGroupId)
            .isNotEmpty;
        return Row(
          children: [
            // The edge docks span the FULL workspace height; the bottom
            // dock runs between them.
            _buildEdgeDock(
              EditorWorkspace.toolLeftGroupId,
              EditorPanelDockSide.left,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // The side docks keep their saved extents but may
                        // never squeeze the canvas out: scale both down
                        // proportionally when the window can't fit them.
                        const minCenterWidth = 120.0;
                        var leftWidth = hasLeftDock
                            ? _layout.dockExtent(
                                EditorWorkspace.leftGroupId,
                                fallback: EditorWorkspace.sideDockWidth,
                              )
                            : 0.0;
                        var rightWidth = hasRightDock
                            ? _layout.dockExtent(
                                EditorWorkspace.rightGroupId,
                                fallback: EditorWorkspace.sideDockWidth,
                              )
                            : 0.0;
                        final splitters =
                            (hasLeftDock ? DockEdgeSplitter.thickness : 0) +
                            (hasRightDock ? DockEdgeSplitter.thickness : 0);
                        final room =
                            (constraints.maxWidth - splitters - minCenterWidth)
                                .clamp(0.0, double.infinity);
                        final wanted = leftWidth + rightWidth;
                        if (wanted > room && wanted > 0) {
                          final scale = room / wanted;
                          leftWidth *= scale;
                          rightWidth *= scale;
                        }
                        return Row(
                          children: [
                            _buildSideDock(
                              EditorWorkspace.leftGroupId,
                              EditorPanelDockSide.left,
                              width: leftWidth,
                            ),
                            if (hasLeftDock)
                              DockEdgeSplitter(
                                key: const ValueKey<String>('dock-resize-left'),
                                axis: Axis.vertical,
                                onDragDelta: (delta) => _layout.resizeDock(
                                  EditorWorkspace.leftGroupId,
                                  delta,
                                  fallback: EditorWorkspace.sideDockWidth,
                                ),
                              ),
                            Expanded(child: _buildCenterDock()),
                            if (hasRightDock)
                              DockEdgeSplitter(
                                key: const ValueKey<String>(
                                  'dock-resize-right',
                                ),
                                axis: Axis.vertical,
                                onDragDelta: (delta) => _layout.resizeDock(
                                  EditorWorkspace.rightGroupId,
                                  -delta,
                                  fallback: EditorWorkspace.sideDockWidth,
                                ),
                              ),
                            _buildSideDock(
                              EditorWorkspace.rightGroupId,
                              EditorPanelDockSide.right,
                              width: rightWidth,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (hasBottomDock)
                    DockEdgeSplitter(
                      key: const ValueKey<String>('dock-resize-bottom'),
                      axis: Axis.horizontal,
                      onDragDelta: (delta) => _layout.resizeDock(
                        EditorWorkspace.bottomGroupId,
                        -delta,
                        fallback: EditorWorkspace.bottomPanelHeight,
                      ),
                    ),
                  _buildBottomDock(),
                ],
              ),
            ),
            _buildEdgeDock(
              EditorWorkspace.toolRightGroupId,
              EditorPanelDockSide.right,
            ),
          ],
        );
      },
    );
  }
}
