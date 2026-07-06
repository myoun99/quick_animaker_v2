import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/canvas_size.dart';

/// Canvas-size dialog for a cut. Pops the new [CanvasSize], or nothing on
/// cancel. Existing artwork keeps its coordinates (top-left anchor), so
/// shrinking crops non-destructively and growing adds transparent space.
class CanvasSizeDialog extends StatefulWidget {
  const CanvasSizeDialog({super.key, required this.initialSize});

  static const int minDimension = 1;
  static const int maxDimension = 8192;

  final CanvasSize initialSize;

  @override
  State<CanvasSizeDialog> createState() => _CanvasSizeDialogState();
}

class _CanvasSizeDialogState extends State<CanvasSizeDialog> {
  static const _presets = <(String, CanvasSize)>[
    ('Default', CanvasSize(width: 2340, height: 1654)),
    ('HD', CanvasSize(width: 1280, height: 720)),
    ('FHD', CanvasSize(width: 1920, height: 1080)),
    ('4K', CanvasSize(width: 3840, height: 2160)),
  ];

  late final TextEditingController _widthController = TextEditingController(
    text: '${widget.initialSize.width}',
  );
  late final TextEditingController _heightController = TextEditingController(
    text: '${widget.initialSize.height}',
  );

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  int? _parseDimension(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null ||
        value < CanvasSizeDialog.minDimension ||
        value > CanvasSizeDialog.maxDimension) {
      return null;
    }
    return value;
  }

  CanvasSize? get _enteredSize {
    final width = _parseDimension(_widthController);
    final height = _parseDimension(_heightController);
    if (width == null || height == null) {
      return null;
    }
    return CanvasSize(width: width, height: height);
  }

  void _applyPreset(CanvasSize size) {
    setState(() {
      _widthController.text = '${size.width}';
      _heightController.text = '${size.height}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final enteredSize = _enteredSize;

    return AlertDialog(
      title: const Text('Canvas Size'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('canvas-size-width-field'),
                  controller: _widthController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Width (px)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('canvas-size-height-field'),
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Height (px)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, size) in _presets)
                ActionChip(
                  key: ValueKey<String>(
                    'canvas-size-preset-${size.width}x${size.height}',
                  ),
                  label: Text('$label ${size.width}×${size.height}'),
                  onPressed: () => _applyPreset(size),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Artwork keeps its position from the top-left corner. '
            'Cropped strokes are restored if the canvas is enlarged again. '
            '(${CanvasSizeDialog.minDimension}–${CanvasSizeDialog.maxDimension} px)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('canvas-size-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('canvas-size-confirm-button'),
          onPressed: enteredSize == null
              ? null
              : () => Navigator.of(context).pop(enteredSize),
          child: const Text('Resize'),
        ),
      ],
    );
  }
}
