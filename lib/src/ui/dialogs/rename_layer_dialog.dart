import 'package:flutter/material.dart';

/// Rename dialog for a layer. Pops the trimmed new name, or nothing on cancel.
/// Rejects an empty name inline.
class RenameLayerDialog extends StatefulWidget {
  const RenameLayerDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<RenameLayerDialog> createState() => _RenameLayerDialogState();
}

class _RenameLayerDialogState extends State<RenameLayerDialog> {
  late final TextEditingController _textController;
  String? _errorText;

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

  void _submit() {
    final trimmedName = _textController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _errorText = 'Layer name cannot be empty.');
      return;
    }
    Navigator.of(context).pop(trimmedName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('rename-layer-dialog'),
      title: const Text('Rename Layer'),
      content: TextField(
        key: const ValueKey<String>('rename-layer-text-field'),
        controller: _textController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Layer name',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('rename-layer-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('rename-layer-ok-button'),
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
