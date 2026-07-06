import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/canvas_size.dart';
import '../../models/frame.dart';
import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../services/cut_frame_composite_plan.dart';
import '../editor_session_manager.dart';
import 'camera_frame_render_service.dart';

/// Picks the directory PNG frames are exported into; `null` on cancel.
typedef ExportDirectoryPicker = Future<String?> Function();

Future<String?> _pickExportDirectory() => getDirectoryPath();

/// Plays the active cut through its camera and exports it as a PNG sequence.
///
/// Preview frames are pre-rendered once at a reduced size (full camera math,
/// smaller raster) and looped at the project fps. Export re-renders each
/// frame at the full camera size and streams it to disk, so full-resolution
/// frames are never all held in memory.
class CameraPreviewDialog extends StatefulWidget {
  const CameraPreviewDialog({
    super.key,
    required this.session,
    this.exportDirectoryPicker,
    this.previewMaxWidth = 640,
  });

  final EditorSessionManager session;

  /// Injectable for tests; defaults to the platform directory picker.
  final ExportDirectoryPicker? exportDirectoryPicker;

  final int previewMaxWidth;

  @override
  State<CameraPreviewDialog> createState() => CameraPreviewDialogState();
}

class CameraPreviewDialogState extends State<CameraPreviewDialog> {
  static const _renderService = CameraFrameRenderService();

  final List<ui.Image?> _previewFrames = [];
  final Map<(LayerId, FrameId), BitmapSurface?> _surfaceCache = {};

  late final int _frameCount = widget.session.activeCutPlaybackFrameCount;
  int _renderedCount = 0;
  int _currentFrame = 0;
  bool _isPlaying = false;
  bool _isExporting = false;
  String? _statusMessage;
  Timer? _playbackTimer;
  bool _disposed = false;

  /// Completes when every preview frame is rendered (test hook).
  late final Future<void> prerenderDone = _prerenderPreviewFrames();

  bool get _isRendering => _renderedCount < _frameCount;

  @override
  void initState() {
    super.initState();
    // Triggers the lazy prerender future.
    unawaited(prerenderDone);
  }

  @override
  void dispose() {
    _disposed = true;
    _playbackTimer?.cancel();
    for (final frame in _previewFrames) {
      frame?.dispose();
    }
    super.dispose();
  }

  CanvasSize get _previewSize {
    final cameraSize = widget.session.cameraFrameSize;
    if (cameraSize.width <= widget.previewMaxWidth) {
      return cameraSize;
    }
    final scale = widget.previewMaxWidth / cameraSize.width;
    return CanvasSize(
      width: widget.previewMaxWidth,
      height: math.max(1, (cameraSize.height * scale).round()),
    );
  }

  BitmapSurface? _cachedSurfaceResolver(Layer layer, Frame frame) {
    return _surfaceCache.putIfAbsent(
      (layer.id, frame.id),
      () => widget.session.brushSurfaceForLayerFrame(layer, frame),
    );
  }

  Future<ui.Image> _renderFrame(int frameIndex, {CanvasSize? outputSize}) {
    final session = widget.session;
    return _renderService.renderThroughCamera(
      layers: planCutFrameComposite(
        cut: session.activeCut,
        frameIndex: frameIndex,
        surfaceResolver: _cachedSurfaceResolver,
      ),
      pose: session.cameraPoseAtFrame(frameIndex),
      cameraFrameSize: session.cameraFrameSize,
      outputSize: outputSize ?? _previewSize,
    );
  }

  Future<void> _prerenderPreviewFrames() async {
    for (var index = 0; index < _frameCount; index += 1) {
      final image = await _renderFrame(index);
      if (_disposed) {
        image.dispose();
        return;
      }
      setState(() {
        _previewFrames.add(image);
        _renderedCount = _previewFrames.length;
      });
    }
    _startPlayback();
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: (1000 / widget.session.projectFps).round()),
      (_) {
        setState(() => _currentFrame = (_currentFrame + 1) % _frameCount);
      },
    );
    setState(() => _isPlaying = true);
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    setState(() => _isPlaying = false);
  }

  /// Public for tests (awaiting the export end-to-end); the UI button is the
  /// production entry point.
  Future<void> exportPngSequence() async {
    final picker = widget.exportDirectoryPicker ?? _pickExportDirectory;
    final directoryPath = await picker();
    if (directoryPath == null || !mounted) {
      return;
    }

    _stopPlayback();
    setState(() {
      _isExporting = true;
      _statusMessage = 'Exporting…';
    });
    try {
      for (var index = 0; index < _frameCount; index += 1) {
        final image = await _renderFrame(
          index,
          outputSize: widget.session.cameraFrameSize,
        );
        try {
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '$directoryPath${Platform.pathSeparator}${cameraSequenceFileName(index)}',
          ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
        } finally {
          image.dispose();
        }
        if (_disposed) {
          return;
        }
        setState(() {
          _statusMessage = 'Exporting… ${index + 1}/$_frameCount';
        });
      }
      setState(() => _statusMessage = 'Exported $_frameCount frames.');
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

  @override
  Widget build(BuildContext context) {
    final previewSize = _previewSize;
    final currentImage = _currentFrame < _previewFrames.length
        ? _previewFrames[_currentFrame]
        : null;

    return AlertDialog(
      title: const Text('Camera Preview'),
      content: SizedBox(
        width: previewSize.width.toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: previewSize.width / previewSize.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: _isRendering
                    ? Center(
                        key: const ValueKey<String>('camera-preview-progress'),
                        child: Text(
                          'Rendering… $_renderedCount/$_frameCount',
                        ),
                      )
                    : RawImage(
                        key: const ValueKey<String>('camera-preview-image'),
                        image: currentImage,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  key: const ValueKey<String>('camera-preview-play-button'),
                  tooltip: _isPlaying ? 'Pause' : 'Play',
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _isRendering || _isExporting
                      ? null
                      : () => _isPlaying ? _stopPlayback() : _startPlayback(),
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey<String>('camera-preview-scrubber'),
                    min: 0,
                    max: (_frameCount - 1).toDouble(),
                    divisions: math.max(1, _frameCount - 1),
                    value: _currentFrame
                        .clamp(0, _frameCount - 1)
                        .toDouble(),
                    onChanged: _isRendering
                        ? null
                        : (value) {
                            _stopPlayback();
                            setState(() => _currentFrame = value.round());
                          },
                  ),
                ),
                Text('${_currentFrame + 1}/$_frameCount'),
              ],
            ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _statusMessage!,
                  key: const ValueKey<String>('camera-preview-status'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('camera-preview-export-button'),
          onPressed: _isRendering || _isExporting ? null : exportPngSequence,
          child: const Text('Export PNG Sequence'),
        ),
        TextButton(
          key: const ValueKey<String>('camera-preview-close-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
