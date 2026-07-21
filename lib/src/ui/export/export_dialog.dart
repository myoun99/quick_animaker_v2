import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/export_format_selection.dart';
import '../../models/export_preset.dart';
import '../../models/export_spec.dart';
import '../../services/audio/audio_mixer_reference.dart' show AudioMixSource;
import '../../services/export/xdts_builder.dart';
import '../../services/persistence/app_export_settings.dart';
import '../../services/persistence/app_export_settings_store.dart';
import '../editor_session_manager.dart';
import 'export_audio_mix.dart';
import 'export_frame_renderer.dart';
import 'export_job.dart';
import 'export_nav_bar.dart';
import 'export_plan.dart';
import 'export_preset_rail.dart';
import 'export_preview_engine.dart';
import 'export_queue_column.dart';
import 'export_settings_modules.dart';
import 'png_sequence_export_service.dart';
import 'video_export_service.dart';

/// Picks the output directory (the Browse… button); `null` on cancel.
typedef ExportDirectoryPicker = Future<String?> Function();

Future<String?> _pickExportDirectory() => getDirectoryPath();

/// The v10 export window: five zones (file/location bar → presets |
/// preview | settings | queue → footer), four tabs, location-first flow —
/// Export starts immediately, files land in the chosen location.
///
/// EX2 ships the shell with today's capabilities behind the new grammar
/// (MP4·H.264 / PNG / XDTS); the format lineup, the live preview and the
/// queue runner widen it in later rounds.
class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.session,
    this.exportDirectoryPicker,
    this.videoExportService = const VideoExportService(),
    this.settingsStore,
  });

  final EditorSessionManager session;

  /// Injectable for tests; defaults to the platform directory picker.
  final ExportDirectoryPicker? exportDirectoryPicker;

  /// Injectable for tests; the real one prefers the OS encoder and falls
  /// back to ffmpeg.
  final VideoExportService videoExportService;

  /// Persists presets/last-used state. Null (the test default) keeps the
  /// state in memory only — no test may write the user's real settings.
  final AppExportSettingsStore? settingsStore;

  @override
  State<ExportDialog> createState() => ExportDialogState();
}

class ExportDialogState extends State<ExportDialog> {
  static const _exportService = PngSequenceExportService();

  ExportTab _tab = ExportTab.sequence;
  late ExportTabSpecs _specs;
  String? _location;
  bool _presetsOpen = true;
  bool _queueOpen = true;
  final Map<String, bool> _expanded = {};
  final ExportQueueModel _queue = ExportQueueModel();

  late final TextEditingController _sequenceFileController;
  late final TextEditingController _imageFileController;
  late final TextEditingController _inController = TextEditingController();
  late final TextEditingController _outController = TextEditingController();
  late final TextEditingController _namingBaseController;
  late final TextEditingController _celSuffixController;

  bool _isExporting = false;
  bool _cancelRequested = false;
  String? _statusMessage;
  (int completed, int total)? _progress;

  // EX3: the preview loop — one controller, two renderers (FX on/off; the
  // toggle changes what frames look like, so flipping it clears the cache).
  final ExportPreviewController _preview = ExportPreviewController();
  late ExportFrameRenderer _previewRendererFx;
  late ExportFrameRenderer _previewRendererRaw;
  int _sequencePosition = 0;
  late int _imageFrame;
  int _celPosition = 0;
  static const int _previewMaxWidth = 316;
  static const int _previewMaxHeight = 300;

  EditorSessionManager get _session => widget.session;

  @override
  void initState() {
    super.initState();
    final restored = AppExport.settings.value;
    _specs = restored.lastSpecs;
    _location = restored.lastLocation;
    _presetsOpen = restored.presetsDrawerOpen;
    _queueOpen = restored.queueDrawerOpen;
    final projectName = sanitizeExportFileComponent(
      _session.repository.requireProject().name,
    );
    _sequenceFileController = TextEditingController(text: '$projectName.mp4');
    _imageFileController = TextEditingController(text: '$projectName.png');
    _namingBaseController = TextEditingController(
      text: _specs.sequence.naming.baseName,
    );
    _celSuffixController = TextEditingController(
      text: _specs.cels.naming.suffix,
    );
    _previewRendererFx = ExportFrameRenderer(session: _session);
    _previewRendererRaw = ExportFrameRenderer(
      session: _session,
      applyLayerFx: false,
    );
    _imageFrame = _session.editingFrameCursor.value.clamp(
      0,
      math.max(1, _session.requireActiveCut.duration) - 1,
    );
    _syncControllersFromSpecs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshPreview();
      }
    });
    unawaited(_restoreFromStore());
  }

  Future<void> _restoreFromStore() async {
    final store = widget.settingsStore;
    if (store == null) {
      return;
    }
    final loaded = await store.load();
    if (loaded == null || !mounted) {
      return;
    }
    AppExport.settings.value = loaded;
    setState(() {
      _specs = loaded.lastSpecs;
      _location = loaded.lastLocation ?? _location;
      _presetsOpen = loaded.presetsDrawerOpen;
      _queueOpen = loaded.queueDrawerOpen;
      _syncControllersFromSpecs();
    });
  }

  @override
  void dispose() {
    _sequenceFileController.dispose();
    _imageFileController.dispose();
    _inController.dispose();
    _outController.dispose();
    _namingBaseController.dispose();
    _celSuffixController.dispose();
    _queue.dispose();
    _preview.dispose();
    super.dispose();
  }

  // --- state plumbing -------------------------------------------------------

  void _persist() {
    final next = AppExport.settings.value.copyWith(
      lastSpecs: _specs,
      lastLocation: _location,
      presetsDrawerOpen: _presetsOpen,
      queueDrawerOpen: _queueOpen,
    );
    AppExport.settings.value = next;
    final store = widget.settingsStore;
    if (store != null) {
      unawaited(store.save(next));
    }
  }

  void _updateSpec(ExportTabSpec spec) {
    setState(() => _specs = _specs.withSpec(spec));
    _persist();
    _refreshPreview();
  }

  void _syncControllersFromSpecs() {
    _namingBaseController.text = _specs.sequence.naming.baseName;
    _celSuffixController.text = _specs.cels.naming.suffix;
    _inController.text = _specs.sequence.inFrame == null
        ? ''
        : '${_specs.sequence.inFrame! + 1}';
    _outController.text = _specs.sequence.outFrame == null
        ? ''
        : '${_specs.sequence.outFrame! + 1}';
  }

  bool _expandedFor(String id, {bool fallback = false}) =>
      _expanded['${_tab.jsonValue}:$id'] ?? fallback;

  void _toggleExpanded(String id, {bool fallback = false}) {
    setState(() {
      _expanded['${_tab.jsonValue}:$id'] =
          !_expandedFor(id, fallback: fallback);
    });
  }

  // --- plans ----------------------------------------------------------------

  Cut get _activeCut => _session.requireActiveCut;

  bool _cutInScope(Cut cut) => _session.repository
      .requireProject()
      .exportOverrides
      .cutIncluded(cut.id);

  /// The 0-based in/out marks on the SEQUENCE AXIS (cut-local frames
  /// under the cut scope, whole-track positions under the project scope);
  /// `null` = the fields don't form a valid range right now.
  (int?, int?)? _sequenceInOut() {
    int? parse(TextEditingController controller) {
      final raw = controller.text.trim();
      if (raw.isEmpty) {
        return null;
      }
      final value = int.tryParse(raw);
      return (value == null || value < 1) ? -1 : value - 1;
    }

    final inFrame = parse(_inController);
    final outFrame = parse(_outController);
    if (inFrame == -1 || outFrame == -1) {
      return null;
    }
    if (inFrame != null && outFrame != null && inFrame > outFrame) {
      return null;
    }
    return (inFrame, outFrame);
  }

  /// The FULL sequence axis (untrimmed, gapless): what the nav bar scrubs
  /// and the in/out marks live on.
  List<ExportFrameTask> _sequenceAxisPlan() {
    final spec = _specs.sequence;
    return buildExportFramePlan(
      project: _session.repository.requireProject(),
      activeCutId: _activeCut.id,
      range: spec.scope == ExportScopeKind.project
          ? ExportRange.allCuts
          : ExportRange.activeCut,
    );
  }

  /// The frames an export actually renders: the axis sliced by in/out.
  /// `null` while the fields are invalid. An UNTRIMMED project-scope video
  /// keeps the gap black frames (full-track sync, the old behavior); a
  /// trimmed range is content-only.
  List<ExportFrameTask>? _sequencePlanForRun({required bool video}) {
    final spec = _specs.sequence;
    final inOut = _sequenceInOut();
    if (inOut == null) {
      return null;
    }
    final (inFrame, outFrame) = inOut;
    final untrimmed = inFrame == null && outFrame == null;
    if (video && untrimmed && spec.scope == ExportScopeKind.project) {
      return buildExportFramePlan(
        project: _session.repository.requireProject(),
        activeCutId: _activeCut.id,
        range: ExportRange.allCuts,
        includeGaps: true,
      );
    }
    final axis = _sequenceAxisPlan();
    if (axis.isEmpty) {
      return axis;
    }
    final lo = (inFrame ?? 0).clamp(0, axis.length - 1);
    final hi = (outFrame ?? axis.length - 1).clamp(lo, axis.length - 1);
    return axis.sublist(lo, hi + 1);
  }

  List<ExportCelTask> _celPlan() {
    final spec = _specs.cels;
    final plan = buildExportCelPlan(
      project: _session.repository.requireProject(),
      activeCutId: _activeCut.id,
      range: spec.scope == ExportScopeKind.project
          ? ExportRange.allCuts
          : ExportRange.activeCut,
      naming: spec.naming,
      onTimesheetOnly: spec.onTimesheetOnly,
    );
    // The project-side cut checks trim the project scope (the grid UI
    // arrives with EX5 — the seam is live already).
    return [
      for (final task in plan)
        if (_cutInScope(task.cut)) task,
    ];
  }

  List<Cut> _timesheetCuts() {
    final cuts = resolveExportCuts(
      project: _session.repository.requireProject(),
      activeCutId: _activeCut.id,
      range: _specs.timesheet.scope == ExportScopeKind.project
          ? ExportRange.allCuts
          : ExportRange.activeCut,
    );
    return [
      for (final cut in cuts)
        if (_cutInScope(cut)) cut,
    ];
  }

  Set<CanvasSize> _scopeCanvasSizes(ExportScopeKind scope) {
    return resolveExportCuts(
      project: _session.repository.requireProject(),
      activeCutId: _activeCut.id,
      range: scope == ExportScopeKind.project
          ? ExportRange.allCuts
          : ExportRange.activeCut,
    ).map((cut) => cut.canvasSize).toSet();
  }

  /// The Image tab's frame: the nav bar owns it (seeded from the editing
  /// playhead on open) — what the preview shows IS what exports.
  int _currentImageFrame() {
    final duration = math.max(1, _activeCut.duration);
    return _imageFrame.clamp(0, duration - 1);
  }

  @visibleForTesting
  int get debugImageFrame => _currentImageFrame();

  /// Test seam: awaits the debounced preview render (call inside
  /// `tester.runAsync` so the raster completes).
  @visibleForTesting
  Future<void> debugFlushPreview() => _preview.debugFlushPending();

  /// The 1-based position of [cut] within its track (sheet/XDTS number).
  int _cutNumberOf(Cut cut) {
    for (final track in _session.repository.requireProject().tracks) {
      final index = track.cuts.indexWhere((entry) => entry.id == cut.id);
      if (index != -1) {
        return index + 1;
      }
    }
    return 1;
  }

  String _sequenceFileNameFor(int index) {
    final naming = _specs.sequence.naming;
    final number = '${index + 1}'.padLeft(naming.digits, '0');
    final extension = _specs.sequence.format.stillFormat.fileExtension;
    return '${naming.baseName}_$number.$extension';
  }

  String _plural(int count, String noun) => count == 1 ? noun : '${noun}s';

  // --- preview (EX3) --------------------------------------------------------

  String _celCaption(ExportCelTask task) {
    final number =
        task.frame.name ??
        '${task.layer.frames.indexWhere((frame) => frame.id == task.frame.id) + 1}';
    return '${task.layer.name}-$number';
  }

  ExportNavAxis _sequenceAxis(List<ExportFrameTask> plan) => ExportNavAxis(
    length: plan.length,
    ticks: [
      for (var i = 1; i < plan.length; i += 1)
        if (plan[i].cut.id != plan[i - 1].cut.id) i,
    ],
    captionOf: (position) => 'F${position + 1}',
  );

  ExportNavAxis _imageAxis() => ExportNavAxis(
    length: math.max(1, _activeCut.duration),
    captionOf: (position) => 'F${position + 1}',
  );

  ExportNavAxis _celsAxis(List<ExportCelTask> plan) => ExportNavAxis(
    length: plan.length,
    ticks: [
      for (var i = 1; i < plan.length; i += 1)
        if (plan[i].layer.id != plan[i - 1].layer.id) i,
    ],
    captionOf: (position) => _celCaption(plan[position]),
  );

  /// Re-aims the preview at whatever the tab currently points at. Called
  /// after every spec/nav/tab change; requests coalesce in the controller.
  void _refreshPreview() {
    switch (_tab) {
      case ExportTab.sequence:
        final spec = _specs.sequence;
        final axis = _sequenceAxisPlan();
        if (axis.isEmpty) {
          return;
        }
        _sequencePosition = _sequencePosition.clamp(0, axis.length - 1);
        final task = axis[_sequencePosition];
        _requestCompositePreview(
          task: task,
          sizeMode: spec.sizeMode,
          applyLayerFx: spec.applyLayerFx,
          caption: 'F${_sequencePosition + 1}',
        );
      case ExportTab.image:
        final spec = _specs.image;
        _requestCompositePreview(
          task: ExportFrameTask(
            cut: _activeCut,
            frameIndex: _currentImageFrame(),
          ),
          sizeMode: spec.sizeMode,
          applyLayerFx: spec.applyLayerFx,
          caption: 'F${_currentImageFrame() + 1}',
        );
      case ExportTab.cels:
        final plan = _celPlan();
        if (plan.isEmpty) {
          _preview.clear();
          return;
        }
        _celPosition = _celPosition.clamp(0, plan.length - 1);
        final task = plan[_celPosition];
        final transparent = _specs.cels.format.wantsAlpha;
        _preview.request(
          key: 'cel:${task.cut.id.value}:${task.layer.id.value}:'
              '${task.frame.id.value}:$transparent',
          caption: _celCaption(task),
          render: () =>
              _previewRendererRaw.renderCel(task, transparent: transparent),
        );
      case ExportTab.timesheet:
        // The sheet preview arrives with the Timesheet round.
        break;
    }
  }

  void _requestCompositePreview({
    required ExportFrameTask task,
    required ExportSizeMode sizeMode,
    required bool applyLayerFx,
    required String caption,
  }) {
    final renderer = applyLayerFx ? _previewRendererFx : _previewRendererRaw;
    final source = sizeMode == ExportSizeMode.camera
        ? _session.cameraFrameSize
        : task.cut.canvasSize;
    final fitted = previewOutputSize(
      sourceWidth: source.width,
      sourceHeight: source.height,
      maxWidth: _previewMaxWidth,
      maxHeight: _previewMaxHeight,
    );
    final outputSize = fitted == null
        ? null
        : CanvasSize(width: fitted.width, height: fitted.height);
    _preview.request(
      key: 'frame:${task.cut.id.value}:${task.frameIndex}:'
          '${sizeMode.jsonValue}:$applyLayerFx:'
          '${outputSize?.width ?? source.width}x'
          '${outputSize?.height ?? source.height}',
      caption: caption,
      render: () => task.isGap
          ? Future<ui.Image?>.value()
          : renderer.renderComposite(task, sizeMode, outputSize: outputSize),
    );
  }

  String? _transportLine() {
    switch (_tab) {
      case ExportTab.sequence:
        final axis = _sequenceAxisPlan();
        if (axis.isEmpty) {
          return null;
        }
        final inOut = _sequenceInOut();
        final position = _sequencePosition.clamp(0, axis.length - 1);
        final cutName = axis[position].cut.name;
        if (inOut == null) {
          return 'Invalid in/out · F${position + 1} · $cutName';
        }
        final lo = (inOut.$1 ?? 0) + 1;
        final hi = (inOut.$2 ?? axis.length - 1) + 1;
        return 'in $lo – out $hi (${hi - lo + 1}f) · '
            'F${position + 1} · $cutName';
      case ExportTab.image:
        return 'F${_currentImageFrame() + 1} / '
            '${math.max(1, _activeCut.duration)} · ${_activeCut.name}';
      case ExportTab.cels:
        final plan = _celPlan();
        if (plan.isEmpty) {
          return null;
        }
        final position = _celPosition.clamp(0, plan.length - 1);
        return '${_celCaption(plan[position])} · '
            '${position + 1} / ${plan.length}';
      case ExportTab.timesheet:
        return null;
    }
  }

  // --- summaries ------------------------------------------------------------

  String _planHeadline() {
    switch (_tab) {
      case ExportTab.sequence:
        final spec = _specs.sequence;
        final plan = _sequencePlanForRun(video: spec.format.isVideo);
        if (plan == null) {
          final duration = math.max(1, _activeCut.duration);
          return 'Enter a valid in/out range (1–$duration).';
        }
        final frames = '${plan.length} ${_plural(plan.length, 'frame')}';
        if (spec.sizeMode == ExportSizeMode.camera) {
          final size = _session.cameraFrameSize;
          return '$frames at ${size.width}×${size.height} through the camera.';
        }
        final sizes = _scopeCanvasSizes(spec.scope);
        if (sizes.length == 1) {
          final size = sizes.first;
          return '$frames at ${size.width}×${size.height} (raw canvas).';
        }
        return "$frames at each cut's own canvas size.";
      case ExportTab.image:
        final size = _specs.image.sizeMode == ExportSizeMode.camera
            ? _session.cameraFrameSize
            : _activeCut.canvasSize;
        return 'Frame ${_currentImageFrame() + 1} of ${_activeCut.name} at '
            '${size.width}×${size.height}.';
      case ExportTab.cels:
        final count = _celPlan().length;
        final background = _specs.cels.format.wantsAlpha
            ? 'transparent'
            : 'opaque';
        return '$count ${_plural(count, 'cel')} as $background '
            '${_specs.cels.format.stillFormat.label} files, no compositing.';
      case ExportTab.timesheet:
        final count = _timesheetCuts().length;
        return '$count XDTS ${_plural(count, 'sheet')} '
            '(cels + serifu + camerawork columns).';
    }
  }

  String _outputLine() {
    final location = _location;
    if (location == null || location.isEmpty) {
      return 'Choose a location to enable Export.';
    }
    switch (_tab) {
      case ExportTab.sequence:
        final spec = _specs.sequence;
        if (spec.format.isVideo) {
          return '→ ${_singleFileName(_sequenceFileController, 'mp4')}';
        }
        return '→ ${_sequenceFileNameFor(0)} …';
      case ExportTab.image:
        return '→ ${_singleFileName(_imageFileController, 'png')}';
      case ExportTab.cels:
        final plan = _celPlan();
        return plan.isEmpty ? '→ (no cels)' : '→ ${plan.first.fileName} …';
      case ExportTab.timesheet:
        final cuts = _timesheetCuts();
        return cuts.isEmpty
            ? '→ (no cuts)'
            : '→ CUT${_cutNumberOf(cuts.first)}.xdts'
                  '${cuts.length > 1 ? ' …' : ''}';
    }
  }

  String _singleFileName(TextEditingController controller, String extension) {
    var name = controller.text.trim();
    if (name.isEmpty) {
      name = sanitizeExportFileComponent(
        _session.repository.requireProject().name,
      );
    }
    if (!name.toLowerCase().endsWith('.$extension')) {
      name = '$name.$extension';
    }
    return name;
  }

  bool get _hasLocation => _location != null && _location!.isNotEmpty;

  bool get _canExport {
    if (_isExporting || !_hasLocation) {
      return false;
    }
    switch (_tab) {
      case ExportTab.sequence:
        final plan =
            _sequencePlanForRun(video: _specs.sequence.format.isVideo);
        return plan != null && plan.isNotEmpty;
      case ExportTab.image:
        return true;
      case ExportTab.cels:
        return _celPlan().isNotEmpty;
      case ExportTab.timesheet:
        return _timesheetCuts().isNotEmpty;
    }
  }

  // --- export runners -------------------------------------------------------

  String _joinLocation(String name) =>
      '$_location${Platform.pathSeparator}$name';

  void _reportProgress(int completed, int total) {
    if (mounted) {
      setState(() {
        _progress = (completed, total);
        _statusMessage = 'Exporting… $completed/$total';
      });
    }
  }

  Future<void> _runGuarded(Future<String> Function() run) async {
    setState(() {
      _isExporting = true;
      _cancelRequested = false;
      _statusMessage = 'Exporting…';
    });
    try {
      final message = await run();
      if (mounted) {
        setState(() => _statusMessage = message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Export failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _progress = null;
        });
      }
    }
  }

  /// Public for tests; the Export button is the production entry point.
  Future<void> export() async {
    if (!_canExport) {
      return;
    }
    switch (_tab) {
      case ExportTab.sequence:
        final spec = _specs.sequence;
        if (spec.format.isVideo) {
          await _runGuarded(_exportVideo);
        } else {
          await _runGuarded(_exportPngSequence);
        }
      case ExportTab.image:
        await _runGuarded(_exportCurrentFrame);
      case ExportTab.cels:
        await _runGuarded(_exportCels);
      case ExportTab.timesheet:
        await _runGuarded(_exportXdts);
    }
  }

  Future<String> _exportVideo() async {
    final spec = _specs.sequence;
    final plan = _sequencePlanForRun(video: true)!;
    final renderer = ExportFrameRenderer(
      session: _session,
      applyLayerFx: spec.applyLayerFx,
    );
    final videoPath = _joinLocation(
      _singleFileName(_sequenceFileController, 'mp4'),
    );
    final audioMixPath =
        spec.includeAudio ? await _renderAudioMix(plan) : null;
    try {
      final summary = await widget.videoExportService.exportVideo(
        count: plan.length,
        // Video frames bake the cut fade (H.264 carries no alpha).
        renderImage: (index) =>
            renderer.renderCompositeForVideo(plan[index], spec.sizeMode),
        outputFilePath: videoPath,
        frameRate: _session.projectFrameRate,
        audioMixPath: audioMixPath,
        isCancelled: () => _cancelRequested,
        onProgress: _reportProgress,
      );
      if (summary.processed < plan.length) {
        return summary.written == 0
            ? 'Export cancelled.'
            : 'Export cancelled after ${summary.written} '
                  '${_plural(summary.written, 'frame')} (partial video kept).';
      }
      return 'Exported video (${summary.written} '
          '${_plural(summary.written, 'frame')}).';
    } finally {
      if (audioMixPath != null) {
        try {
          File(audioMixPath).deleteSync();
        } on Object {
          // A leftover temp mix is untidy, not an export failure.
        }
      }
    }
  }

  Future<String> _exportPngSequence() async {
    final spec = _specs.sequence;
    final plan = _sequencePlanForRun(video: false)!;
    final renderer = ExportFrameRenderer(
      session: _session,
      applyLayerFx: spec.applyLayerFx,
    );
    final summary = await _exportService.exportImages(
      count: plan.length,
      renderImage: (index) =>
          renderer.renderComposite(plan[index], spec.sizeMode),
      fileNameFor: _sequenceFileNameFor,
      directoryPath: _location!,
      isCancelled: () => _cancelRequested,
      onProgress: _reportProgress,
    );
    if (summary.processed < plan.length) {
      return 'Export cancelled after ${summary.written} '
          '${_plural(summary.written, 'file')}.';
    }
    return 'Exported ${summary.written} '
        '${_plural(summary.written, 'frame')}.';
  }

  Future<String> _exportCurrentFrame() async {
    final spec = _specs.image;
    final renderer = ExportFrameRenderer(
      session: _session,
      applyLayerFx: spec.applyLayerFx,
    );
    final task = ExportFrameTask(
      cut: _activeCut,
      frameIndex: _currentImageFrame(),
    );
    final fileName = _singleFileName(_imageFileController, 'png');
    final summary = await _exportService.exportImages(
      count: 1,
      renderImage: (_) => renderer.renderComposite(task, spec.sizeMode),
      fileNameFor: (_) => fileName,
      directoryPath: _location!,
      isCancelled: () => _cancelRequested,
      onProgress: _reportProgress,
    );
    return summary.written == 1
        ? 'Exported $fileName.'
        : 'Nothing to export (empty frame).';
  }

  Future<String> _exportCels() async {
    final spec = _specs.cels;
    final plan = _celPlan();
    final renderer = ExportFrameRenderer(
      session: _session,
      applyLayerFx: false,
    );
    final summary = await _exportService.exportImages(
      count: plan.length,
      renderImage: (index) => renderer.renderCel(
        plan[index],
        transparent: spec.format.wantsAlpha,
      ),
      fileNameFor: (index) => plan[index].fileName,
      directoryPath: _location!,
      isCancelled: () => _cancelRequested,
      onProgress: _reportProgress,
    );
    if (summary.processed < plan.length) {
      return 'Export cancelled after ${summary.written} '
          '${_plural(summary.written, 'file')}.';
    }
    final skipped = summary.processed - summary.written;
    final cels = '${summary.written} ${_plural(summary.written, 'cel')}';
    return skipped > 0
        ? 'Exported $cels ($skipped empty skipped).'
        : 'Exported $cels.';
  }

  Future<String> _exportXdts() async {
    final cuts = _timesheetCuts();
    final defById = _session.cameraInstructionSet.defById;
    var written = 0;
    for (final cut in cuts) {
      final content = buildXdtsContent(
        cut: cut,
        cutNumber: _cutNumberOf(cut),
        instructionDefById: defById,
      );
      final file = File(_joinLocation('CUT${_cutNumberOf(cut)}.xdts'));
      await file.parent.create(recursive: true);
      await file.writeAsString(content, flush: true);
      written += 1;
      _reportProgress(written, cuts.length);
    }
    return 'Exported $written XDTS ${_plural(written, 'sheet')}.';
  }

  /// Renders the SE mix to a temp WAV through the same mixer playback
  /// uses; null = nothing audible (video-only encode).
  Future<String?> _renderAudioMix(List<ExportFrameTask> videoPlan) async {
    final schedule = buildExportAudioPlan(
      plan: videoPlan,
      project: _session.repository.requireProject(),
    );
    if (schedule.isEmpty) {
      return null;
    }
    final store = _session.audioConformStore;
    for (final clip in schedule) {
      await store.ensureFor(clip.filePath);
    }
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'qa_export_mix_${DateTime.now().microsecondsSinceEpoch}.wav';
    final written = await writeExportAudioMixWav(
      schedule: schedule,
      rate: _session.projectFrameRate,
      totalFrames: videoPlan.length,
      sampleRate: store.projectSampleRate,
      resolveSource: (filePath) async {
        final entry = await store.ensureFor(filePath);
        final samples = entry != null && entry.isUsable ? entry.samples : null;
        if (samples == null) {
          return null;
        }
        return AudioMixSource(samples: samples, channels: entry!.channels);
      },
      resolveStreamReader: (filePath) =>
          store.isStreaming(filePath) ? store.streamReaderFor(filePath) : null,
      outputPath: path,
      log: debugPrint,
    );
    return written ? path : null;
  }

  void cancelExport() {
    _cancelRequested = true;
  }

  // --- presets --------------------------------------------------------------

  List<ExportPreset> get _tabPresets =>
      AppExport.settings.value.presetsFor(_tab);

  void _applyPreset(ExportPreset preset) {
    setState(() {
      _specs = _specs.withSpec(preset.spec);
      _syncControllersFromSpecs();
    });
    _persist();
    _refreshPreview();
  }

  Future<void> _saveCurrentPreset() async {
    final name = await showExportPresetNameDialog(context);
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    final preset = ExportPreset(
      id: ExportPresetId(
        'preset-${DateTime.now().microsecondsSinceEpoch}',
      ),
      name: name,
      spec: _specs.specFor(_tab),
    );
    final settings = AppExport.settings.value;
    AppExport.settings.value = settings.copyWith(
      presets: [...settings.presets, preset],
    );
    setState(() {});
    _persist();
  }

  void _deletePreset(ExportPreset preset) {
    final settings = AppExport.settings.value;
    AppExport.settings.value = settings.copyWith(
      presets: [
        for (final entry in settings.presets)
          if (entry.id != preset.id) entry,
      ],
    );
    setState(() {});
    _persist();
  }

  // --- build ----------------------------------------------------------------

  Future<void> _browseLocation() async {
    final picker = widget.exportDirectoryPicker ?? _pickExportDirectory;
    final directory = await picker();
    if (directory == null || !mounted) {
      return;
    }
    setState(() => _location = directory);
    _persist();
  }

  bool get _singleFileTab =>
      _tab == ExportTab.image ||
      (_tab == ExportTab.sequence && _specs.sequence.format.isVideo);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The drawers yield before the preview does (v10: 전개 ~1020 /
          // 최소 ~700): a tight surface collapses the queue, then the
          // presets, to presentational strips — the stored preference
          // stays untouched.
          var presetsOpen = _presetsOpen;
          var queueOpen = _queueOpen;
          double widthFor() =>
              (presetsOpen ? 152.0 : 22.0) +
              330 +
              272 +
              (queueOpen ? 200.0 : 22.0) +
              4;
          if (widthFor() > constraints.maxWidth && queueOpen) {
            queueOpen = false;
          }
          if (widthFor() > constraints.maxWidth && presetsOpen) {
            presetsOpen = false;
          }
          final presetsWidth = presetsOpen ? 152.0 : 22.0;
          final queueWidth = queueOpen ? 200.0 : 22.0;
          final width = math.min(widthFor(), constraints.maxWidth);
          final height = math.min(560.0, constraints.maxHeight);

          return SizedBox(
            width: width,
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleBar(theme),
                _tabBar(theme),
                _nameBar(theme),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: presetsWidth,
                        child: _presetsZone(open: presetsOpen),
                      ),
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      Expanded(child: _previewZone(theme)),
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      SizedBox(width: 272, child: _settingsZone()),
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      SizedBox(
                        width: queueWidth,
                        child: _queueZone(open: queueOpen),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                _footer(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _titleBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 0),
      child: Row(
        children: [
          Text(
            'Export',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey<String>('export-close-button'),
            onPressed: _isExporting
                ? null
                : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _tabBar(ThemeData theme) {
    Widget tabButton(ExportTab tab) {
      final selected = _tab == tab;
      final accent = theme.colorScheme.primary;
      return InkWell(
        key: ValueKey<String>('export-tab-${tab.jsonValue}'),
        onTap: _isExporting || selected
            ? null
            : () {
                setState(() => _tab = tab);
                // Tabs share the one preview slot; a stale picture from
                // another domain must not linger under the new axis.
                _preview.clear();
                _refreshPreview();
              },
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 6, 13, 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected ? accent : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            ExportPresetRail.tabLabel(tab),
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? accent : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [for (final tab in ExportTab.values) tabButton(tab)]),
    );
  }

  Widget _nameBar(ThemeData theme) {
    final singleFile = _singleFileTab;
    final controller = _tab == ExportTab.image
        ? _imageFileController
        : _sequenceFileController;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          Text(
            singleFile ? 'File' : 'Pattern',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          if (singleFile)
            SizedBox(
              width: 180,
              child: TextField(
                key: const ValueKey<String>('export-file-name-field'),
                controller: controller,
                enabled: !_isExporting,
                style: theme.textTheme.bodySmall,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            )
          else
            Text(
              _patternPreview(),
              key: const ValueKey<String>('export-pattern-preview'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          const SizedBox(width: 14),
          Text(
            'Location',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _location ?? 'Choose a folder…',
              key: const ValueKey<String>('export-location-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: _hasLocation
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const ValueKey<String>('export-browse-button'),
            onPressed: _isExporting ? null : _browseLocation,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Browse…'),
          ),
        ],
      ),
    );
  }

  String _patternPreview() {
    switch (_tab) {
      case ExportTab.sequence:
        return _sequenceFileNameFor(0);
      case ExportTab.cels:
        final plan = _celPlan();
        return plan.isEmpty ? '(no cels)' : plan.first.fileName;
      case ExportTab.timesheet:
        return 'CUT1.xdts';
      case ExportTab.image:
        return '';
    }
  }

  Widget _presetsZone({required bool open}) {
    if (!open) {
      return ExportDrawerStrip(
        key: const ValueKey<String>('export-presets-strip'),
        caption: 'Presets',
        chevron: Icons.chevron_right,
        onTap: () {
          setState(() => _presetsOpen = true);
          _persist();
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            key: const ValueKey<String>('export-presets-collapse'),
            onTap: () {
              setState(() => _presetsOpen = false);
              _persist();
            },
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.chevron_left, size: 13),
            ),
          ),
        ),
        Expanded(
          child: ExportPresetRail(
            tab: _tab,
            presets: _tabPresets,
            currentSpec: _specs.specFor(_tab),
            enabled: !_isExporting,
            onApply: _applyPreset,
            onSaveCurrent: () => unawaited(_saveCurrentPreset()),
            onDelete: _deletePreset,
          ),
        ),
      ],
    );
  }

  ExportNavBar? _navBar() {
    switch (_tab) {
      case ExportTab.sequence:
        final axis = _sequenceAxis(_sequenceAxisPlan());
        final inOut = _sequenceInOut();
        return ExportNavBar(
          axis: axis,
          position: _sequencePosition,
          enabled: !_isExporting,
          inController: _inController,
          outController: _outController,
          onInOutEdited: _writeInOutToSpec,
          inMark: inOut?.$1,
          outMark: inOut?.$2,
          onChanged: (position) {
            setState(() => _sequencePosition = position);
            _refreshPreview();
          },
        );
      case ExportTab.image:
        return ExportNavBar(
          axis: _imageAxis(),
          position: _currentImageFrame(),
          enabled: !_isExporting,
          onChanged: (position) {
            setState(() => _imageFrame = position);
            _refreshPreview();
          },
        );
      case ExportTab.cels:
        return ExportNavBar(
          axis: _celsAxis(_celPlan()),
          position: _celPosition,
          enabled: !_isExporting,
          onChanged: (position) {
            setState(() => _celPosition = position);
            _refreshPreview();
          },
        );
      case ExportTab.timesheet:
        // The sheet page scrub arrives with the Timesheet round.
        return null;
    }
  }

  Widget _previewZone(ThemeData theme) {
    final progress = _progress;
    final navBar = _navBar();
    final transport = _transportLine();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              // The preview shows the CROPPED RESULT alone (v10: 오버레이
              // 없음) — or the plan headline while nothing has resolved.
              child: AnimatedBuilder(
                animation: _preview,
                builder: (context, _) {
                  final image = _preview.image;
                  if (image == null) {
                    return Text(
                      _planHeadline(),
                      key: const ValueKey<String>('export-plan-headline'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    );
                  }
                  return RawImage(
                    key: const ValueKey<String>('export-preview-image'),
                    image: image,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  );
                },
              ),
            ),
          ),
          if (navBar != null) ...[const SizedBox(height: 6), navBar],
          if (transport != null) ...[
            const SizedBox(height: 3),
            Text(
              transport,
              key: const ValueKey<String>('export-transport-line'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _outputLine(),
            key: const ValueKey<String>('export-output-line'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 10.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress.$2 > 0 ? progress.$1 / progress.$2 : null,
              minHeight: 4,
            ),
          ],
        ],
      ),
    );
  }

  Widget _settingsZone() {
    final children = switch (_tab) {
      ExportTab.sequence => _sequenceModules(),
      ExportTab.image => _imageModules(),
      ExportTab.cels => _celsModules(),
      ExportTab.timesheet => _timesheetModules(),
    };
    // A plain scroll view (not a lazy list): a handful of modules, and
    // collapsed accordions must exist for finders/ensureVisible.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children) ...[
            child,
            const SizedBox(height: exportModuleGap),
          ],
        ],
      ),
    );
  }

  List<Widget> _sequenceModules() {
    final spec = _specs.sequence;
    final projectScope = spec.scope == ExportScopeKind.project;
    return [
      ExportAccordion(
        title: 'Format',
        summary: ExportFormatModule.summarize(spec.format),
        expanded: _expandedFor('format', fallback: true),
        onToggle: () => _toggleExpanded('format', fallback: true),
        resetEnabled: spec.format != const ExportFormatSelection(),
        onReset: () =>
            _updateSpec(spec.copyWith(format: const ExportFormatSelection())),
        child: ExportFormatModule(
          selection: spec.format,
          capabilities: const ExportFormatCapabilities(
            stills: [ExportStillFormat.png],
            video: {
              ExportVideoContainer.mp4: [ExportVideoCodec.h264],
            },
          ),
          enabled: !_isExporting,
          onChanged: (format) => _updateSpec(spec.copyWith(format: format)),
        ),
      ),
      ExportAccordion(
        title: 'Scope',
        summary: ExportScopeModule.summarize(spec.scope),
        expanded: _expandedFor('scope', fallback: true),
        onToggle: () => _toggleExpanded('scope', fallback: true),
        child: ExportScopeModule(
          scope: spec.scope,
          enabled: !_isExporting,
          onChanged: (scope) => _updateSpec(
            spec.copyWith(
              scope: scope,
              // The v10 coupling: a project scope renders through the
              // camera (per-cut canvases cannot make one movie).
              sizeMode: scope == ExportScopeKind.project
                  ? ExportSizeMode.camera
                  : spec.sizeMode,
            ),
          ),
          // The in/out fields live on the nav bar's ends (v10) — the
          // module keeps the scope choice alone.
          note: projectScope
              ? 'No cut list here — in/out alone trims the sequence.'
              : null,
        ),
      ),
      ExportAccordion(
        title: 'Size',
        summary: ExportSizeModule.summarize(spec.sizeMode),
        expanded: _expandedFor('size', fallback: true),
        onToggle: () => _toggleExpanded('size', fallback: true),
        child: ExportSizeModule(
          sizeMode: spec.sizeMode,
          cameraSize: _session.cameraFrameSize,
          canvasSizes: _scopeCanvasSizes(spec.scope),
          projectScope: projectScope,
          enabled: !_isExporting,
          onChanged: (mode) => _updateSpec(spec.copyWith(sizeMode: mode)),
        ),
      ),
      if (spec.format.isVideo)
        ExportAccordion(
          title: 'Audio',
          summary: spec.includeAudio ? 'SE muxed · AAC' : 'Off',
          expanded: _expandedFor('audio'),
          onToggle: () => _toggleExpanded('audio'),
          child: ExportToggleRow(
            widgetKey: const ValueKey<String>('export-audio-toggle'),
            label: 'Mux the SE mix into the video',
            value: spec.includeAudio,
            onChanged: _isExporting
                ? null
                : (value) => _updateSpec(spec.copyWith(includeAudio: value)),
          ),
        ),
      if (spec.format.isStill)
        ExportAccordion(
          title: 'Naming',
          summary: ExportSequenceNamingModule.summarize(
            spec.naming,
            spec.format.stillFormat.fileExtension,
          ),
          expanded: _expandedFor('naming'),
          onToggle: () => _toggleExpanded('naming'),
          resetEnabled: spec.naming != const ExportSequenceNaming(),
          onReset: () {
            _updateSpec(spec.copyWith(naming: const ExportSequenceNaming()));
            _namingBaseController.text = 'frame';
          },
          child: ExportSequenceNamingModule(
            naming: spec.naming,
            enabled: !_isExporting,
            baseNameController: _namingBaseController,
            onChanged: (naming) => _updateSpec(spec.copyWith(naming: naming)),
          ),
        ),
      ExportAccordion(
        title: 'Options',
        summary: spec.applyLayerFx ? 'FX on' : 'FX off',
        expanded: _expandedFor('options'),
        onToggle: () => _toggleExpanded('options'),
        child: ExportToggleRow(
          widgetKey: const ValueKey<String>('export-apply-fx-toggle'),
          label: 'Apply layer FX (transforms and animated opacity)',
          value: spec.applyLayerFx,
          onChanged: _isExporting
              ? null
              : (value) {
                  _preview.clear();
                  _updateSpec(spec.copyWith(applyLayerFx: value));
                },
        ),
      ),
    ];
  }

  void _writeInOutToSpec() {
    final spec = _specs.sequence;
    final inOut = _sequenceInOut();
    setState(() {
      if (inOut != null) {
        _specs = _specs.withSpec(
          spec.copyWith(inFrame: inOut.$1, outFrame: inOut.$2),
        );
      }
    });
    if (inOut != null) {
      _persist();
    }
    _refreshPreview();
  }

  List<Widget> _imageModules() {
    final spec = _specs.image;
    return [
      ExportAccordion(
        title: 'Format',
        summary: ExportFormatModule.summarize(spec.format),
        expanded: _expandedFor('format', fallback: true),
        onToggle: () => _toggleExpanded('format', fallback: true),
        child: ExportFormatModule(
          selection: spec.format,
          capabilities: const ExportFormatCapabilities(
            stills: [ExportStillFormat.png],
          ),
          enabled: !_isExporting,
          onChanged: (format) => _updateSpec(spec.copyWith(format: format)),
        ),
      ),
      ExportAccordion(
        title: 'Size',
        summary: ExportSizeModule.summarize(spec.sizeMode),
        expanded: _expandedFor('size', fallback: true),
        onToggle: () => _toggleExpanded('size', fallback: true),
        child: ExportSizeModule(
          sizeMode: spec.sizeMode,
          cameraSize: _session.cameraFrameSize,
          canvasSizes: {_activeCut.canvasSize},
          projectScope: false,
          enabled: !_isExporting,
          onChanged: (mode) => _updateSpec(spec.copyWith(sizeMode: mode)),
        ),
      ),
      ExportAccordion(
        title: 'Options',
        summary: spec.applyLayerFx ? 'FX on' : 'FX off',
        expanded: _expandedFor('options'),
        onToggle: () => _toggleExpanded('options'),
        child: ExportToggleRow(
          widgetKey: const ValueKey<String>('export-image-fx-toggle'),
          label: 'Apply layer FX',
          value: spec.applyLayerFx,
          onChanged: _isExporting
              ? null
              : (value) {
                  _preview.clear();
                  _updateSpec(spec.copyWith(applyLayerFx: value));
                },
        ),
      ),
    ];
  }

  List<Widget> _celsModules() {
    final spec = _specs.cels;
    return [
      ExportAccordion(
        title: 'Format',
        summary: ExportFormatModule.summarize(spec.format),
        expanded: _expandedFor('format', fallback: true),
        onToggle: () => _toggleExpanded('format', fallback: true),
        child: ExportFormatModule(
          selection: spec.format,
          capabilities: const ExportFormatCapabilities(
            stills: [ExportStillFormat.png],
          ),
          enabled: !_isExporting,
          onChanged: (format) => _updateSpec(spec.copyWith(format: format)),
        ),
      ),
      ExportAccordion(
        title: 'Layers',
        summary: spec.onTimesheetOnly ? 'Sheet only' : 'All visible',
        expanded: _expandedFor('layers', fallback: true),
        onToggle: () => _toggleExpanded('layers', fallback: true),
        child: ExportToggleRow(
          widgetKey: const ValueKey<String>('export-cel-timesheet-only-toggle'),
          label: 'On-timesheet layers only',
          value: spec.onTimesheetOnly,
          onChanged: _isExporting
              ? null
              : (value) =>
                    _updateSpec(spec.copyWith(onTimesheetOnly: value)),
        ),
      ),
      ExportAccordion(
        title: 'Naming',
        summary: ExportCelNamingModule.summarize(spec.naming),
        expanded: _expandedFor('naming'),
        onToggle: () => _toggleExpanded('naming'),
        resetEnabled: spec.naming != const ExportCelNaming(),
        onReset: () {
          _updateSpec(spec.copyWith(naming: const ExportCelNaming()));
          _celSuffixController.text = '';
        },
        child: ExportCelNamingModule(
          naming: spec.naming,
          enabled: !_isExporting,
          suffixController: _celSuffixController,
          onChanged: (naming) => _updateSpec(spec.copyWith(naming: naming)),
        ),
      ),
      ExportAccordion(
        title: 'Scope',
        summary: ExportScopeModule.summarize(spec.scope),
        expanded: _expandedFor('scope'),
        onToggle: () => _toggleExpanded('scope'),
        child: ExportScopeModule(
          scope: spec.scope,
          enabled: !_isExporting,
          onChanged: (scope) => _updateSpec(spec.copyWith(scope: scope)),
          note: spec.scope == ExportScopeKind.project
              ? 'Per-cut checks arrive with the cut grid.'
              : null,
        ),
      ),
    ];
  }

  List<Widget> _timesheetModules() {
    final spec = _specs.timesheet;
    return [
      ExportAccordion(
        title: 'Format',
        summary: 'XDTS',
        expanded: _expandedFor('format', fallback: true),
        onToggle: () => _toggleExpanded('format', fallback: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 5,
              children: const [
                ExportChip(label: 'XDTS', selected: true),
              ],
            ),
            const SizedBox(height: 5),
            exportModuleNote(
              context,
              'One .xdts digital timesheet per cut (OpenToonz/CSP-'
              'compatible sheet data, no rendering).',
            ),
          ],
        ),
      ),
      ExportAccordion(
        title: 'Scope',
        summary: ExportScopeModule.summarize(spec.scope),
        expanded: _expandedFor('scope', fallback: true),
        onToggle: () => _toggleExpanded('scope', fallback: true),
        child: ExportScopeModule(
          scope: spec.scope,
          enabled: !_isExporting,
          onChanged: (scope) => _updateSpec(spec.copyWith(scope: scope)),
          note: spec.scope == ExportScopeKind.project
              ? 'Per-cut checks arrive with the cut grid.'
              : null,
        ),
      ),
    ];
  }

  Widget _queueZone({required bool open}) {
    if (!open) {
      return ExportDrawerStrip(
        key: const ValueKey<String>('export-queue-strip'),
        caption: 'Queue',
        chevron: Icons.chevron_left,
        badgeCount: _queue.jobs.length,
        onTap: () {
          setState(() => _queueOpen = true);
          _persist();
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            key: const ValueKey<String>('export-queue-collapse'),
            onTap: () {
              setState(() => _queueOpen = false);
              _persist();
            },
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.chevron_right, size: 13),
            ),
          ),
        ),
        Expanded(
          child: ExportQueueColumn(queue: _queue, enabled: !_isExporting),
        ),
      ],
    );
  }

  Widget _footer(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _statusMessage ?? '',
              key: const ValueKey<String>('export-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_isExporting) ...[
            TextButton(
              key: const ValueKey<String>('export-cancel-button'),
              onPressed: cancelExport,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 6),
          ],
          Tooltip(
            message: 'The queue runner arrives in a later round.',
            child: OutlinedButton(
              key: const ValueKey<String>('export-queue-add-button'),
              onPressed: null,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Add to Queue'),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            key: const ValueKey<String>('export-run-button'),
            onPressed: _canExport ? () => unawaited(export()) : null,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }
}
