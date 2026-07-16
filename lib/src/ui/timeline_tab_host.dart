import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../models/camera_instruction.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import 'dialogs/camera_key_dialog.dart';
import 'dialogs/delete_layer_dialog.dart';
import 'dialogs/frame_name_conflict_dialog.dart';
import 'dialogs/instruction_event_dialog.dart';
import 'dialogs/instruction_set_editor_dialog.dart';
import 'dialogs/rename_frame_dialog.dart';
import 'dialogs/rename_layer_dialog.dart';
import 'dialogs/se_instance_dialog.dart';
import 'editor_session_manager.dart';
import 'playback/canvas_playback_controller.dart';
import 'playback/playback_transport_controls.dart';
import '../models/transform_track.dart';
import '../services/camera_pose_resolver.dart';
import 'timeline/camera_key_edit.dart';
import 'timeline/property_lane_model.dart';
import 'timeline/se_audio_lane.dart';
import 'timeline/timeline_action_toolbar.dart';
import 'timeline/timeline_frame_range_gesture.dart';
import 'timeline/timeline_run_end_handles.dart';
import 'timeline/timeline_exposure_comma_drag_policy.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart';
import 'timeline/timeline_layer_controls_header.dart' show LayerLegendCallbacks;
import 'timeline/timeline_row_filter.dart';
import 'timeline/timeline_section_bracket_rail.dart'
    show TimelineSectionRailCallbacks;
import 'timeline/timeline_section_policy.dart';
import 'timeline/transform_lane_editing.dart';
import 'timeline/transform_lane_policy.dart';

/// The Timeline tab's content: the timeline panel with its transport, cell
/// action toolbar and the layer/frame dialogs it triggers. All wiring lives
/// HERE (not in HomePage) so parallel work on other panels stays in other
/// files.
class TimelineTabHost extends StatefulWidget {
  const TimelineTabHost({
    super.key,
    required this.session,
    required this.orientation,
    required this.onOrientationChanged,
    required this.pixelsPerFrame,
    this.pixelsPerFrameListenable,
    required this.onPixelsPerFrameChanged,
    required this.showSeconds,
    required this.onShowSecondsChanged,
    this.expandedLaneLayerIds = const {},
    this.onToggleLayerLanes,
    this.expandedTransformGroupLayerIds = const {},
    this.onToggleTransformGroup,
    this.hiddenSections = const {},
    this.onToggleSection,
    this.rowFilter = TimelineRowFilter.none,
    this.onSetRowFilter,
    this.audioFilePicker,
    this.cameraViewEnabled,
    this.cameraDimOpacity,
  });

  final EditorSessionManager session;
  final TimelineOrientation orientation;
  final ValueChanged<TimelineOrientation> onOrientationChanged;
  final double pixelsPerFrame;

  /// Zoom scoping (UI-R6 #4): when provided, ONLY the panel subtree
  /// rebuilds per zoom step (the workspace shell and this host's build
  /// stay out of the loop). [pixelsPerFrame] is the fallback for hosts
  /// without the notifier.
  final ValueListenable<double>? pixelsPerFrameListenable;
  final ValueChanged<double> onPixelsPerFrameChanged;
  final bool showSeconds;
  final ValueChanged<bool> onShowSecondsChanged;

  /// AE-style property-lane twirl-down state (host-owned so it survives
  /// tab switches).
  final Set<LayerId> expandedLaneLayerIds;
  final ValueChanged<LayerId>? onToggleLayerLanes;

  /// Layers whose Transform GROUP is twirled open (AE group collapse —
  /// default collapsed; host-owned so the per-layer state survives tab
  /// switches).
  final Set<LayerId> expandedTransformGroupLayerIds;
  final ValueChanged<LayerId>? onToggleTransformGroup;

  /// SE/camera section visibility (host-owned, survives tab switches):
  /// hidden sections render no rows; the toolbar buttons toggle them.
  final Set<TimelineSection> hiddenSections;
  final ValueChanged<TimelineSection>? onToggleSection;

  /// The rail's row filter (host-owned, survives tab switches): hides
  /// layer rows failing its predicate. Null [onSetRowFilter] hides the
  /// filter UI.
  final TimelineRowFilter rowFilter;
  final ValueChanged<TimelineRowFilter>? onSetRowFilter;

  /// Injectable for tests; defaults to the platform open-file dialog.
  final Future<String?> Function()? audioFilePicker;

  /// Unified layer controls: the CAMERA row's visibility button and opacity
  /// slider drive the camera-view overlay state (workspace-owned notifiers,
  /// shared with the canvas and the camera panel). Null keeps the camera
  /// row's controls on the plain layer flags.
  final ValueNotifier<bool>? cameraViewEnabled;
  final ValueNotifier<double>? cameraDimOpacity;

  @override
  State<TimelineTabHost> createState() => _TimelineTabHostState();
}

class _TimelineTabHostState extends State<TimelineTabHost> {
  EditorSessionManager get _session => widget.session;

  /// The frame cursor the panel's cursor-driven widgets subscribe to
  /// (playhead, rulers, lane values, frame counter). Playback ticks and
  /// editing seeks land HERE — never as a panel rebuild; that is the whole
  /// playback-performance architecture.
  late final ValueNotifier<int> _frameCursor = ValueNotifier<int>(
    _session.currentFrameIndex,
  );

  void _syncFrameCursor() {
    final playbackGlobalFrame =
        _session.playback.globalFrameIndexListenable.value;
    _frameCursor.value = playbackGlobalFrame == null
        ? _session.currentFrameIndex
        : _session.playback.position?.localFrameIndex ??
              _session.currentFrameIndex;
  }

  @override
  void initState() {
    super.initState();
    _session.playback.globalFrameIndexListenable.addListener(_syncFrameCursor);
    // Scrub moves fire the editing cursor WITHOUT a session notify — this
    // listener is what keeps the playhead glued to the pointer.
    _session.editingFrameCursor.addListener(_syncFrameCursor);
    _session.addListener(_syncFrameCursor);
  }

  @override
  void dispose() {
    _session.playback.globalFrameIndexListenable.removeListener(
      _syncFrameCursor,
    );
    _session.editingFrameCursor.removeListener(_syncFrameCursor);
    _session.removeListener(_syncFrameCursor);
    _frameCursor.dispose();
    super.dispose();
  }

  /// Every kind's twirl-down lanes — the SAME AE Transform lanes on truly
  /// every layer (unified layer controls): the camera rides the cut camera
  /// track, every other kind its own layer track (applied at composite
  /// time; SE transforms move the canvas dialogue, instruction transforms
  /// are authored state for parity). SE layers append their audio lane.
  /// Folds every OTHER hideable section (the bracket flyout's 'only this
  /// section'); the target unfolds if it was hidden.
  void _soloSection(TimelineSection section) {
    final onToggle = widget.onToggleSection;
    if (onToggle == null) {
      return;
    }
    for (final other in TimelineSection.values) {
      if (!timelineSectionHideable(other)) {
        continue;
      }
      final shouldHide = other != section;
      final isHidden = widget.hiddenSections.contains(other);
      if (shouldHide != isHidden) {
        onToggle(other);
      }
    }
  }

  List<PropertyLaneRow> _lanesForLayer(Layer layer) {
    // Attach rows ride their BASE's transform/opacity lanes (W5 fx
    // sharing) — no lanes of their own in v1.
    if (layer.attachedToLayerId != null) {
      return const [];
    }
    switch (layer.kind) {
      case LayerKind.camera:
        final cut = _session.activeCut;
        return _collapsibleTransformGroup(
          layer,
          transformPropertyLanes(
            cut.camera.track,
            poseAt: (frameIndex) => resolveCameraPoseAt(
              camera: cut.camera,
              canvasSize: cut.canvasSize,
              frameIndex: frameIndex,
            ),
          ),
        );
      case LayerKind.se:
        // Audio controls lead the SE twirl-down (the row's main tool); the
        // Transform group sits below, collapsed by default.
        return [
          ...seAudioLanesFor(layer),
          ..._collapsibleTransformGroup(layer, _layerTransformLanes(layer)),
        ];
      case LayerKind.animation:
      case LayerKind.art:
      case LayerKind.storyboard:
      case LayerKind.instruction:
        return _collapsibleTransformGroup(layer, _layerTransformLanes(layer));
    }
  }

  /// The full AE Transform group — Anchor Point / Position / Scale /
  /// Rotation / Opacity — identical on EVERY layer-track kind (R6-④:
  /// SE/instruction match the drawing layers exactly; unified feel is the
  /// point, per user).
  List<PropertyLaneRow> _layerTransformLanes(Layer layer) {
    return transformPropertyLanes(
      layer.transformTrack,
      includeAnchorAndOpacity: true,
      poseAt: (frameIndex) => _session.layerPoseAtFrame(layer, frameIndex),
      anchorAt: (frameIndex) =>
          _session.layerAnchorPointAtFrame(layer, frameIndex),
      opacityAt: (frameIndex) =>
          _session.layerOpacityAtFrame(layer, frameIndex),
    );
  }

  /// AE group collapse: the Transform group header always shows; its
  /// member lanes only while the layer's group is twirled open (default
  /// collapsed, host-owned per layer so it survives tab switches).
  List<PropertyLaneRow> _collapsibleTransformGroup(
    Layer layer,
    List<PropertyLaneRow> group,
  ) {
    final expanded = widget.expandedTransformGroupLayerIds.contains(layer.id);
    return [
      transformGroupHeader(expanded: expanded),
      if (expanded) ...group.where((lane) => !lane.isGroupHeader),
    ];
  }

  /// The track a layer's transform lanes edit: the camera rides the cut's
  /// camera track, every other kind its own layer track.
  TransformTrack _laneTrackOf(Layer layer) => layer.kind == LayerKind.camera
      ? _session.activeCut.camera.track
      : layer.transformTrack;

  /// Commits an edited transform track as one undo step, dispatched by
  /// kind (camera → cut camera, drawing layers → the layer's own track).
  void _commitLaneEdit(Layer layer, TransformTrack? next, String description) {
    if (next == null) {
      return;
    }
    // Track-owned SE rows: their display clones strip the transform track
    // (global keys cannot render at cut-local lane positions), so a
    // clone-based commit would plant LOCAL-frame keys on the GLOBAL
    // layer. SE transform-lane editing stands down until the lane path
    // converts through the cut window.
    if (_session.isTrackSeLayerId(layer.id)) {
      return;
    }
    if (layer.kind == LayerKind.camera) {
      _session.updateActiveCutCameraTrack(next, description: description);
      return;
    }
    _session.updateLayerTransformTrack(
      layer.id,
      next,
      description: description,
    );
  }

  PropertyLaneEditCallbacks get _laneEdit => PropertyLaneEditCallbacks(
    onToggleKeyAt: (layer, lane, frameIndex) {
      final isCamera = layer.kind == LayerKind.camera;
      _commitLaneEdit(
        layer,
        transformTrackWithLaneKeyToggled(
          _laneTrackOf(layer),
          laneId: lane.laneId,
          frameIndex: frameIndex,
          // The navigator toggles at the playhead: freeze the property's
          // CURRENT resolved value there (AE behavior).
          resolvedPose: isCamera
              ? _session.cameraPoseAtCurrentFrame
              : _session.layerPoseAtFrame(layer, frameIndex),
          resolvedAnchorPoint: isCamera
              ? null
              : _session.layerAnchorPointAtFrame(layer, frameIndex),
          resolvedOpacity: isCamera
              ? 1
              : _session.layerOpacityAtFrame(layer, frameIndex),
        ),
        '${lane.label} keyframe at frame ${frameIndex + 1}',
      );
    },
    onMoveKey: (layer, lane, fromFrame, toFrame) {
      _commitLaneEdit(
        layer,
        transformTrackWithLaneKeyMoved(
          _laneTrackOf(layer),
          laneId: lane.laneId,
          fromFrame: fromFrame,
          toFrame: toFrame,
        ),
        'Move ${lane.label} keyframe to frame ${toFrame + 1}',
      );
    },
    onRemoveKey: (layer, lane, frameIndex) {
      _commitLaneEdit(
        layer,
        transformTrackWithLaneKeyRemoved(
          _laneTrackOf(layer),
          laneId: lane.laneId,
          frameIndex: frameIndex,
        ),
        'Delete ${lane.label} keyframe',
      );
    },
    onToggleHold: (layer, lane, frameIndex) {
      _commitLaneEdit(
        layer,
        transformTrackWithLaneHoldToggled(
          _laneTrackOf(layer),
          laneId: lane.laneId,
          frameIndex: frameIndex,
        ),
        'Toggle hold on ${lane.label} keyframe',
      );
    },
    onSetValue: (layer, lane, frameIndex, input) {
      // The SE audio lane's value field edits the playhead span's offset
      // trim instead of a transform property (one undo via the session).
      if (laneIsSeAudio(lane)) {
        final offset = parseAudioOffsetInput(input);
        final span = seAudioSpanForLaneValue(layer, frameIndex);
        if (offset == null || span == null) {
          return;
        }
        _session.setAudioClipOffset(layer.id, span.clipIndex, offset);
        return;
      }
      _commitLaneEdit(
        layer,
        transformTrackWithLaneValueEdited(
          _laneTrackOf(layer),
          laneId: lane.laneId,
          frameIndex: frameIndex,
          input: input,
        ),
        'Set ${lane.label} at frame ${frameIndex + 1}',
      );
    },
  );

  Future<void> _deleteActiveLayer() async {
    final activeLayer = _session.activeLayer;
    if (activeLayer == null || !_session.canDeleteActiveLayer) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteLayerDialog(layerName: activeLayer.name),
    );
    if (!mounted || shouldDelete != true) {
      return;
    }

    _session.deleteActiveLayer();
  }

  Future<void> _renameActiveLayer() async {
    final activeLayer = _session.activeLayer;
    if (activeLayer == null) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => RenameLayerDialog(initialName: activeLayer.name),
    );
    if (!mounted || nextName == null) {
      return;
    }

    _session.renameActiveLayer(nextName);
  }

  /// THE unified instance-edit entrance (double-tap on any cell, and the
  /// toolbar's Edit Instance button), dispatched by row kind: drawing
  /// kinds edit the frame name, SE its name/dialogue, instruction its
  /// event, camera its keys at the frame.
  Future<void> _activateCellEditor(LayerId layerId, int frameIndex) async {
    final layer = _session.activeLayer;
    if (layer == null || layer.id != layerId) {
      return;
    }
    switch (layer.kind) {
      case LayerKind.se:
        await _editSeLabel();
      case LayerKind.instruction:
        await _editInstructionEvent(layerId, frameIndex);
      case LayerKind.camera:
        await _editCameraKeys(frameIndex);
      case LayerKind.animation || LayerKind.storyboard || LayerKind.art:
        await _renameSelectedFrame();
    }
  }

  /// Toolbar 'Edit Instance': the same entrance at the playhead.
  Future<void> _editActiveInstance() async {
    final layer = _session.activeLayer;
    if (layer == null) {
      return;
    }
    await _activateCellEditor(layer.id, _session.currentFrameIndex);
  }

  /// Toolbar 'Add' — kind-dispatched creation: drawing kinds create a
  /// frame, camera keys the current pose, SE/instruction open their
  /// dialog first (dialog-first, one undo on commit).
  Future<void> _createActiveInstance() async {
    final layer = _session.activeLayer;
    if (layer == null) {
      return;
    }
    switch (layer.kind) {
      case LayerKind.camera:
        _session.setCameraKeyframeAtCurrentFrame(
          _session.cameraPoseAtCurrentFrame,
        );
      case LayerKind.se:
        await _editSeLabel();
      case LayerKind.instruction:
        await _editInstructionEvent(layer.id, _session.currentFrameIndex);
      case LayerKind.animation || LayerKind.storyboard || LayerKind.art:
        _session.createDrawingAtCurrentFrame();
    }
  }

  /// Camera cells: per-lane key/value/interpolation dialog at the frame;
  /// the edited states fold into ONE track commit (one undo).
  Future<void> _editCameraKeys(int frameIndex) async {
    if (frameIndex < 0) {
      return;
    }
    final cut = _session.activeCut;
    final before = cameraKeyLaneStatesAt(
      cut.camera.track,
      frameIndex: frameIndex,
      resolvedPose: resolveCameraPoseAt(
        camera: cut.camera,
        canvasSize: cut.canvasSize,
        frameIndex: frameIndex,
      ),
    );

    final after = await showDialog<List<CameraKeyLaneState>>(
      context: context,
      builder: (context) =>
          CameraKeyDialog(frameIndex: frameIndex, lanes: before),
    );
    if (!mounted || after == null) {
      return;
    }

    final next = transformTrackWithKeyDialogApplied(
      _session.activeCut.camera.track,
      frameIndex: frameIndex,
      before: before,
      after: after,
    );
    if (next != null) {
      _session.updateActiveCutCameraTrack(
        next,
        description: 'Edit camera keys at frame ${frameIndex + 1}',
      );
    }
  }

  /// The preview inside the instance dialogs follows the visible
  /// orientation (Axis policy in miniature).
  Axis get _previewAxis => widget.orientation == TimelineOrientation.horizontal
      ? Axis.horizontal
      : Axis.vertical;

  /// SE cells: covered cells edit the covering entry's name/dialogue,
  /// empty cells create a ONE-frame entry carrying the entered texts (the
  /// comma grips own the length afterwards, like drawing cels); one undo
  /// each way.
  Future<void> _editSeLabel() async {
    final creating = _session.selectedFrame == null;
    if (creating && !_session.canCreateDrawingAtCurrentFrame) {
      return;
    }

    final result = await showDialog<SeInstanceDialogResult>(
      context: context,
      builder: (context) => SeInstanceDialog(
        creating: creating,
        initialSeName: creating ? '' : _session.selectedFrameSeName ?? '',
        initialDialogue: creating ? '' : _session.selectedFrameName ?? '',
        previewAxis: _previewAxis,
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    final seName = result.seName.isEmpty ? null : result.seName;
    if (creating) {
      _session.createSeEntryAtCurrentFrame(
        name: result.dialogue,
        seName: seName,
        lengthFrames: 1,
      );
    } else {
      // SE edits never hit the link-conflict flow (duplicates allowed).
      _session.updateSelectedSeEntry(dialogue: result.dialogue, seName: seName);
    }
  }

  /// Instruction cells: covered cells edit/delete the covering event, empty
  /// cells add a ONE-frame event (the grips own the length afterwards);
  /// one undo each. The vocabulary editor is reachable from inside the
  /// picker.
  Future<void> _editInstructionEvent(LayerId layerId, int frameIndex) async {
    final covering = _session.instructionSpanAt(layerId, frameIndex);

    final result = await showDialog<InstructionEventDialogResult>(
      context: context,
      builder: (context) => InstructionEventDialog(
        instructionSet: _session.cameraInstructionSet,
        initialInstructionId: covering?.value.instructionId,
        initialText: covering?.value.text,
        initialValueA: covering?.value.valueA,
        initialValueB: covering?.value.valueB,
        initialMemo: covering?.value.memo,
        editing: covering != null,
        onEditInstructionSet: () => _editInstructionSet(context),
        previewAxis: _previewAxis,
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.delete) {
      _session.removeInstructionEventAt(layerId, frameIndex);
      return;
    }
    final instructionId = result.instructionId;
    if (instructionId == null) {
      return;
    }
    _session.upsertInstructionEventAt(
      layerId,
      frameIndex,
      InstructionEvent(
        instructionId: instructionId,
        length: 1,
        text: result.text,
        valueA: result.valueA,
        valueB: result.valueB,
        memo: result.memo,
      ),
      createLengthFrames: 1,
    );
  }

  /// Opens the vocabulary editor and commits the edited set immediately
  /// (its own undo step), so it sticks even when the event dialog is then
  /// cancelled. The already-open picker keeps its old list until reopened.
  Future<void> _editInstructionSet(BuildContext dialogContext) async {
    final edited = await showDialog<CameraInstructionSet>(
      context: dialogContext,
      builder: (context) =>
          InstructionSetEditorDialog(initialSet: _session.cameraInstructionSet),
    );
    if (!mounted || edited == null) {
      return;
    }
    _session.updateCameraInstructionSet(edited);
  }

  /// Imports a sound file onto the active SE layer at the playhead.
  Future<void> _importAudio() async {
    if (!_session.canImportAudioToActiveLayer) {
      return;
    }
    final picker = widget.audioFilePicker ?? _pickAudioFile;
    final path = await picker();
    if (!mounted || path == null) {
      return;
    }
    _session.addAudioClipToActiveSeLayer(path);
  }

  static Future<String?> _pickAudioFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Audio',
          extensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
        ),
      ],
    );
    return file?.path;
  }

  Future<void> _renameSelectedFrame() async {
    if (_session.selectedFrame == null ||
        !_session.canRenameFrameAtCurrentFrame) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameFrameDialog(initialName: _session.selectedFrameName ?? ''),
    );
    if (!mounted || nextName == null) {
      return;
    }

    final conflictingFrameId = _session.renameSelectedFrame(nextName);
    if (conflictingFrameId == null) {
      return;
    }

    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (context) => const FrameNameConflictDialog(),
    );
    if (!mounted || shouldLink != true) {
      return;
    }

    _session.linkSelectedFrame(conflictingFrameId);
  }

  /// Layers as DISPLAYED (unified layer controls): the camera row mirrors
  /// the camera-view overlay state on its visibility icon and opacity
  /// slider — the same notifiers the canvas and the camera panel share.
  List<Layer> _displayLayers() {
    final view = widget.cameraViewEnabled;
    final dim = widget.cameraDimOpacity;
    if (view == null && dim == null) {
      return _session.layers;
    }
    return [
      for (final layer in _session.layers)
        layer.kind == LayerKind.camera
            ? layer.copyWith(
                isVisible: view?.value ?? layer.isVisible,
                opacity: dim?.value ?? layer.opacity,
              )
            : layer,
    ];
  }

  LayerKind? _kindOf(LayerId layerId) {
    for (final layer in _session.layers) {
      if (layer.id == layerId) {
        return layer.kind;
      }
    }
    return null;
  }

  void _toggleLayerVisibility(LayerId layerId) {
    final view = widget.cameraViewEnabled;
    if (view != null && _kindOf(layerId) == LayerKind.camera) {
      view.value = !view.value;
      return;
    }
    _session.toggleLayerVisibility(layerId);
  }

  // Opacity drags preview per move and commit ONE write on release
  // (R4 #4): the camera row's slider is the camera-view dim notifier —
  // already cheap and live, so it applies on both hooks.
  void _previewLayerOpacity(LayerId layerId, double opacity) {
    final dim = widget.cameraDimOpacity;
    if (dim != null && _kindOf(layerId) == LayerKind.camera) {
      dim.value = opacity;
      return;
    }
    _session.previewLayerOpacity(layerId, opacity);
  }

  void _commitLayerOpacity(LayerId layerId, double opacity) {
    final dim = widget.cameraDimOpacity;
    if (dim != null && _kindOf(layerId) == LayerKind.camera) {
      dim.value = opacity;
      return;
    }
    _session.commitLayerOpacity(layerId, opacity);
  }

  @override
  Widget build(BuildContext context) {
    // Playback ticks flow into the frame cursor (see _syncFrameCursor) —
    // NEVER as a panel rebuild: only the cursor-driven widgets (playhead
    // layer, rulers, lane values, counter) subscribe, so the grids'
    // hundreds of cells stay untouched frame to frame. The prerender
    // progress listenable repaints the rulers' green bars the same way.
    // The camera-view notifiers keep the camera row's unified controls
    // live.
    return ListenableBuilder(
      listenable: Listenable.merge([
        ?widget.cameraViewEnabled,
        ?widget.cameraDimOpacity,
      ]),
      builder: (context, _) {
        // Zoom scoping (UI-R6 #4): the toolbar widget is built ONCE per
        // host rebuild and reused across zoom steps — the identical
        // instance lets its transport + ~25 buttons skip rebuilding while
        // the ValueListenableBuilder below re-lays-out just the panel.
        final timelineToolbar = _buildTimelineToolbar();
        Widget buildPanel(
          BuildContext context,
          double pixelsPerFrame,
          Widget? child,
        ) => TimelinePanel(
          layers: _displayLayers(),
          activeLayerId: _session.activeLayerId,
          // Edit drags (comma/trim) preview through the scoped channel: a
          // step rebuilds the dragged row's gate + the cursor overlay only,
          // never this host (the release commit is the one session notify).
          dragPreview: _session.dragPreview,
          frameCursor: _frameCursor,
          cacheProgress: _session.prerenderScheduler.progress,
          isFrameCached: _session.isPlaybackFrameCached,
          playbackFrameCount: _session.activeCutPlaybackFrameCount,
          exposureStateForLayer: _session.exposureStateForLayer,
          frameNameForLayer: _session.frameNameForLayer,
          onSelectLayer: _session.selectLayer,
          // Ruler scrubs during playback SEEK the playback clock instead of
          // moving the (hidden) editing playhead.
          onSelectFrame: (frameIndex) {
            if (_session.playback.isActive) {
              _session.playback.seekToLocalFrame(frameIndex);
            } else {
              _session.selectFrameIndex(frameIndex);
            }
          },
          // Ruler drags: per-move seeks ride the cursor path (value-only —
          // the playhead and the canvas preview follow, nothing rebuilds);
          // the release commits the selection as ONE ordinary seek.
          onScrubFrame: (frameIndex) {
            if (_session.playback.isActive) {
              _session.playback.seekToLocalFrame(frameIndex);
            } else {
              _session.scrubFrameIndex(frameIndex);
            }
          },
          onScrubEnd: () {
            if (!_session.playback.isActive) {
              _session.commitFrameScrub();
            }
          },
          onActivateCell: _activateCellEditor,
          instructionDefById: (instructionId) =>
              _session.cameraInstructionSet.defById(instructionId),
          audioPeaksFor: _session.audioPeaksStore.peaksFor,
          onRemoveAudioClip: _session.removeAudioClipAt,
          // Media-browser drops: link the dragged sound to the block.
          onDropMediaAsset: (layerId, blockStartFrame, path) =>
              _session.linkMediaAssetToSeBlock(
                layerId: layerId,
                blockStartFrame: blockStartFrame,
                path: path,
              ),
          // The audio lane's slide edit (the clip's offset trim), edge
          // fade handles and gain dialog. The slide previews LOCALLY in the
          // lane span (its own painter, no session traffic per move) and
          // commits ONE undo on release — the repo-live drag session
          // rebuilt every panel per move and made the slide feel heavy
          // (R5-⑧); the session drag API stays for callers that need the
          // cross-panel mirror.
          onSetAudioClipOffset: _session.setAudioClipOffset,
          onSetAudioClipFades: (layerId, clipIndex, fadeIn, fadeOut) =>
              _session.setAudioClipFades(
                layerId,
                clipIndex,
                fadeInFrames: fadeIn,
                fadeOutFrames: fadeOut,
              ),
          onSetAudioClipGain: _session.setAudioClipGain,
          onAddLayer: _session.addLayer,
          onToggleLayerMuted: _session.toggleLayerMuted,
          // Kind-dispatched (unified layer controls): the camera row drives
          // the camera-view notifiers, every other row the layer flags.
          onToggleLayerVisibility: _toggleLayerVisibility,
          onLayerOpacityChanged: _previewLayerOpacity,
          onLayerOpacityChangeEnd: _commitLayerOpacity,
          onToggleLayerTimesheet: _session.toggleLayerTimesheet,
          onToggleLayerFillReference: _session.toggleLayerFillReference,
          onLayerMarkSelected: _session.setLayerMark,
          // The AE-style fx switch: bypasses the layer's transform/FX on
          // every composite route (session view state).
          layerFxEnabledOf: _session.isLayerFxEnabled,
          onToggleLayerFx: _session.toggleLayerFx,
          // Comma edge drags preview live from the session's drag-start
          // snapshot and commit as ONE undo entry on release.
          commaDrag: TimelineCommaDragCallbacks(
            onBegin: (layerId, blockStartIndex, edge) =>
                _session.beginExposureEdgeDrag(
                  layerId: layerId,
                  blockStartIndex: blockStartIndex,
                  edge: edge,
                ),
            onUpdate: _session.updateExposureEdgeDrag,
            onEnd: _session.endExposureEdgeDrag,
            onCancel: _session.cancelExposureEdgeDrag,
          ),
          // TVP-style frame ranges (UI-R8): a cell drag SELECTS a range
          // (block-snapped), a drag starting inside the selection MOVES it
          // — the block-body immediate move's successor, same live-preview
          // + one-undo discipline.
          rangeHooks: TimelineFrameRangeHooks(
            selection: _session.frameRangeSelection,
            onSelectUpdate: (layerId, anchorIndex, headIndex) =>
                _session.updateFrameRangeSelectionDrag(
                  layerId: layerId,
                  anchorIndex: anchorIndex,
                  headIndex: headIndex,
                ),
            onClear: _session.clearFrameRangeSelection,
            move: TimelineRangeMoveCallbacks(
              onBegin: _session.beginFrameRangeMoveDrag,
              onUpdate: ({required frameDelta, targetLayerId}) =>
                  _session.updateFrameRangeMoveDrag(
                    frameDelta: frameDelta,
                    targetLayerId: targetLayerId,
                  ),
              onEnd: _session.endFrameRangeMoveDrag,
              onCancel: _session.cancelFrameRangeMoveDrag,
            ),
          ),
          // The TVP run-edge handles (UI-R8): [+] drags new one-frame
          // drawings onto a run, [↻] drags a live repeat region (ghosts).
          runEdit: TimelineRunEditCallbacks(
            onAddBegin: (layerId, blockStartIndex, {required atEnd}) =>
                _session.beginRunFramesAddDrag(
                  layerId: layerId,
                  blockStartIndex: blockStartIndex,
                  atEnd: atEnd,
                ),
            onAddUpdate: _session.updateRunFramesAddDrag,
            onAddEnd: _session.endRunFramesAddDrag,
            onAddCancel: _session.cancelRunFramesAddDrag,
            onRepeatBegin: (layerId, blockStartIndex, regionId) =>
                _session.beginRepeatRegionDrag(
                  layerId: layerId,
                  blockStartIndex: blockStartIndex,
                  regionId: regionId,
                ),
            onRepeatUpdate: _session.updateRepeatRegionDrag,
            onRepeatEnd: _session.endRepeatRegionDrag,
            onRepeatCancel: _session.cancelRepeatRegionDrag,
          ),
          orientation: widget.orientation,
          onOrientationChanged: widget.onOrientationChanged,
          pixelsPerFrame: pixelsPerFrame,
          onPixelsPerFrameChanged: widget.onPixelsPerFrameChanged,
          showSeconds: widget.showSeconds,
          onShowSecondsChanged: widget.onShowSecondsChanged,
          projectFps: _session.projectFps,
          expandedLaneLayerIds: widget.expandedLaneLayerIds,
          onToggleLayerLanes: widget.onToggleLayerLanes,
          hiddenSections: widget.hiddenSections,
          onToggleSection: widget.onToggleSection,
          rowFilter: widget.rowFilter,
          onSetRowFilter: widget.onSetRowFilter,
          visibilitySoloEnabled: _session.layerVisibilitySoloEnabled,
          // Master-bar drags (UI-R6 #2): rows' sliders follow the preview
          // channel live; at rest the bar shows the last committed value.
          opacityDragPreview: _session.opacityDragPreview,
          masterOpacityValue: _session.lastMasterOpacity,
          // Sounds carrying over from the previous cut (UI-R7 #6): the
          // cut start draws `~` and the spill block's start grip stands
          // down.
          seSpillInLayerIds: _session.trackSeSpillInLayerIds,
          // The rail legend's bulk sweeps + the section brackets' flyout —
          // all session-backed (R-toolbar round); the R2 filter/dim/opacity
          // facets ride the same struct.
          legend: LayerLegendCallbacks(
            onShowAllLayers: () => _session.setAllLayersVisibility(true),
            onHideAllLayers: () => _session.setAllLayersVisibility(false),
            onToggleVisibilitySolo: _session.toggleLayerVisibilitySolo,
            onSheetAllOn: () => _session.setAllLayersOnTimesheet(true),
            onSheetAllOff: () => _session.setAllLayersOnTimesheet(false),
            onClearAllMarks: _session.clearAllLayerMarks,
            onClearAllFillReferences: _session.clearAllFillReferences,
            onMuteAllSe: () => _session.setAllSeLayersMuted(true),
            onUnmuteAllSe: () => _session.setAllSeLayersMuted(false),
            onBypassAllFx: () => _session.setAllLayersFxBypassed(true),
            onEnableAllFx: () => _session.setAllLayersFxBypassed(false),
            onToggleMarkFilter: (mark) =>
                widget.onSetRowFilter?.call(widget.rowFilter.toggledMark(mark)),
            onToggleKindFilter: (kind) =>
                widget.onSetRowFilter?.call(widget.rowFilter.toggledKind(kind)),
            onToggleSheetOnlyFilter: () => widget.onSetRowFilter?.call(
              widget.rowFilter.copyWith(
                onTimesheetOnly: !widget.rowFilter.onTimesheetOnly,
              ),
            ),
            onToggleFxOnlyFilter: () => widget.onSetRowFilter?.call(
              widget.rowFilter.copyWith(fxOnly: !widget.rowFilter.fxOnly),
            ),
            onToggleFillReferenceOnlyFilter: () => widget.onSetRowFilter?.call(
              widget.rowFilter.copyWith(
                fillReferenceOnly: !widget.rowFilter.fillReferenceOnly,
              ),
            ),
            // The legend master bar (R4 #6): preview per move, one commit.
            onPreviewLayersOpacity: _session.previewLayersOpacity,
            onCommitLayersOpacity: _session.commitLayersOpacity,
          ),
          sectionRail: widget.onToggleSection == null
              ? null
              : TimelineSectionRailCallbacks(
                  onToggleSection: widget.onToggleSection!,
                  onAddLayerOfKind: _session.addLayerOfKind,
                  onSetSectionLayersVisibility:
                      _session.setSectionLayersVisibility,
                  onSoloSection: _soloSection,
                ),
          lanesForLayer: _lanesForLayer,
          laneEdit: _laneEdit,
          // The Transform group header's twirl (AE collapse).
          onToggleLaneGroup: widget.onToggleTransformGroup == null
              ? null
              : (layer, lane) => widget.onToggleTransformGroup!(layer.id),
          timelineActionToolbar: timelineToolbar,
        );
        final zoom = widget.pixelsPerFrameListenable;
        if (zoom == null) {
          return buildPanel(context, widget.pixelsPerFrame, null);
        }
        return ValueListenableBuilder<double>(
          valueListenable: zoom,
          builder: buildPanel,
        );
      },
    );
  }

  /// Button enablement reads the playhead, and committed seeks are no
  /// longer session notifies — the toolbar re-reads them here without
  /// the panel (or its grids) rebuilding. TOKEN-GATED (R13-2): the
  /// naive per-seek rebuild reconstructed the whole transport + ~25
  /// Material buttons on every frame flip — measured on device as
  /// the flip hitch. Seeks that land in the same enablement state
  /// (almost all of them) now rebuild nothing.
  Widget _buildTimelineToolbar() {
    return _SeekGatedTimelineToolbar(
      session: _session,
      builder: (context) => Row(
        children: [
          PlaybackTransportControls(
            controller: _session.playback,
            scope: PlaybackScope.activeCut,
            quality: _session.playbackQuality,
            onQualityChanged: _session.setPlaybackQuality,
            playbackStartFrame: () => _session.currentFrameIndex,
          ),
          Expanded(
            child: TimelineActionToolbar(
              session: _session,
              onAddLayer: _session.addLayer,
              onRenameLayer: _renameActiveLayer,
              onDeleteLayer: _deleteActiveLayer,
              onEditInstance: _editActiveInstance,
              onCreateInstance: _createActiveInstance,
              onImportAudio: _importAudio,
              hiddenSections: widget.hiddenSections,
              onToggleSection: widget.onToggleSection,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds the timeline's transport + action toolbar on a committed seek
/// ONLY when the seek changed what the buttons can do (R13-2). The toolbar
/// reads ~a dozen playhead-sensitive `can*` getters; deriving them into a
/// comparison token per seek costs microseconds, while the rebuild it
/// replaces reconstructed every Material button — the frame-flip hitch's
/// toolbar share. Session notifies still refresh the toolbar through the
/// host's ordinary rebuild (this widget re-derives on didUpdateWidget).
class _SeekGatedTimelineToolbar extends StatefulWidget {
  const _SeekGatedTimelineToolbar({
    required this.session,
    required this.builder,
  });

  final EditorSessionManager session;
  final WidgetBuilder builder;

  @override
  State<_SeekGatedTimelineToolbar> createState() =>
      _SeekGatedTimelineToolbarState();
}

class _SeekGatedTimelineToolbarState extends State<_SeekGatedTimelineToolbar> {
  late Object _token = _deriveToken();

  /// Every playhead-sensitive enablement the toolbar's buttons consume.
  /// A new playhead-reading button must join this record — the guard test
  /// pins the gate against the real toolbar.
  Object _deriveToken() {
    final session = widget.session;
    return (
      session.selectedFrame != null,
      session.canCreateDrawingAtCurrentFrame,
      session.canRenameFrameAtCurrentFrame,
      session.canCutExposureAtCurrentFrame,
      session.canToggleMarkAtCurrentFrame,
      session.canCopyFrameAtCurrentFrame,
      session.canPasteLinkedFrameAtCurrentFrame,
      session.canDeleteCellAtCurrentFrame,
      session.canDecreaseSelectedExposure,
      session.canIncreaseSelectedExposure,
    );
  }

  void _handleSeekCommitted() {
    final next = _deriveToken();
    if (next == _token) {
      return;
    }
    setState(() => _token = next);
  }

  @override
  void initState() {
    super.initState();
    widget.session.frameSeekCommitted.addListener(_handleSeekCommitted);
  }

  @override
  void didUpdateWidget(covariant _SeekGatedTimelineToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.frameSeekCommitted.removeListener(_handleSeekCommitted);
      widget.session.frameSeekCommitted.addListener(_handleSeekCommitted);
    }
    _token = _deriveToken();
  }

  @override
  void dispose() {
    widget.session.frameSeekCommitted.removeListener(_handleSeekCommitted);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
