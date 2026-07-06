import 'package:flutter/material.dart';

import '../../models/camera_pose.dart';

/// The slim camera control row above the canvas.
///
/// Always shows the camera-view toggle (overlay + dimmed surroundings) with
/// its dim-opacity slider. While the camera layer is active it additionally
/// shows the pose controls for the playhead frame: zoom/rotation numeric
/// fields and key set/remove buttons.
class CameraToolbar extends StatefulWidget {
  const CameraToolbar({
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

  @override
  State<CameraToolbar> createState() => _CameraToolbarState();
}

class _CameraToolbarState extends State<CameraToolbar> {
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
  void didUpdateWidget(covariant CameraToolbar oldWidget) {
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
    return SizedBox(
      height: 36,
      child: Row(
        key: const ValueKey<String>('camera-toolbar'),
        children: [
          IconButton(
            key: const ValueKey<String>('camera-view-toggle'),
            tooltip: 'Camera View',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            isSelected: widget.cameraViewEnabled,
            selectedIcon: Icon(Icons.videocam, color: colorScheme.primary),
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () =>
                widget.onCameraViewChanged(!widget.cameraViewEnabled),
          ),
          if (widget.cameraViewEnabled) ...[
            Tooltip(
              message: 'Outside dim',
              child: SizedBox(
                width: 90,
                child: Slider(
                  key: const ValueKey<String>('camera-dim-slider'),
                  min: 0,
                  max: 0.95,
                  value: widget.dimOpacity.clamp(0.0, 0.95).toDouble(),
                  onChanged: widget.onDimOpacityChanged,
                ),
              ),
            ),
          ],
          if (widget.isCameraLayerActive) ...[
            const SizedBox(width: 8),
            _PoseField(
              fieldKey: 'camera-zoom-field',
              label: 'Zoom %',
              controller: _zoomController,
              focusNode: _zoomFocus,
              onSubmitted: _submitZoom,
            ),
            const SizedBox(width: 8),
            _PoseField(
              fieldKey: 'camera-rotation-field',
              label: 'Rot °',
              controller: _rotationController,
              focusNode: _rotationFocus,
              onSubmitted: _submitRotation,
            ),
            const SizedBox(width: 4),
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
    return SizedBox(
      width: 76,
      child: TextField(
        key: ValueKey<String>(fieldKey),
        controller: controller,
        focusNode: focusNode,
        style: Theme.of(context).textTheme.labelMedium,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}
