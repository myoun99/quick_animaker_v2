import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One tab in an [EditorPanelTabs] group.
class EditorPanelTab {
  const EditorPanelTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.buttonKey,
    this.minContentWidth,
    this.minContentHeight,
    this.locked = false,
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

  /// Smallest size this panel lays out at. When the tab is docked somewhere
  /// smaller (frame-axis panels in a side dock), the shell hosts it at this
  /// size inside scrollers instead of letting its fixed rails and toolbars
  /// overflow.
  final double? minContentWidth;
  final double? minContentHeight;

  /// Drag-locked tabs stay put (the canvas panel defaults to locked so a
  /// stray drag can't undock the drawing surface).
  final bool locked;
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
/// When [groupId] and [onTabMoved] are given, tabs become draggable (drag
/// starts immediately on pointer movement; a plain tap still just
/// switches): within the strip to reorder, and onto another group's strip
/// to re-dock. Drop position follows the pointer (left/right half of a
/// hovered tab inserts before/after it; the empty strip tail appends).
/// LOCKED tabs ([EditorPanelTab.locked]) refuse to lift; [onToggleLock]
/// puts a lock toggle for the active tab at the strip's end.
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
    this.onTabDragChanged,
    this.onToggleLock,
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

  /// Fires with the drag data when a tab lifts off this strip and with
  /// null when the drag ends — lets the dock layout reveal its drop zones
  /// for the tab in flight.
  final ValueChanged<EditorPanelTabDragData?>? onTabDragChanged;

  /// Toggles a tab's drag lock (the ACTIVE tab button carries the toggle,
  /// left of its name). Null hides the toggle.
  final ValueChanged<String>? onToggleLock;

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
        Expanded(child: _buildActiveContent(active)),
      ],
    );
  }

  /// The active tab's content; panels with a minimum content size larger
  /// than the dock render at that size inside scrollers.
  Widget _buildActiveContent(EditorPanelTab active) {
    if (active.minContentWidth == null && active.minContentHeight == null) {
      return Builder(builder: active.builder);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          active.minContentWidth ?? 0,
          constraints.maxWidth,
        );
        final height = math.max(
          active.minContentHeight ?? 0,
          constraints.maxHeight,
        );
        if (width <= constraints.maxWidth && height <= constraints.maxHeight) {
          return Builder(builder: active.builder);
        }
        Widget content = SizedBox(
          width: width,
          height: height,
          child: Builder(builder: active.builder),
        );
        if (height > constraints.maxHeight) {
          content = SingleChildScrollView(child: content);
        }
        if (width > constraints.maxWidth) {
          content = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          );
        }
        return content;
      },
    );
  }

  Widget _buildTabButton(int index) {
    final tab = tabs[index];
    final selected = tab.id == activeTabId;
    final button = _PanelTabButton(
      key: tab.buttonKey ?? ValueKey<String>('panel-tab-${tab.id}'),
      label: tab.label,
      icon: tab.icon,
      compact: compact,
      selected: selected,
      locked: tab.locked,
      lockKey: ValueKey<String>('panel-lock-${tab.id}'),
      // The ACTIVE tab carries the drag-lock toggle, left of its name.
      onToggleLock: selected && onToggleLock != null
          ? () => onToggleLock!(tab.id)
          : null,
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
      // Locked tabs stay drop targets but refuse to lift.
      child: tab.locked
          ? button
          : Draggable<EditorPanelTabDragData>(
              data: data,
              maxSimultaneousDrags: 1,
              // The avatar origin IS the pointer, so drop regions can split
              // themselves into exact before/after halves from the drag
              // offset.
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: _PanelTabDragFeedback(label: tab.label, icon: tab.icon),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: button),
              onDragStarted: () => onTabDragChanged?.call(data),
              // onDragEnd covers completion AND cancellation.
              onDragEnd: (_) => onTabDragChanged?.call(null),
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

/// The tappable drag-lock glyph on an active tab button.
class _TabLockGlyph extends StatelessWidget {
  const _TabLockGlyph({
    required this.lockKey,
    required this.label,
    required this.locked,
    required this.color,
    required this.onToggleLock,
  });

  final Key lockKey;
  final String label;
  final bool locked;
  final Color color;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: locked ? 'Unlock $label drag' : 'Lock $label drag',
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(
        key: lockKey,
        behavior: HitTestBehavior.opaque,
        onTap: onToggleLock,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            locked ? Icons.lock_outline : Icons.lock_open,
            size: 11,
            color: color,
          ),
        ),
      ),
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
    required this.locked,
    required this.lockKey,
    required this.onPressed,
    this.onToggleLock,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final bool selected;
  final bool locked;
  final Key lockKey;
  final VoidCallback onPressed;

  /// Non-null on the active tab: taps on the lock glyph toggle the drag
  /// lock instead of re-selecting the tab.
  final VoidCallback? onToggleLock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: label,
      // Manual trigger: hover tooltips still work, but no long-press
      // recognizer competes with the tab's LongPressDraggable lift.
      triggerMode: TooltipTriggerMode.manual,
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
              // The drag-lock lives on the tab itself, left of the panel
              // name: tappable on the active tab, a passive badge on
              // locked inactive tabs.
              if (onToggleLock != null) ...[
                const SizedBox(width: 4),
                _TabLockGlyph(
                  lockKey: lockKey,
                  label: label,
                  locked: locked,
                  color: foreground,
                  onToggleLock: onToggleLock!,
                ),
              ] else if (locked) ...[
                const SizedBox(width: 4),
                Icon(Icons.lock_outline, size: 10, color: foreground),
              ],
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
