import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/frame.dart';
import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../services/cut_frame_composite_plan.dart';
import '../camera/camera_frame_render_service.dart';
import '../editor_session_manager.dart';
import 'png_sequence_export_service.dart';

/// Picks the directory PNG frames are exported into; `null` on cancel.
typedef ExportDirectoryPicker = Future<String?> Function();

Future<String?> _pickExportDirectory() => getDirectoryPath();

/// Interim PNG-sequence export entry point: renders the active cut through
/// its camera at the full output size, streaming each frame to disk.
///
/// Canvas playback replaced the old camera preview dialog; this keeps its
/// export path alive until the full TVPaint-style export window lands.
class PngSequenceExportDialog extends StatefulWidget {
  const PngSequenceExportDialog({
    super.key,
    required this.session,
    this.exportDirectoryPicker,
  });

  final EditorSessionManager session;

  /// Injectable for tests; defaults to the platform directory picker.
  final ExportDirectoryPicker? exportDirectoryPicker;

  @override
  State<PngSequenceExportDialog> createState() =>
      PngSequenceExportDialogState();
}

class PngSequenceExportDialogState extends State<PngSequenceExportDialog> {
  static const _renderService = CameraFrameRenderService();
  static const _exportService = PngSequenceExportService();

  final Map<(LayerId, FrameId), BitmapSurface?> _surfaceCache = {};
  bool _isExporting = false;
  String? _statusMessage;

  BitmapSurface? _cachedSurfaceResolver(Layer layer, Frame frame) {
    return _surfaceCache.putIfAbsent(
      (layer.id, frame.id),
      () => widget.session.brushSurfaceForLayerFrame(layer, frame),
    );
  }

  Future<ui.Image> _renderFrame(int frameIndex) {
    final session = widget.session;
    return _renderService.renderThroughCamera(
      layers: planCutFrameComposite(
        cut: session.activeCut,
        frameIndex: frameIndex,
        surfaceResolver: _cachedSurfaceResolver,
      ),
      pose: session.cameraPoseAtFrame(frameIndex),
      cameraFrameSize: session.cameraFrameSize,
    );
  }

  /// Public for tests; the export button is the production entry point.
  Future<void> export() async {
    final picker = widget.exportDirectoryPicker ?? _pickExportDirectory;
    final directoryPath = await picker();
    if (directoryPath == null || !mounted) {
      return;
    }

    final frameCount = widget.session.activeCutPlaybackFrameCount;
    setState(() {
      _isExporting = true;
      _statusMessage = 'Exporting…';
    });
    try {
      await _exportService.exportFrames(
        frameCount: frameCount,
        renderFrame: _renderFrame,
        directoryPath: directoryPath,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() => _statusMessage = 'Exporting… $completed/$total');
          }
        },
      );
      if (mounted) {
        setState(() => _statusMessage = 'Exported $frameCount frames.');
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

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final cameraSize = session.cameraFrameSize;

    return AlertDialog(
      title: const Text('Export PNG Sequence'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${session.activeCut.name}: '
            '${session.activeCutPlaybackFrameCount} frames through the '
            'camera at ${cameraSize.width}×${cameraSize.height}.',
          ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _statusMessage!,
                key: const ValueKey<String>('png-export-status'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('png-export-run-button'),
          onPressed: _isExporting ? null : export,
          child: const Text('Export…'),
        ),
        TextButton(
          key: const ValueKey<String>('png-export-close-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
