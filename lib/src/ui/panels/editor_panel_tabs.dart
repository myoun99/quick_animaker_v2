import 'package:flutter/material.dart';

/// One tab in an [EditorPanelTabs] group.
class EditorPanelTab {
  const EditorPanelTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.buttonKey,
  });

  /// Stable identifier the group reports through `onTabSelected`.
  final String id;

  final String label;
  final IconData icon;

  /// Builds the tab's content; only the ACTIVE tab is built (panel state
  /// that must survive switches lives above the tab group).
  final WidgetBuilder builder;

  /// Key for the tab strip button. Groups replacing older toggle buttons
  /// keep the legacy keys here so existing flows and tests keep working.
  final Key? buttonKey;
}

/// The CSP-style tabbed panel shell: a compact tab strip on top, the active
/// tab's content below. Selection is CONTROLLED by the owner (so it can
/// persist per-view state across switches). Rule of thumb: the strip only
/// switches — tools/buttons belong to each panel's own toolbar below it.
class EditorPanelTabs extends StatelessWidget {
  const EditorPanelTabs({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onTabSelected,
  }) : assert(tabs.length > 0);

  final List<EditorPanelTab> tabs;
  final String activeTabId;
  final ValueChanged<String> onTabSelected;

  static const double stripHeight = 30;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = tabs.firstWhere(
      (tab) => tab.id == activeTabId,
      orElse: () => tabs.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: EditorPanelTabs.stripHeight,
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              for (final tab in tabs)
                _PanelTabButton(
                  key: tab.buttonKey ?? ValueKey<String>('panel-tab-${tab.id}'),
                  label: tab.label,
                  icon: tab.icon,
                  selected: tab.id == active.id,
                  onPressed: () => onTabSelected(tab.id),
                ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(child: Builder(builder: active.builder)),
      ],
    );
  }
}

class _PanelTabButton extends StatelessWidget {
  const _PanelTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.surfaceContainerHighest
                : Colors.transparent,
            border: Border(
              top: BorderSide(
                width: 2,
                color: selected ? colorScheme.primary : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
