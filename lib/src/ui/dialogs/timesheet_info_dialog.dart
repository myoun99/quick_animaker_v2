import 'package:flutter/material.dart';

import '../../models/timesheet_info.dart';

/// Edits the sheet-header text (title/episode/artist) the paper timesheet
/// reads. Pops the edited [TimesheetInfo], or null when cancelled.
class TimesheetInfoDialog extends StatefulWidget {
  const TimesheetInfoDialog({super.key, required this.initialInfo});

  final TimesheetInfo initialInfo;

  @override
  State<TimesheetInfoDialog> createState() => _TimesheetInfoDialogState();
}

class _TimesheetInfoDialogState extends State<TimesheetInfoDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialInfo.title,
  );
  late final TextEditingController _episodeController = TextEditingController(
    text: widget.initialInfo.episode,
  );
  late final TextEditingController _artistController = TextEditingController(
    text: widget.initialInfo.artist,
  );

  @override
  void dispose() {
    _titleController.dispose();
    _episodeController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      TimesheetInfo(
        title: _titleController.text.trim(),
        episode: _episodeController.text.trim(),
        artist: _artistController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sheet Info'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey<String>('timesheet-info-title-field'),
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Project name when empty',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('timesheet-info-episode-field'),
              controller: _episodeController,
              decoration: const InputDecoration(labelText: 'Episode'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('timesheet-info-artist-field'),
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artist'),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('timesheet-info-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('timesheet-info-save-button'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
