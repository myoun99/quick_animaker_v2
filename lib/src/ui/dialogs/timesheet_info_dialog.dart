import 'package:flutter/material.dart';

import '../../models/timesheet_info.dart';

/// Edits the sheet-header text (title/episode/scene/artist) the paper
/// timesheet reads, and which header boxes the form prints. Pops the
/// edited [TimesheetInfo], or null when cancelled.
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
  late final TextEditingController _sceneController = TextEditingController(
    text: widget.initialInfo.scene,
  );
  late final TextEditingController _artistController = TextEditingController(
    text: widget.initialInfo.artist,
  );
  late final Set<TimesheetHeaderField> _hiddenFields = {
    ...widget.initialInfo.hiddenFields,
  };

  static const Map<TimesheetHeaderField, String> _fieldLabels = {
    TimesheetHeaderField.title: 'Title',
    TimesheetHeaderField.episode: 'Episode',
    TimesheetHeaderField.scene: 'Scene',
    TimesheetHeaderField.cut: 'Cut',
    TimesheetHeaderField.time: 'Time',
    TimesheetHeaderField.name: 'Name',
    TimesheetHeaderField.sheet: 'Sheet',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _episodeController.dispose();
    _sceneController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      TimesheetInfo(
        title: _titleController.text.trim(),
        episode: _episodeController.text.trim(),
        scene: _sceneController.text.trim(),
        artist: _artistController.text.trim(),
        hiddenFields: {..._hiddenFields},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sheet Info'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                key: const ValueKey<String>('timesheet-info-scene-field'),
                controller: _sceneController,
                decoration: const InputDecoration(labelText: 'Scene'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey<String>('timesheet-info-artist-field'),
                controller: _artistController,
                decoration: const InputDecoration(labelText: 'Artist'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text(
                'Visible Boxes',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final field in TimesheetHeaderField.values)
                    FilterChip(
                      key: ValueKey<String>(
                        'timesheet-info-visible-${field.name}',
                      ),
                      label: Text(_fieldLabels[field]!),
                      selected: !_hiddenFields.contains(field),
                      onSelected: (visible) => setState(() {
                        if (visible) {
                          _hiddenFields.remove(field);
                        } else {
                          _hiddenFields.add(field);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
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
