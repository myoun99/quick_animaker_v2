import 'package:flutter/material.dart';

class CutNoteDialog extends StatefulWidget {
  const CutNoteDialog({super.key, required this.initialNote});

  final String initialNote;

  @override
  State<CutNoteDialog> createState() => _CutNoteDialogState();
}

class _CutNoteDialogState extends State<CutNoteDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Cut Note'),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey<String>('cut-note-text-field'),
          controller: _noteController,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Cut note',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('cancel-cut-note-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('save-cut-note-button'),
          onPressed: () => Navigator.of(context).pop(_noteController.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
