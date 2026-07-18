import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
                  'ON (default): finger pans scroll the grids — the edit '
                  'gestures release touch entirely.\n'
                  'OFF: touch edits exactly like the pen (select, move, '
                  'drag grips) — the safety net for pens that report as '
                  'touch.',
                ),
                value: settings.touchTimelineScroll,
                onChanged: (enabled) => session.setInputSettings(
                  settings.copyWith(touchTimelineScroll: enabled),
                ),
              ),
              // The CSP-style tablet service switch (PEN-2) — Windows
              // only: other platforms have a single native pen path.
              if (defaultTargetPlatform == TargetPlatform.windows) ...[
                const Divider(height: 16),
                Text(
                  'Tablet service',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                RadioGroup<TabletService>(
                  groupValue: settings.tabletService,
                  onChanged: (service) => session.setInputSettings(
                    settings.copyWith(tabletService: service),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<TabletService>(
                        key: ValueKey<String>('settings-tablet-standard'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Standard (default)'),
                        subtitle: Text(
                          'The OS pointer pipeline (Windows Ink) — right '
                          'for up-to-date drivers and built-in pens.',
                        ),
                        value: TabletService.standard,
                      ),
                      RadioListTile<TabletService>(
                        key: ValueKey<String>('settings-tablet-wintab'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Wintab'),
                        subtitle: Text(
                          'Reads pressure straight from the tablet driver '
                          '— the escape hatch when the pen arrives without '
                          'pressure or as touch/mouse.',
                        ),
                        value: TabletService.wintab,
                      ),
                    ],
                  ),
                ),
              ],
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
