import 'package:flutter/material.dart';

/// Asks whether to link to an existing frame that already uses the entered
/// name so identical names share the same material. Pops `true` to link.
class FrameNameConflictDialog extends StatelessWidget {
  const FrameNameConflictDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('frame-name-conflict-dialog'),
      title: const Text('Frame name already exists'),
      content: const Text(
        'This name is already used by another frame in this layer. Link to '
        'the existing named frame so the same name shares the same material?',
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('frame-name-conflict-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('frame-name-conflict-link-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Link'),
        ),
      ],
    );
  }
}
