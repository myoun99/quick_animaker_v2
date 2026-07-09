import 'package:flutter/material.dart';

import 'instance_edit_dialog.dart';
import 'instance_edit_preview.dart';
import 'instance_length_field.dart';

/// What the SE instance dialog resolved to: the (possibly empty) speaker
/// name, the dialogue text and — when creating — the entered length.
class SeInstanceDialogResult {
  const SeInstanceDialogResult({
    required this.seName,
    required this.dialogue,
    this.lengthFrames,
  });

  final String seName;
  final String dialogue;

  /// The new instance's length in frames (creation only; null on edits —
  /// existing blocks resize with their grips).
  final int? lengthFrames;
}

/// The SE layer's instance editor — name (speaker/effect, accent box) +
/// dialogue (can run long → multiline) with the live paper-block preview.
/// Creating also asks for the block LENGTH (s+k / frames notation, both
/// persisted) — new entries no longer auto-run to the cut end. Pops a
/// [SeInstanceDialogResult], or nothing on cancel.
class SeInstanceDialog extends StatefulWidget {
  const SeInstanceDialog({
    super.key,
    this.initialSeName = '',
    this.initialDialogue = '',
    this.creating = false,
    this.previewAxis = Axis.horizontal,
    this.fps = 24,
  });

  final String initialSeName;
  final String initialDialogue;

  /// Whether a new entry is being created (title wording + length field).
  final bool creating;

  /// Follows the timeline orientation so the preview matches what the
  /// user is looking at.
  final Axis previewAxis;

  /// The project fps — the length field's s+k notation needs it.
  final int fps;

  @override
  State<SeInstanceDialog> createState() => _SeInstanceDialogState();
}

class _SeInstanceDialogState extends State<SeInstanceDialog> {
  late final TextEditingController _seNameController = TextEditingController(
    text: widget.initialSeName,
  );
  late final TextEditingController _dialogueController = TextEditingController(
    text: widget.initialDialogue,
  );
  int? _lengthFrames = InstanceLengthMemory.lengthFrames;

  @override
  void initState() {
    super.initState();
    // Live preview: repaint on every keystroke.
    _seNameController.addListener(_onFieldsChanged);
    _dialogueController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() => setState(() {});

  @override
  void dispose() {
    _seNameController.dispose();
    _dialogueController.dispose();
    super.dispose();
  }

  void _submit() {
    final lengthFrames = widget.creating ? _lengthFrames : null;
    if (widget.creating) {
      if (lengthFrames == null) {
        return;
      }
      InstanceLengthMemory.lengthFrames = lengthFrames;
    }
    Navigator.of(context).pop(
      SeInstanceDialogResult(
        seName: _seNameController.text.trim(),
        dialogue: _dialogueController.text.trim(),
        lengthFrames: lengthFrames,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InstanceEditDialogShell(
      title: widget.creating ? 'New SE' : 'Edit SE',
      titleIcon: Icons.music_note_outlined,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey<String>('se-name-field'),
            controller: _seNameController,
            decoration: const InputDecoration(
              labelText: 'Name (speaker — blank hides the box)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('se-dialogue-field'),
            controller: _dialogueController,
            autofocus: true,
            minLines: 2,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Dialogue'),
          ),
          if (widget.creating) ...[
            const SizedBox(height: 8),
            InstanceLengthField(
              fps: widget.fps,
              onChanged: (lengthFrames) =>
                  setState(() => _lengthFrames = lengthFrames),
            ),
          ],
        ],
      ),
      preview: InstanceEditPreview.se(
        axis: widget.previewAxis,
        dialogue: _dialogueController.text.trim(),
        seName: _seNameController.text.trim(),
      ),
      onSubmit: widget.creating && _lengthFrames == null ? null : _submit,
    );
  }
}
