import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/canvas_size.dart';
import '../camera/camera_frame_render_service.dart';
import '../editor_session_manager.dart';
import 'export_frame_renderer.dart';
import 'export_plan.dart';
import 'png_sequence_export_service.dart';

/// Picks the directory export files are written into; `null` on cancel.
typedef ExportDirectoryPicker = Future<String?> Function();

Future<String?> _pickExportDirectory() => getDirectoryPath();

/// The TVPaint-style export window: range (active cut / all cuts / frame
/// subrange), output size (through the camera or the raw cut canvas),
/// format (PNG sequence now, video later) and instance-only cel export.
/// Always renders at full quality, streaming one file at a time.
class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.session,
    this.exportDirectoryPicker,
  });

  final EditorSessionManager session;

  /// Injectable for tests; defaults to the platform directory picker.
  final ExportDirectoryPicker? exportDirectoryPicker;

  @override
  State<ExportDialog> createState() => ExportDialogState();
}

class ExportDialogState extends State<ExportDialog> {
  static const _exportService = PngSequenceExportService();

  ExportRange _range = ExportRange.activeCut;
  ExportSizeMode _sizeMode = ExportSizeMode.camera;
  bool _instanceOnly = false;
  bool _celTransparent = true;
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

  String _planSummary() {
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

  /// Public for tests; the Export button is the production entry point.
  Future<void> export() async {
    final instanceOnly = _instanceOnly;
    final celTransparent = _celTransparent;
    final sizeMode = _sizeMode;
    final celPlan = instanceOnly ? _celPlan() : const <ExportCelTask>[];
    final framePlan = instanceOnly ? const <ExportFrameTask>[] : _framePlan();
    final count = instanceOnly ? celPlan.length : (framePlan?.length ?? 0);
    if (count == 0 || _isExporting) {
      return;
    }

    final picker = widget.exportDirectoryPicker ?? _pickExportDirectory;
    final directoryPath = await picker();
    if (directoryPath == null || !mounted) {
      return;
    }

    final renderer = ExportFrameRenderer(session: widget.session);
    setState(() {
      _isExporting = true;
      _cancelRequested = false;
      _progress = (0, count);
      _statusMessage = 'Exporting…';
    });
    try {
      final summary = await _exportService.exportImages(
        count: count,
        renderImage: (index) => instanceOnly
            ? renderer.renderCel(celPlan[index], transparent: celTransparent)
            : renderer.renderComposite(framePlan![index], sizeMode),
        fileNameFor: (index) => instanceOnly
            ? celPlan[index].fileName
            : cameraSequenceFileName(index),
        directoryPath: directoryPath,
        isCancelled: () => _cancelRequested,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _progress = (completed, total);
              _statusMessage = 'Exporting… $completed/$total';
            });
          }
        },
      );
      if (mounted) {
        setState(
          () => _statusMessage = _summaryMessage(summary, count, instanceOnly),
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
    return ChoiceChip(
      key: ValueKey<String>('export-range-$keySuffix'),
      label: Text(label),
      selected: _range == range,
      onSelected: _isExporting ? null : (_) => setState(() => _range = range),
    );
  }

  Widget _sizeChip(String label, ExportSizeMode mode, String keySuffix) {
    return ChoiceChip(
      key: ValueKey<String>('export-size-$keySuffix'),
      label: Text(label),
      selected: _sizeMode == mode,
      // Cels are always raw canvas artwork, so size mode is moot.
      onSelected: _isExporting || _instanceOnly
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
        (_instanceOnly
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
                    value: ExportFormat.pngSequence,
                    items: const [
                      DropdownMenuItem(
                        value: ExportFormat.pngSequence,
                        child: Text('PNG sequence'),
                      ),
                    ],
                    onChanged: _isExporting ? null : (_) {},
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Video export lands later.',
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
