import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../services/export/xdts_builder.dart';
import '../camera/camera_frame_render_service.dart';
import '../editor_session_manager.dart';
import 'export_frame_renderer.dart';
import 'export_plan.dart';
import 'png_sequence_export_service.dart';
import 'video_export_service.dart';

/// Picks the directory export files are written into; `null` on cancel.
typedef ExportDirectoryPicker = Future<String?> Function();

/// Picks the video output file path; `null` on cancel.
typedef ExportVideoPathPicker = Future<String?> Function(String suggestedName);

/// Picks the XDTS output file path; `null` on cancel.
typedef ExportXdtsPathPicker = Future<String?> Function(String suggestedName);

Future<String?> _pickExportDirectory() => getDirectoryPath();

Future<String?> _pickExportVideoPath(String suggestedName) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'MP4 video', extensions: ['mp4']),
    ],
  );
  return location?.path;
}

Future<String?> _pickExportXdtsPath(String suggestedName) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'XDTS timesheet', extensions: ['xdts']),
    ],
  );
  return location?.path;
}

/// The TVPaint-style export window: range (active cut / all cuts / frame
/// subrange), output size (through the camera or the raw cut canvas),
/// format (PNG sequence now, video later) and instance-only cel export.
/// Always renders at full quality, streaming one file at a time.
class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.session,
    this.exportDirectoryPicker,
    this.exportVideoPathPicker,
    this.exportXdtsPathPicker,
    this.videoExportService = const VideoExportService(),
  });

  final EditorSessionManager session;

  /// Injectable for tests; defaults to the platform directory picker.
  final ExportDirectoryPicker? exportDirectoryPicker;

  /// Injectable for tests; defaults to the platform save-file dialog.
  final ExportVideoPathPicker? exportVideoPathPicker;

  /// Injectable for tests; defaults to the platform save-file dialog.
  final ExportXdtsPathPicker? exportXdtsPathPicker;

  /// Injectable for tests; the real one shells out to ffmpeg.
  final VideoExportService videoExportService;

  @override
  State<ExportDialog> createState() => ExportDialogState();
}

class ExportDialogState extends State<ExportDialog> {
  static const _exportService = PngSequenceExportService();

  ExportRange _range = ExportRange.activeCut;
  ExportSizeMode _sizeMode = ExportSizeMode.camera;
  ExportFormat _format = ExportFormat.pngSequence;
  bool _instanceOnly = false;
  bool _celTransparent = true;
  bool _celTimesheetOnly = false;
  bool _celIncludeProject = false;
  bool _celIncludeCut = false;
  bool _celIncludeLayer = true;
  bool _celCutFolder = false;
  bool _celLayerFolder = false;
  late final TextEditingController _rangeStartController =
      TextEditingController(text: '1');
  late final TextEditingController _rangeEndController = TextEditingController(
    text: '${math.max(1, widget.session.activeCut.duration)}',
  );
  late final TextEditingController _celDigitsController = TextEditingController(
    text: '0',
  );
  late final TextEditingController _celSuffixController =
      TextEditingController();
  bool _isExporting = false;
  bool _cancelRequested = false;
  String? _statusMessage;
  (int completed, int total)? _progress;

  @override
  void dispose() {
    _rangeStartController.dispose();
    _rangeEndController.dispose();
    _celDigitsController.dispose();
    _celSuffixController.dispose();
    super.dispose();
  }

  int? _parseRangeField(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    return (value == null || value < 1) ? null : value;
  }

  /// The composite plan for the current selections; `null` while the frame
  /// range fields don't form a valid 1-based range.
  List<ExportFrameTask>? _framePlan() {
    int? start;
    int? end;
    if (_range == ExportRange.frameRange) {
      final startField = _parseRangeField(_rangeStartController);
      final endField = _parseRangeField(_rangeEndController);
      if (startField == null || endField == null || startField > endField) {
        return null;
      }
      start = startField - 1;
      end = endField - 1;
    }
    return buildExportFramePlan(
      project: widget.session.repository.requireProject(),
      activeCutId: widget.session.activeCut.id,
      range: _range,
      rangeStartFrame: start,
      rangeEndFrame: end,
    );
  }

  ExportCelNaming get _celNaming => ExportCelNaming(
    includeProjectName: _celIncludeProject,
    includeCutName: _celIncludeCut,
    includeLayerName: _celIncludeLayer,
    frameDigits: int.tryParse(_celDigitsController.text.trim()) ?? 0,
    suffix: _celSuffixController.text.trim(),
    cutFolder: _celCutFolder,
    layerFolder: _celLayerFolder,
  );

  List<ExportCelTask> _celPlan() => buildExportCelPlan(
    project: widget.session.repository.requireProject(),
    activeCutId: widget.session.activeCut.id,
    range: _range,
    naming: _celNaming,
    onTimesheetOnly: _celTimesheetOnly,
  );

  /// The canvas sizes the current range covers; one entry means every
  /// exported cut shares it.
  Set<CanvasSize> _rangeCanvasSizes() {
    return resolveExportCuts(
      project: widget.session.repository.requireProject(),
      activeCutId: widget.session.activeCut.id,
      range: _range,
    ).map((cut) => cut.canvasSize).toSet();
  }

  /// Video needs one constant picture size; the camera size always is, but
  /// raw canvas mode breaks when the range mixes cut canvas sizes.
  bool get _videoSizeConflict =>
      _format == ExportFormat.mp4Video &&
      !_instanceOnly &&
      _sizeMode == ExportSizeMode.canvas &&
      _rangeCanvasSizes().length > 1;

  /// Sheet-data export: size/frame-range/rendering do not apply.
  bool get _isXdts => !_instanceOnly && _format == ExportFormat.xdtsTimesheet;

  String _planSummary() {
    if (_isXdts) {
      final count = _xdtsCuts().length;
      return '$count XDTS ${_plural(count, 'sheet')} '
          '(cels + serifu + camerawork columns).';
    }
    if (_instanceOnly) {
      final count = _celPlan().length;
      final background = _celTransparent ? 'transparent' : 'opaque white';
      return '$count ${_plural(count, 'cel')} as $background PNGs, '
          'no compositing.';
    }
    final plan = _framePlan();
    if (plan == null) {
      final duration = math.max(1, widget.session.activeCut.duration);
      return 'Enter a valid frame range (1–$duration).';
    }
    final frames = '${plan.length} ${_plural(plan.length, 'frame')}';
    if (_sizeMode == ExportSizeMode.camera) {
      final size = widget.session.cameraFrameSize;
      return '$frames at ${size.width}×${size.height} through the camera.';
    }
    final sizes = _rangeCanvasSizes();
    if (sizes.length == 1) {
      final size = sizes.first;
      return '$frames at ${size.width}×${size.height} (raw canvas).';
    }
    if (_videoSizeConflict) {
      return 'Video needs one picture size, but the cuts in this range have '
          'different canvas sizes — use the camera size instead.';
    }
    return "$frames at each cut's own canvas size.";
  }

  String _plural(int count, String noun) => count == 1 ? noun : '${noun}s';

  String _summaryMessage(
    ExportWriteSummary summary,
    int planned,
    bool instanceOnly,
  ) {
    if (summary.processed < planned) {
      return 'Export cancelled after ${summary.written} '
          '${_plural(summary.written, 'file')}.';
    }
    if (instanceOnly) {
      final skipped = summary.processed - summary.written;
      final cels = '${summary.written} ${_plural(summary.written, 'cel')}';
      return skipped > 0
          ? 'Exported $cels ($skipped empty skipped).'
          : 'Exported $cels.';
    }
    return 'Exported ${summary.written} '
        '${_plural(summary.written, 'frame')}.';
  }

  /// The 1-based position of [cut] within its track — the sheet/XDTS cut
  /// number.
  int _cutNumberOf(Cut cut) {
    for (final track in widget.session.repository.requireProject().tracks) {
      final index = track.cuts.indexWhere((entry) => entry.id == cut.id);
      if (index != -1) {
        return index + 1;
      }
    }
    return 1;
  }

  List<Cut> _xdtsCuts() => resolveExportCuts(
    project: widget.session.repository.requireProject(),
    activeCutId: widget.session.activeCut.id,
    // XDTS has no frame subrange — a sheet always covers its whole cut.
    range: _range == ExportRange.allCuts
        ? ExportRange.allCuts
        : ExportRange.activeCut,
  );

  /// XDTS export writes sheet data straight to disk — no rendering: one
  /// .xdts per cut (save dialog for the active cut, a directory for all).
  Future<void> _exportXdts() async {
    final cuts = _xdtsCuts();
    if (cuts.isEmpty) {
      return;
    }
    final defById = widget.session.cameraInstructionSet.defById;

    final targets = <(Cut, String)>[];
    if (cuts.length == 1) {
      final picker = widget.exportXdtsPathPicker ?? _pickExportXdtsPath;
      var path = await picker('CUT${_cutNumberOf(cuts.single)}.xdts');
      if (path == null || !mounted) {
        return;
      }
      if (!path.toLowerCase().endsWith('.xdts')) {
        path = '$path.xdts';
      }
      targets.add((cuts.single, path));
    } else {
      final picker = widget.exportDirectoryPicker ?? _pickExportDirectory;
      final directoryPath = await picker();
      if (directoryPath == null || !mounted) {
        return;
      }
      for (final cut in cuts) {
        targets.add((
          cut,
          '$directoryPath${Platform.pathSeparator}'
              'CUT${_cutNumberOf(cut)}.xdts',
        ));
      }
    }

    setState(() {
      _isExporting = true;
      _statusMessage = 'Exporting…';
    });
    try {
      for (final (cut, path) in targets) {
        final content = buildXdtsContent(
          cut: cut,
          cutNumber: _cutNumberOf(cut),
          instructionDefById: defById,
        );
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsString(content, flush: true);
      }
      if (mounted) {
        setState(
          () => _statusMessage =
              'Exported ${targets.length} XDTS '
              '${_plural(targets.length, 'sheet')}.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _statusMessage = 'Export failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Public for tests; the Export button is the production entry point.
  Future<void> export() async {
    final instanceOnly = _instanceOnly;
    final celTransparent = _celTransparent;
    final sizeMode = _sizeMode;
    if (!instanceOnly && _format == ExportFormat.xdtsTimesheet) {
      if (_isExporting) {
        return;
      }
      await _exportXdts();
      return;
    }
    final isVideo = !instanceOnly && _format == ExportFormat.mp4Video;
    final celPlan = instanceOnly ? _celPlan() : const <ExportCelTask>[];
    final framePlan = instanceOnly ? const <ExportFrameTask>[] : _framePlan();
    final count = instanceOnly ? celPlan.length : (framePlan?.length ?? 0);
    if (count == 0 || _isExporting || _videoSizeConflict) {
      return;
    }

    String? directoryPath;
    String? videoPath;
    if (isVideo) {
      final picker = widget.exportVideoPathPicker ?? _pickExportVideoPath;
      final suggestedName =
          '${sanitizeExportFileComponent(widget.session.repository.requireProject().name)}.mp4';
      videoPath = await picker(suggestedName);
      if (videoPath == null || !mounted) {
        return;
      }
      if (!videoPath.toLowerCase().endsWith('.mp4')) {
        videoPath = '$videoPath.mp4';
      }
    } else {
      final picker = widget.exportDirectoryPicker ?? _pickExportDirectory;
      directoryPath = await picker();
      if (directoryPath == null || !mounted) {
        return;
      }
    }

    final renderer = ExportFrameRenderer(session: widget.session);
    setState(() {
      _isExporting = true;
      _cancelRequested = false;
      _progress = (0, count);
      _statusMessage = 'Exporting…';
    });
    try {
      void reportProgress(int completed, int total) {
        if (mounted) {
          setState(() {
            _progress = (completed, total);
            _statusMessage = 'Exporting… $completed/$total';
          });
        }
      }

      final ExportWriteSummary summary;
      if (isVideo) {
        final videoPlan = framePlan!;
        summary = await widget.videoExportService.exportVideo(
          count: count,
          // Video frames bake the cut fade (MP4 has no alpha channel).
          renderImage: (index) =>
              renderer.renderCompositeForVideo(videoPlan[index], sizeMode),
          outputFilePath: videoPath!,
          fps: widget.session.projectFps,
          // SE audio clips muxed onto the video timeline (silent export
          // when none are attached).
          audioClips: buildExportAudioPlan(
            plan: videoPlan,
            fps: widget.session.projectFps,
          ),
          isCancelled: () => _cancelRequested,
          onProgress: reportProgress,
        );
      } else {
        summary = await _exportService.exportImages(
          count: count,
          renderImage: (index) => instanceOnly
              ? renderer.renderCel(celPlan[index], transparent: celTransparent)
              : renderer.renderComposite(framePlan![index], sizeMode),
          fileNameFor: (index) => instanceOnly
              ? celPlan[index].fileName
              : cameraSequenceFileName(index),
          directoryPath: directoryPath!,
          isCancelled: () => _cancelRequested,
          onProgress: reportProgress,
        );
      }
      if (mounted) {
        setState(
          () => _statusMessage = isVideo
              ? _videoSummaryMessage(summary, count)
              : _summaryMessage(summary, count, instanceOnly),
        );
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

  String _videoSummaryMessage(ExportWriteSummary summary, int planned) {
    if (summary.processed < planned) {
      return summary.written == 0
          ? 'Export cancelled.'
          : 'Export cancelled after ${summary.written} '
                '${_plural(summary.written, 'frame')} (partial video kept).';
    }
    return 'Exported video (${summary.written} '
        '${_plural(summary.written, 'frame')}).';
  }

  void cancelExport() {
    _cancelRequested = true;
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Widget _rangeChip(String label, ExportRange range, String keySuffix) {
    // A sheet always covers its whole cut — no frame subrange for XDTS.
    final unavailable = _isXdts && range == ExportRange.frameRange;
    return ChoiceChip(
      key: ValueKey<String>('export-range-$keySuffix'),
      label: Text(label),
      selected: _range == range,
      onSelected: _isExporting || unavailable
          ? null
          : (_) => setState(() => _range = range),
    );
  }

  Widget _sizeChip(String label, ExportSizeMode mode, String keySuffix) {
    return ChoiceChip(
      key: ValueKey<String>('export-size-$keySuffix'),
      label: Text(label),
      selected: _sizeMode == mode,
      // Cels are always raw canvas artwork and XDTS carries no pictures,
      // so size mode is moot for both.
      onSelected: _isExporting || _instanceOnly || _isXdts
          ? null
          : (_) => setState(() => _sizeMode = mode),
    );
  }

  Widget _celOptionChip(
    String label,
    bool selected,
    void Function(bool value) apply,
    String key,
  ) {
    return FilterChip(
      key: ValueKey<String>(key),
      label: Text(label),
      selected: selected,
      onSelected: _isExporting ? null : (value) => setState(() => apply(value)),
    );
  }

  Widget _rangeField(
    TextEditingController controller,
    String label,
    String key,
  ) {
    return Expanded(
      child: TextField(
        key: ValueKey<String>(key),
        controller: controller,
        enabled: !_isExporting,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cameraSize = widget.session.cameraFrameSize;
    final canvasSizes = _rangeCanvasSizes();
    final canvasLabel = canvasSizes.length == 1
        ? 'Canvas ${canvasSizes.first.width}×${canvasSizes.first.height}'
        : 'Canvas (per cut)';
    final progress = _progress;
    final celPlan = _instanceOnly ? _celPlan() : const <ExportCelTask>[];
    final canExport =
        !_isExporting &&
        !_videoSizeConflict &&
        (_isXdts
            ? _xdtsCuts().isNotEmpty
            : _instanceOnly
            ? celPlan.isNotEmpty
            : (_framePlan()?.isNotEmpty ?? false));

    return AlertDialog(
      title: const Text('Export'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Range'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _rangeChip('Active cut', ExportRange.activeCut, 'active-cut'),
                  _rangeChip('All cuts', ExportRange.allCuts, 'all-cuts'),
                  _rangeChip(
                    'Frame range',
                    ExportRange.frameRange,
                    'frame-range',
                  ),
                ],
              ),
              if (_range == ExportRange.frameRange && !_instanceOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      _rangeField(
                        _rangeStartController,
                        'From frame',
                        'export-range-start-field',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('–'),
                      ),
                      _rangeField(
                        _rangeEndController,
                        'To frame',
                        'export-range-end-field',
                      ),
                    ],
                  ),
                ),
              if (_range == ExportRange.frameRange && _instanceOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Cel export always covers the whole cut; the frame range '
                    'does not apply.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              _sectionLabel('Size'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _sizeChip(
                    'Camera ${cameraSize.width}×${cameraSize.height}',
                    ExportSizeMode.camera,
                    'camera',
                  ),
                  _sizeChip(canvasLabel, ExportSizeMode.canvas, 'canvas'),
                ],
              ),
              const SizedBox(height: 12),
              _sectionLabel('Format'),
              Row(
                children: [
                  DropdownButton<ExportFormat>(
                    key: const ValueKey<String>('export-format-dropdown'),
                    // Cels are always individual PNGs.
                    value: _instanceOnly ? ExportFormat.pngSequence : _format,
                    items: const [
                      DropdownMenuItem(
                        value: ExportFormat.pngSequence,
                        child: Text('PNG sequence'),
                      ),
                      DropdownMenuItem(
                        value: ExportFormat.mp4Video,
                        child: Text('MP4 video'),
                      ),
                      DropdownMenuItem(
                        value: ExportFormat.xdtsTimesheet,
                        child: Text('XDTS timesheet'),
                      ),
                    ],
                    onChanged: _isExporting || _instanceOnly
                        ? null
                        : (format) => setState(
                            () => _format = format ?? ExportFormat.pngSequence,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isXdts
                          ? 'One .xdts digital timesheet per cut (OpenToonz/'
                                'CSP-compatible sheet data, no rendering).'
                          : _format == ExportFormat.mp4Video && !_instanceOnly
                          ? 'Encoded with FFmpeg — it must be installed and '
                                'on PATH.'
                          : 'One PNG file per frame.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    key: const ValueKey<String>('export-instance-toggle'),
                    value: _instanceOnly,
                    onChanged: _isExporting
                        ? null
                        : (value) => setState(() => _instanceOnly = value),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Instance export: each unique cel as its own PNG, '
                      'no compositing.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (_instanceOnly) ...[
                const SizedBox(height: 4),
                _sectionLabel('Cel options'),
                Row(
                  children: [
                    Switch(
                      key: const ValueKey<String>(
                        'export-cel-transparent-toggle',
                      ),
                      value: _celTransparent,
                      onChanged: _isExporting
                          ? null
                          : (value) => setState(() => _celTransparent = value),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _celTransparent
                            ? 'Transparent background'
                            : 'Opaque background (white paper)',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Switch(
                      key: const ValueKey<String>(
                        'export-cel-timesheet-only-toggle',
                      ),
                      value: _celTimesheetOnly,
                      onChanged: _isExporting
                          ? null
                          : (value) =>
                                setState(() => _celTimesheetOnly = value),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _celTimesheetOnly
                            ? 'Timesheet layers only'
                            : 'All visible drawing layers',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _celOptionChip(
                      'Project name',
                      _celIncludeProject,
                      (value) => _celIncludeProject = value,
                      'export-cel-include-project',
                    ),
                    _celOptionChip(
                      'Cut name',
                      _celIncludeCut,
                      (value) => _celIncludeCut = value,
                      'export-cel-include-cut',
                    ),
                    _celOptionChip(
                      'Layer name',
                      _celIncludeLayer,
                      (value) => _celIncludeLayer = value,
                      'export-cel-include-layer',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextField(
                        key: const ValueKey<String>('export-cel-digits-field'),
                        controller: _celDigitsController,
                        enabled: !_isExporting,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Digits (0 = off)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('export-cel-suffix-field'),
                        controller: _celSuffixController,
                        enabled: !_isExporting,
                        decoration: const InputDecoration(labelText: 'Suffix'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _celOptionChip(
                      'Cut folder',
                      _celCutFolder,
                      (value) => _celCutFolder = value,
                      'export-cel-cut-folder',
                    ),
                    _celOptionChip(
                      'Layer folder',
                      _celLayerFolder,
                      (value) => _celLayerFolder = value,
                      'export-cel-layer-folder',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(_planSummary(), style: theme.textTheme.bodyMedium),
              if (_instanceOnly && celPlan.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Example: ${celPlan.first.fileName}',
                    key: const ValueKey<String>('export-cel-example'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    value: progress.$2 > 0 ? progress.$1 / progress.$2 : null,
                  ),
                ),
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _statusMessage!,
                    key: const ValueKey<String>('export-status'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isExporting)
          TextButton(
            key: const ValueKey<String>('export-cancel-button'),
            onPressed: cancelExport,
            child: const Text('Cancel'),
          ),
        TextButton(
          key: const ValueKey<String>('export-run-button'),
          onPressed: canExport ? export : null,
          child: const Text('Export…'),
        ),
        TextButton(
          key: const ValueKey<String>('export-close-button'),
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
