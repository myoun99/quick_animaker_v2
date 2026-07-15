import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One entry of a [showPanelFlyout] list.
///
/// The app's shared popup-list vocabulary (the FieldSlider of menus): every
/// toolbar menu, legend bulk flyout and split-button dropdown builds from
/// these entries so they all read alike.
sealed class PanelFlyoutEntry {
  const PanelFlyoutEntry();
}

/// Non-interactive section caption.
class PanelFlyoutHeader extends PanelFlyoutEntry {
  const PanelFlyoutHeader(this.label);

  final String label;
}

/// Thin separator between groups.
class PanelFlyoutDivider extends PanelFlyoutEntry {
  const PanelFlyoutDivider();
}

/// A selectable command.
class PanelFlyoutItem extends PanelFlyoutEntry {
  const PanelFlyoutItem({
    required this.keyValue,
    required this.label,
    this.icon,
    this.checked,
    this.danger = false,
    this.enabled = true,
    this.onSelected,
  });

  /// Widget key string — menu items that replaced toolbar buttons reuse the
  /// retired button's key string so tests only gain a menu-open tap.
  final String keyValue;

  final String label;
  final IconData? icon;

  /// Trailing check when true; null means the item is not a toggle.
  final bool? checked;

  /// Destructive styling (delete commands).
  final bool danger;

  final bool enabled;

  /// Runs AFTER the flyout closes.
  final VoidCallback? onSelected;
}

/// Shows the shared flyout anchored under [anchorContext]'s widget and runs
/// the picked item's [PanelFlyoutItem.onSelected] after the menu closes.
Future<void> showPanelFlyout(
  BuildContext anchorContext, {
  required List<PanelFlyoutEntry> entries,
}) async {
  final button = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  final selected = await showMenu<PanelFlyoutItem>(
    context: anchorContext,
    position: position,
    items: [
      for (final entry in entries)
        switch (entry) {
          PanelFlyoutHeader(:final label) => PopupMenuItem<PanelFlyoutItem>(
            enabled: false,
            height: 24,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textDim),
            ),
          ),
          PanelFlyoutDivider() =>
            const PopupMenuDivider(height: 6)
                as PopupMenuEntry<PanelFlyoutItem>,
          PanelFlyoutItem() => PopupMenuItem<PanelFlyoutItem>(
            key: ValueKey<String>(entry.keyValue),
            value: entry,
            enabled: entry.enabled,
            height: 32,
            child: Row(
              children: [
                if (entry.icon != null) ...[
                  Icon(
                    entry.icon,
                    size: 16,
                    color: !entry.enabled
                        ? AppColors.textDim.withValues(alpha: 0.5)
                        : entry.danger
                        ? AppColors.danger
                        : AppColors.text,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    entry.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: !entry.enabled
                          ? AppColors.textDim.withValues(alpha: 0.5)
                          : entry.danger
                          ? AppColors.danger
                          : AppColors.text,
                    ),
                  ),
                ),
                if (entry.checked == true) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 14, color: AppColors.accent),
                ],
              ],
            ),
          ),
        },
    ],
  );
  selected?.onSelected?.call();
}

/// A labeled flyout trigger ('Layer ▾', 'Frame ▾', 'Cut ▾'): compact
/// bordered chip that opens [showPanelFlyout] with lazily built entries.
class PanelFlyoutButton extends StatelessWidget {
  const PanelFlyoutButton({
    super.key,
    required this.label,
    required this.entriesBuilder,
    this.tooltip,
  });

  final String label;
  final List<PanelFlyoutEntry> Function() entriesBuilder;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => showPanelFlyout(context, entries: entriesBuilder()),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 5, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: AppColors.textDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) {
      return chip;
    }
    return Tooltip(message: tooltip!, child: chip);
  }
}
