import 'package:flutter/material.dart';

import '../editor_session_manager.dart';
import '../playback/audio_sync_settings.dart';

/// Audio program 2D: the A/V offset and the sync inspector
/// (Preferences ▸ Audio).
///
/// The offset is the RESIDUAL correction — what remains after the device's
/// reported latency is applied automatically. It describes this machine's
/// output path (screen pipeline, Bluetooth, an AV receiver), which is why
/// it lives in app settings and not in the project file.
class AudioSettingsSection extends StatefulWidget {
  const AudioSettingsSection({super.key, required this.session});

  final EditorSessionManager session;

  @override
  State<AudioSettingsSection> createState() => _AudioSettingsSectionState();
}

class _AudioSettingsSectionState extends State<AudioSettingsSection> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioSyncSettings>(
      valueListenable: widget.session.audioSyncSettings,
      builder: (context, settings, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A/V offset',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fine-tunes when the picture is shown relative to the sound. '
              'The measurable part of the delay is corrected automatically; '
              'this removes what remains — wireless headphones commonly sit '
              '150–300 ms behind and report nothing. Positive shows the '
              'picture LATER (sound arriving late is the common case).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Offset', style: TextStyle(fontSize: 12)),
                ),
                SizedBox(
                  width: 72,
                  child: _OffsetField(
                    key: const ValueKey<String>('settings-av-offset-value'),
                    offset: settings.offset,
                    unit: settings.unit,
                    onCommitted: (value) => widget.session.setAudioSyncSettings(
                      settings.copyWith(
                        offset: AudioSyncSettings.clampOffset(
                          value,
                          settings.unit,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<AvOffsetUnit>(
                  key: const ValueKey<String>('settings-av-offset-unit'),
                  value: settings.unit,
                  isDense: true,
                  style: const TextStyle(fontSize: 12),
                  items: const [
                    DropdownMenuItem(
                      value: AvOffsetUnit.milliseconds,
                      child: Text('ms'),
                    ),
                    DropdownMenuItem(
                      value: AvOffsetUnit.frames,
                      child: Text('frames'),
                    ),
                  ],
                  // Switching units keeps the NUMBER (it is what the user
                  // typed), re-clamped into the new unit's range.
                  onChanged: (unit) {
                    if (unit != null && unit != settings.unit) {
                      widget.session.setAudioSyncSettings(
                        AudioSyncSettings(
                          offset: AudioSyncSettings.clampOffset(
                            settings.offset,
                            unit,
                          ),
                          unit: unit,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sync inspector',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('settings-audio-report-refresh'),
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: 'Refresh',
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // One pasteable line — a real-device report should be evidence,
            // not an impression.
            SelectableText(
              widget.session.audioDeviceTransport.report.summary,
              key: const ValueKey<String>('settings-audio-report'),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        );
      },
    );
  }
}

/// A compact signed-integer field that commits on submit/focus loss and
/// snaps back to the live value on bad input (mirrors the autosave
/// minutes field).
class _OffsetField extends StatefulWidget {
  const _OffsetField({
    super.key,
    required this.offset,
    required this.unit,
    required this.onCommitted,
  });

  final int offset;
  final AvOffsetUnit unit;
  final ValueChanged<int> onCommitted;

  @override
  State<_OffsetField> createState() => _OffsetFieldState();
}

class _OffsetFieldState extends State<_OffsetField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.offset}',
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _OffsetField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.offset != oldWidget.offset || widget.unit != oldWidget.unit) &&
        !_focus.hasFocus) {
      _controller.text = '${widget.offset}';
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = '${widget.offset}';
      return;
    }
    if (parsed != widget.offset) {
      widget.onCommitted(parsed);
    } else {
      // Same value: still normalize the text (e.g. "+3" → "3").
      _controller.text = '${widget.offset}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      textAlign: TextAlign.end,
      style: const TextStyle(fontSize: 12),
      decoration: const InputDecoration(isDense: true),
      onSubmitted: (_) => _commit(),
    );
  }
}
