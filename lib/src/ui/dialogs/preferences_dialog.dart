import 'package:flutter/material.dart';

import '../editor_session_manager.dart';
import 'accent_settings_dialog.dart' show AccentSettingsSection;
import 'autosave_settings_section.dart';
import 'input_settings_dialog.dart' show InputSettingsSection;
import 'language_settings_dialog.dart' show LanguageSettingsSection;

/// SAVE-1: the unified Preferences dialog — Input, Autosave, Language
/// and Accent Colors as sections of ONE window (the old per-domain Edit
/// menu entries collapsed here; their dialogs remain as thin wrappers
/// around the same section widgets for tests and deep links).
enum PreferencesSection { input, autosave, language, accent }

Future<void> showPreferencesDialog(
  BuildContext context, {
  required EditorSessionManager session,
  PreferencesSection initialSection = PreferencesSection.input,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _PreferencesDialog(session: session, initialSection: initialSection),
  );
}

class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog({
    required this.session,
    required this.initialSection,
  });

  final EditorSessionManager session;
  final PreferencesSection initialSection;

  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  late PreferencesSection _section = widget.initialSection;

  static String _labelOf(PreferencesSection section) => switch (section) {
    PreferencesSection.input => 'Input',
    PreferencesSection.autosave => 'Autosave',
    PreferencesSection.language => 'Language',
    PreferencesSection.accent => 'Accent Colors',
  };

  Widget _bodyOf(PreferencesSection section) => switch (section) {
    PreferencesSection.input => InputSettingsSection(session: widget.session),
    PreferencesSection.autosave => AutosaveSettingsSection(
      session: widget.session,
    ),
    PreferencesSection.language => LanguageSettingsSection(
      session: widget.session,
    ),
    PreferencesSection.accent => AccentSettingsSection(session: widget.session),
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('preferences-dialog'),
      title: const Text('Preferences'),
      content: SizedBox(
        width: 680,
        height: 460,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 150,
              child: ListView(
                children: [
                  for (final section in PreferencesSection.values)
                    ListTile(
                      key: ValueKey<String>(
                        'preferences-section-${section.name}',
                      ),
                      dense: true,
                      selected: section == _section,
                      title: Text(_labelOf(section)),
                      onTap: () => setState(() => _section = section),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 4),
                child: _bodyOf(_section),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('preferences-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
