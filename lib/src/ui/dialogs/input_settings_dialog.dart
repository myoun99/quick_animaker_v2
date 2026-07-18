import 'package:flutter/material.dart';

import '../editor_session_manager.dart';
import '../input/app_input_settings.dart';

/// The pointer-input settings dialog (UI-R22 #6). One toggle decides
/// what a TOUCH contact means on the timeline grids — scroll or edit —
/// exclusively, so scrolling and editing never race over one contact.
Future<void> showInputSettingsDialog(
  BuildContext context, {
  required EditorSessionManager session,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _InputSettingsDialog(session: session),
  );
}

class _InputSettingsDialog extends StatelessWidget {
  const _InputSettingsDialog({required this.session});

  final EditorSessionManager session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppInputSettings>(
      valueListenable: AppInput.settings,
      builder: (context, settings, _) {
        return AlertDialog(
          title: const Text('Input Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                key: const ValueKey<String>('settings-touch-timeline-scroll'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Touch scrolls the timeline'),
                subtitle: const Text(
                  'ON: finger pans scroll the grids — the edit gestures '
                  'release touch entirely.\n'
                  'OFF (default): touch edits exactly like the pen '
                  '(select, move, drag grips) — pens that report as '
                  'touch keep full power.',
                ),
                value: settings.touchTimelineScroll,
                onChanged: (enabled) => session.setInputSettings(
                  settings.copyWith(touchTimelineScroll: enabled),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey<String>('settings-input-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
