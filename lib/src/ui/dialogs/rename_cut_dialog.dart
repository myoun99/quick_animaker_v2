import 'package:flutter/material.dart';

/// Rename dialog for a cut. Pops the new name text, or nothing on cancel.
class RenameCutDialog extends StatefulWidget {
  const RenameCutDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<RenameCutDialog> createState() => _RenameCutDialogState();
}

class _RenameCutDialogState extends State<RenameCutDialog> {
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
      title: const Text('Rename Cut'),
      content: TextField(
        key: const ValueKey<String>('rename-cut-text-field'),
        controller: _textController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Cut name'),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('rename-cut-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('rename-cut-confirm-button'),
          onPressed: () => Navigator.of(context).pop(_textController.text),
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
