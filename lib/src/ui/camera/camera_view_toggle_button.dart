import 'package:flutter/material.dart';

import '../theme/app_theme.dart' show AppColors;

/// The CAMERA VIEW toggle that sits beside a command bar's transport
/// (R27 #1, unified across panels by R28 #1).
///
/// Camera view is a VIEW MODE, not a property of the timeline: the same
/// button therefore belongs on every panel that carries a transport. Both
/// entrances drive the one notifier the workspace owns, so the state can
/// never disagree between panels.
///
/// [keyValue] distinguishes the mounts for finders; everything else about
/// the button — icon, sizing, lit color, tooltip wording — lives here so a
/// restyle lands on every panel at once.
class CameraViewToggleButton extends StatelessWidget {
  const CameraViewToggleButton({
    super.key,
    required this.enabled,
    required this.keyValue,
  });

  /// Null hosts skip the button entirely (a panel without camera context).
  final ValueNotifier<bool>? enabled;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    final notifier = enabled;
    if (notifier == null) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, isOn, _) => IconButton(
        key: ValueKey<String>(keyValue),
        tooltip: isOn ? 'Camera view (on)' : 'Camera view',
        visualDensity: VisualDensity.compact,
        onPressed: () => notifier.value = !isOn,
        icon: Icon(
          Icons.videocam_outlined,
          size: 18,
          color: isOn
              ? AppColors.accent
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
