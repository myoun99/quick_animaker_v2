import 'package:flutter/material.dart';

/// Rename dialog for a frame. Pops the new name text, or nothing on cancel.
class RenameFrameDialog extends StatefulWidget {
  const RenameFrameDialog({super.key, required this.initialName});

  final String initialName;

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
      title: const Text('Rename Frame'),
      content: TextField(
        key: const ValueKey<String>('rename-frame-text-field'),
        controller: _textController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Frame name'),
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
