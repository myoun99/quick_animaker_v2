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

/// A tab in flight between (or within) tab groups.
class EditorPanelTabDragData {
  const EditorPanelTabDragData({
    required this.tabId,
    required this.fromGroupId,
  });

  final String tabId;
  final String fromGroupId;
}

/// The CSP-style tabbed panel shell: a compact tab strip on top, the active
/// tab's content below. Selection is CONTROLLED by the owner (so it can
/// persist per-view state across switches). Rule of thumb: the strip only
/// switches — tools/buttons belong to each panel's own toolbar below it.
///
/// When [groupId] and [onTabMoved] are given, tabs become draggable: within
/// the strip to reorder, and onto another group's strip to re-dock. Drop
/// position follows the pointer (left/right half of a hovered tab inserts
/// before/after it; the empty strip tail appends).
class EditorPanelTabs extends StatelessWidget {
  const EditorPanelTabs({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onTabSelected,
    this.compact = false,
    this.groupId,
    this.onTabMoved,
    this.canAcceptTab,
  }) : assert(tabs.length > 0),
       assert(
         onTabMoved == null || groupId != null,
         'Draggable tab groups need a groupId',
       );

  final List<EditorPanelTab> tabs;
  final String activeTabId;
  final ValueChanged<String> onTabSelected;

  /// Icon-only tab buttons (the label moves into the tooltip) — for narrow
  /// docks where full labels would overflow the strip.
  final bool compact;

  /// This group's identity in the dock layout; tags outgoing drags.
  final String? groupId;

  /// Called when a tab (possibly from another group) is dropped here.
  /// `insertIndex` counts this group's tabs BEFORE the moved tab is removed
  /// from its old position.
  final void Function(EditorPanelTabDragData data, int insertIndex)? onTabMoved;

  /// Whether a hovering tab may drop into this group (defaults to yes).
  final bool Function(EditorPanelTabDragData data)? canAcceptTab;

  static const double stripHeight = 30;

  bool get _dragEnabled => groupId != null && onTabMoved != null;

  bool _willAccept(EditorPanelTabDragData data) =>
      canAcceptTab?.call(data) ?? true;

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
              for (var index = 0; index < tabs.length; index += 1)
                _buildTabButton(index),
              if (_dragEnabled)
                Expanded(
                  child: _TabStripTailDropRegion(
                    willAccept: _willAccept,
                    onDropped: (data) => onTabMoved!(data, tabs.length),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
        Expanded(child: Builder(builder: active.builder)),
      ],
    );
  }

  Widget _buildTabButton(int index) {
    final tab = tabs[index];
    final button = _PanelTabButton(
      key: tab.buttonKey ?? ValueKey<String>('panel-tab-${tab.id}'),
      label: tab.label,
      icon: tab.icon,
      compact: compact,
      selected: tab.id == activeTabId,
      onPressed: () => onTabSelected(tab.id),
    );
    if (!_dragEnabled) {
      return button;
    }
    final data = EditorPanelTabDragData(tabId: tab.id, fromGroupId: groupId!);
    return _TabDropRegion(
      willAccept: _willAccept,
      // Left half inserts before this tab, right half after it.
      onDropped: (dropped, after) =>
          onTabMoved!(dropped, after ? index + 1 : index),
      child: Draggable<EditorPanelTabDragData>(
        data: data,
        maxSimultaneousDrags: 1,
        // The avatar origin IS the pointer, so drop regions can split
        // themselves into exact before/after halves from the drag offset.
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: _PanelTabDragFeedback(label: tab.label, icon: tab.icon),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: button),
        child: button,
      ),
    );
  }
}

/// Drop target around one tab button: highlights the insertion edge that
/// matches the pointer's half and reports before/after on drop.
class _TabDropRegion extends StatefulWidget {
  const _TabDropRegion({
    required this.willAccept,
    required this.onDropped,
    required this.child,
  });

  final bool Function(EditorPanelTabDragData data) willAccept;
  final void Function(EditorPanelTabDragData data, bool after) onDropped;
  final Widget child;

  @override
  State<_TabDropRegion> createState() => _TabDropRegionState();
}

class _TabDropRegionState extends State<_TabDropRegion> {
  /// Which insertion edge the hover points at; null while not hovered.
  bool? _hoverAfter;

  bool _isAfter(Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox;
    return box.globalToLocal(globalOffset).dx > box.size.width / 2;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<EditorPanelTabDragData>(
      onWillAcceptWithDetails: (details) => widget.willAccept(details.data),
      onMove: (details) {
        if (!widget.willAccept(details.data)) {
          return;
        }
        final after = _isAfter(details.offset);
        if (after != _hoverAfter) {
          setState(() => _hoverAfter = after);
        }
      },
      onLeave: (_) => setState(() => _hoverAfter = null),
      onAcceptWithDetails: (details) {
        setState(() => _hoverAfter = null);
        widget.onDropped(details.data, _isAfter(details.offset));
      },
      builder: (context, candidateData, rejectedData) {
        final hoverAfter = candidateData.isEmpty ? null : _hoverAfter;
        return Stack(
          children: [
            widget.child,
            if (hoverAfter != null)
              Positioned(
                left: hoverAfter ? null : 0,
                right: hoverAfter ? 0 : null,
                top: 0,
                bottom: 0,
                width: 2,
                child: ColoredBox(color: colorScheme.primary),
              ),
          ],
        );
      },
    );
  }
}

/// The empty strip tail: dropping there appends the tab to this group.
class _TabStripTailDropRegion extends StatelessWidget {
  const _TabStripTailDropRegion({
    required this.willAccept,
    required this.onDropped,
  });

  final bool Function(EditorPanelTabDragData data) willAccept;
  final void Function(EditorPanelTabDragData data) onDropped;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<EditorPanelTabDragData>(
      onWillAcceptWithDetails: (details) => willAccept(details.data),
      onAcceptWithDetails: (details) => onDropped(details.data),
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            const SizedBox.expand(),
            if (candidateData.isNotEmpty)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 2,
                child: ColoredBox(color: colorScheme.primary),
              ),
          ],
        );
      },
    );
  }
}

/// The floating chip under the pointer while a tab is dragged.
class _PanelTabDragFeedback extends StatelessWidget {
  const _PanelTabDragFeedback({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelTabButton extends StatelessWidget {
  const _PanelTabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.compact,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool compact;
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
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
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
              if (!compact) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}
