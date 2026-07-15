import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'panel_flyout.dart';

/// A split button: the body is the primary action (keeps its own key so
/// existing tests survive), the slim ▾ zone opens a [showPanelFlyout] with
/// the explicit variants.
class SplitIconButton extends StatelessWidget {
  const SplitIconButton({
    super.key,
    required this.buttonKey,
    required this.menuKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.entriesBuilder,
    this.accent = false,
  });

  /// Key for the primary-action body.
  final String buttonKey;

  /// Key for the ▾ dropdown zone.
  final String menuKey;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final List<PanelFlyoutEntry> Function() entriesBuilder;

  /// Accent border (the 'add' affordance).
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: accent ? AppColors.accent : AppColors.hairline,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey<String>(buttonKey),
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: accent ? AppColors.accent : null),
            iconSize: 18,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
          ),
          Builder(
            builder: (anchorContext) => Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey<String>(menuKey),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
                onTap: () =>
                    showPanelFlyout(anchorContext, entries: entriesBuilder()),
                child: SizedBox(
                  width: 14,
                  height: 28,
                  child: Icon(
                    Icons.arrow_drop_down,
                    size: 14,
                    color: accent ? AppColors.accent : AppColors.textDim,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
