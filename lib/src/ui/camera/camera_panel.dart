import 'package:flutter/material.dart';

import '../../models/camera_pose.dart';
import '../panels/editor_panel_frame.dart';

/// The camera operation panel in the editor dock (TVPaint/Clip-Studio
/// style: camera zoom/rotation live in a panel, not on the canvas).
///
/// The header hosts the camera-view toggle (overlay + dimmed
/// surroundings); the body shows the dim-opacity slider while the view is
/// on, and — while the camera layer is active — the pose controls for the
/// playhead frame: zoom/rotation fields and key set/remove buttons.
class CameraPanel extends StatefulWidget {
  const CameraPanel({
    super.key,
    required this.cameraViewEnabled,
    required this.onCameraViewChanged,
    required this.dimOpacity,
    required this.onDimOpacityChanged,
    required this.isCameraLayerActive,
    required this.pose,
    required this.hasKeyframeAtCurrentFrame,
    required this.onPoseCommitted,
    required this.onRemoveKeyframe,
    this.onCopyAeKeyframes,
  });

  final bool cameraViewEnabled;
  final ValueChanged<bool> onCameraViewChanged;
  final double dimOpacity;
  final ValueChanged<double> onDimOpacityChanged;
  final bool isCameraLayerActive;

  /// The resolved pose at the playhead frame.
  final CameraPose pose;

  final bool hasKeyframeAtCurrentFrame;

  /// Commits a pose as the keyframe at the playhead frame.
  final ValueChanged<CameraPose> onPoseCommitted;

  final VoidCallback onRemoveKeyframe;

  /// Copies the cut's camera work to the clipboard as After Effects
  /// keyframe data; the button hides when null.
  final VoidCallback? onCopyAeKeyframes;

  @override
  State<CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<CameraPanel> {
  late final TextEditingController _zoomController = TextEditingController(
    text: _zoomText(widget.pose),
  );
  late final TextEditingController _rotationController = TextEditingController(
    text: _rotationText(widget.pose),
  );
  final FocusNode _zoomFocus = FocusNode();
  final FocusNode _rotationFocus = FocusNode();

  static String _zoomText(CameraPose pose) =>
      (pose.zoom * 100).round().toString();

  static String _rotationText(CameraPose pose) {
    final degrees = pose.rotationDegrees;
    return degrees == degrees.roundToDouble()
        ? degrees.round().toString()
        : degrees.toStringAsFixed(1);
  }

  @override
  void didUpdateWidget(covariant CameraPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow external pose changes (playhead moves, undo, drag) but never
    // fight the user while they are typing.
    if (!_zoomFocus.hasFocus) {
      _zoomController.text = _zoomText(widget.pose);
    }
    if (!_rotationFocus.hasFocus) {
      _rotationController.text = _rotationText(widget.pose);
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _rotationController.dispose();
    _zoomFocus.dispose();
    _rotationFocus.dispose();
    super.dispose();
  }

  void _submitZoom(String text) {
    final percent = double.tryParse(text.trim());
    if (percent == null || percent <= 0) {
      _zoomController.text = _zoomText(widget.pose);
      return;
    }
    widget.onPoseCommitted(widget.pose.copyWith(zoom: percent / 100));
  }

  void _submitRotation(String text) {
    final degrees = double.tryParse(text.trim());
    if (degrees == null || !degrees.isFinite) {
      _rotationController.text = _rotationText(widget.pose);
      return;
    }
    widget.onPoseCommitted(widget.pose.copyWith(rotationDegrees: degrees));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return EditorPanelFrame(
      title: 'Camera',
      trailing: IconButton(
        key: const ValueKey<String>('camera-view-toggle'),
        tooltip: 'Camera View',
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        isSelected: widget.cameraViewEnabled,
        selectedIcon: Icon(Icons.videocam, color: colorScheme.primary),
        icon: const Icon(Icons.videocam_outlined),
        onPressed: () => widget.onCameraViewChanged(!widget.cameraViewEnabled),
      ),
      child: Column(
        key: const ValueKey<String>('camera-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.cameraViewEnabled)
            Row(
              children: [
                Tooltip(
                  message: 'Outside dim',
                  child: Icon(
                    Icons.brightness_6_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey<String>('camera-dim-slider'),
                    min: 0,
                    max: 0.95,
                    value: widget.dimOpacity.clamp(0.0, 0.95).toDouble(),
                    onChanged: widget.onDimOpacityChanged,
                  ),
                ),
              ],
            ),
          if (widget.isCameraLayerActive) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _PoseField(
                    fieldKey: 'camera-zoom-field',
                    label: 'Zoom %',
                    controller: _zoomController,
                    focusNode: _zoomFocus,
                    onSubmitted: _submitZoom,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PoseField(
                    fieldKey: 'camera-rotation-field',
                    label: 'Rot °',
                    controller: _rotationController,
                    focusNode: _rotationFocus,
                    onSubmitted: _submitRotation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  key: const ValueKey<String>('camera-set-key-button'),
                  tooltip: widget.hasKeyframeAtCurrentFrame
                      ? 'Update camera key at this frame'
                      : 'Add camera key at this frame',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    widget.hasKeyframeAtCurrentFrame
                        ? Icons.key
                        : Icons.key_outlined,
                    color: widget.hasKeyframeAtCurrentFrame
                        ? colorScheme.primary
                        : null,
                  ),
                  onPressed: () => widget.onPoseCommitted(widget.pose),
                ),
                IconButton(
                  key: const ValueKey<String>('camera-remove-key-button'),
                  tooltip: 'Remove camera key at this frame',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.key_off_outlined),
                  onPressed: widget.hasKeyframeAtCurrentFrame
                      ? widget.onRemoveKeyframe
                      : null,
                ),
                if (widget.onCopyAeKeyframes != null)
                  IconButton(
                    key: const ValueKey<String>('camera-copy-ae-button'),
                    tooltip: 'Copy AE Keyframes',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_all_outlined),
                    onPressed: widget.onCopyAeKeyframes,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PoseField extends StatelessWidget {
  const _PoseField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final String fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey<String>(fieldKey),
      controller: controller,
      focusNode: focusNode,
      style: Theme.of(context).textTheme.labelMedium,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
