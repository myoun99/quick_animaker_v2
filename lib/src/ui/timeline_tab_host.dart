import 'package:file_selector/file_selector.dart';
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
import 'timeline/timeline_exposure_comma_drag_policy.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart';
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
    required this.onPixelsPerFrameChanged,
    required this.showSeconds,
    required this.onShowSecondsChanged,
    this.expandedLaneLayerIds = const {},
    this.onToggleLayerLanes,
    this.expandedTransformGroupLayerIds = const {},
    this.onToggleTransformGroup,
    this.hiddenSections = const {},
    this.onToggleSection,
    this.audioFilePicker,
    this.cameraViewEnabled,
    this.cameraDimOpacity,
  });

  final EditorSessionManager session;
  final TimelineOrientation orientation;
  final ValueChanged<TimelineOrientation> onOrientationChanged;
  final double pixelsPerFrame;
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
  List<PropertyLaneRow> _lanesForLayer(Layer layer) {
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
        return _collapsibleTransformGroup(
          layer,
          transformPropertyLanes(
            layer.transformTrack,
            // The full AE Transform group on drawing layers: Anchor Point /
            // Position / Scale / Rotation / Opacity (R3 ⑪).
            includeAnchorAndOpacity: true,
            poseAt: (frameIndex) =>
                _session.layerPoseAtFrame(layer, frameIndex),
            anchorAt: (frameIndex) =>
                _session.layerAnchorPointAtFrame(layer, frameIndex),
            opacityAt: (frameIndex) =>
                _session.layerOpacityAtFrame(layer, frameIndex),
          ),
        );
      case LayerKind.instruction:
        return _collapsibleTransformGroup(layer, _layerTransformLanes(layer));
    }
  }

  List<PropertyLaneRow> _layerTransformLanes(Layer layer) {
    return transformPropertyLanes(
      layer.transformTrack,
      poseAt: (frameIndex) => _session.layerPoseAtFrame(layer, frameIndex),
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

  void _setLayerOpacity(LayerId layerId, double opacity) {
    final dim = widget.cameraDimOpacity;
    if (dim != null && _kindOf(layerId) == LayerKind.camera) {
      dim.value = opacity;
      return;
    }
    _session.setLayerOpacity(layerId: layerId, opacity: opacity);
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
      builder: (context, _) => TimelinePanel(
        layers: _displayLayers(),
        activeLayerId: _session.activeLayerId,
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
        // SE empty-stretch wash follows the sheet's project toggle
        // (3-surface rule: sheet, X-sheet and timeline read the same).
        seEmptyFill: _session.timesheetInfo.seEmptyFill,
        // The audio lane's slide edit (the clip's offset trim), edge
        // fade handles and gain dialog. The slide DRAG rides the live
        // session (repo-direct preview — waveforms and blocks follow in
        // real time, one undo on release); the value field keeps the
        // one-shot commit.
        onSetAudioClipOffset: _session.setAudioClipOffset,
        audioOffsetDrag: AudioOffsetDragCallbacks(
          onBegin: (layerId, clipIndex) => _session.beginAudioClipOffsetDrag(
            layerId: layerId,
            clipIndex: clipIndex,
          ),
          onUpdate: _session.updateAudioClipOffsetDrag,
          onEnd: _session.endAudioClipOffsetDrag,
          onCancel: _session.cancelAudioClipOffsetDrag,
        ),
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
        onLayerOpacityChanged: _setLayerOpacity,
        onToggleLayerTimesheet: _session.toggleLayerTimesheet,
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
        orientation: widget.orientation,
        onOrientationChanged: widget.onOrientationChanged,
        pixelsPerFrame: widget.pixelsPerFrame,
        onPixelsPerFrameChanged: widget.onPixelsPerFrameChanged,
        showSeconds: widget.showSeconds,
        onShowSecondsChanged: widget.onShowSecondsChanged,
        projectFps: _session.projectFps,
        expandedLaneLayerIds: widget.expandedLaneLayerIds,
        onToggleLayerLanes: widget.onToggleLayerLanes,
        hiddenSections: widget.hiddenSections,
        lanesForLayer: _lanesForLayer,
        laneEdit: _laneEdit,
        // The Transform group header's twirl (AE collapse).
        onToggleLaneGroup: widget.onToggleTransformGroup == null
            ? null
            : (layer, lane) => widget.onToggleTransformGroup!(layer.id),
        // Button enablement reads the playhead, and committed seeks are no
        // longer session notifies — the toolbar re-reads them here without
        // the panel (or its grids) rebuilding.
        timelineActionToolbar: ListenableBuilder(
          listenable: _session.frameSeekCommitted,
          builder: (context, _) => Row(
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
        ),
      ),
    );
  }
}
