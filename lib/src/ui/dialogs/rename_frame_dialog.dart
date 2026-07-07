import 'package:flutter/material.dart';

/// Rename dialog for a frame. Pops the new name text, or nothing on cancel.
/// SE rows reuse it with sheet wording (title/label overrides) — the frame
/// name IS the sheet's name/dialogue text there.
class RenameFrameDialog extends StatefulWidget {
  const RenameFrameDialog({
    super.key,
    required this.initialName,
    this.title = 'Rename Frame',
    this.fieldLabel = 'Frame name',
  });

  final String initialName;
  final String title;
  final String fieldLabel;

  @override
  State<RenameFrameDialog> createState() => _RenameFrameDialogState();
}

class _RenameFrameDialogState extends State<RenameFrameDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey<String>('rename-frame-text-field'),
        controller: _textController,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.fieldLabel),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('rename-frame-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('rename-frame-ok-button'),
          onPressed: () => Navigator.of(context).pop(_textController.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
