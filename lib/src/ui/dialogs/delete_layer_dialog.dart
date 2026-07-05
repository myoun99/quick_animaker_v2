import 'package:flutter/material.dart';

/// Confirmation dialog for deleting a layer. Pops `true` to confirm.
class DeleteLayerDialog extends StatelessWidget {
  const DeleteLayerDialog({super.key, required this.layerName});

  final String layerName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('delete-layer-dialog'),
      title: const Text('Delete Layer'),
      content: Text('Delete layer "$layerName"?'),
      actions: [
        TextButton(
          key: const ValueKey<String>('delete-layer-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('delete-layer-confirm-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
