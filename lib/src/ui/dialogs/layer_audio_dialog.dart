import 'package:flutter/material.dart';

import '../../models/layer_id.dart';
import '../editor_session_manager.dart';
import '../widgets/field_slider.dart';

/// AUDIO-PRO R1: the SE row's track fader + pan — the layer-level mix
/// controls (clip gain/fades stay on the lane). Opened from the speaker
/// button's context menu.
Future<void> showLayerAudioDialog(
  BuildContext context, {
  required EditorSessionManager session,
  required LayerId layerId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LayerAudioDialog(session: session, layerId: layerId),
  );
}

class _LayerAudioDialog extends StatefulWidget {
  const _LayerAudioDialog({required this.session, required this.layerId});

  final EditorSessionManager session;
  final LayerId layerId;

  @override
  State<_LayerAudioDialog> createState() => _LayerAudioDialogState();
}

class _LayerAudioDialogState extends State<_LayerAudioDialog> {
  late double _gain;
  late double _pan;

  @override
  void initState() {
    super.initState();
    final layer = widget.session.layers
        .where((layer) => layer.id == widget.layerId)
        .firstOrNull;
    _gain = (layer?.audioGain ?? 1.0).clamp(0.0, 2.0);
    _pan = (layer?.audioPan ?? 0.0).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('layer-audio-dialog'),
      title: const Text('Layer Audio'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FieldSlider(
              key: const ValueKey<String>('layer-audio-gain-slider'),
              min: 0,
              max: 2,
              value: _gain,
              label: 'Gain',
              valueText: '${(_gain * 100).round()}%',
              displayFactor: 100,
              onChanged: (value) => setState(() => _gain = value),
            ),
            const SizedBox(height: 8),
            FieldSlider(
              key: const ValueKey<String>('layer-audio-pan-slider'),
              min: -1,
              max: 1,
              value: _pan,
              label: 'Pan',
              valueText: _pan == 0
                  ? 'C'
                  : _pan < 0
                  ? 'L${(-_pan * 100).round()}'
                  : 'R${(_pan * 100).round()}',
              displayFactor: 100,
              onChanged: (value) => setState(() => _pan = value),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pan applies on the device mixer path (equal-power law).',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('layer-audio-apply'),
          onPressed: () {
            widget.session.setLayerAudio(
              layerId: widget.layerId,
              gain: _gain,
              pan: _pan,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
