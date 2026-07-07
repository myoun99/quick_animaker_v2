import 'package:flutter/material.dart';

import 'brush_tool_state.dart';

/// Which workspace edge a [ToolsPanel] bar is pinned to; the hairline
/// border faces the canvas.
enum ToolsPanelSide { left, right }

/// The Photoshop/Clip-Studio style tool bar: a slim vertical strip pinned
/// to a workspace edge (NOT a dockable tab) switching brush ⇄ eraser. The
/// workspace shows one on BOTH edges (mirror layout for left-handed use);
/// they share the tool state. Both tools share the brush options (size,
/// hardness, tip) — the eraser only flips the dabs into destination-out.
class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.tool,
    required this.onToolChanged,
    this.side = ToolsPanelSide.left,
  });

  final CanvasTool tool;
  final ValueChanged<CanvasTool> onToolChanged;
  final ToolsPanelSide side;

  static const double width = 44;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLeft = side == ToolsPanelSide.left;
    final borderSide = BorderSide(color: colorScheme.outlineVariant);
    // The left bar keeps the legacy un-suffixed keys; the right (mirror)
    // bar gets its own so finders stay unambiguous.
    final keySuffix = isLeft ? '' : '-right';
    return Container(
      key: ValueKey<String>('tools-panel$keySuffix'),
      width: ToolsPanel.width,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          left: isLeft ? BorderSide.none : borderSide,
          right: isLeft ? borderSide : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          _ToolButton(
            keyValue: 'tool-brush-button$keySuffix',
            tooltip: 'Brush Tool',
            icon: Icons.brush_outlined,
            selected: tool == CanvasTool.brush,
            onPressed: () => onToolChanged(CanvasTool.brush),
          ),
          const SizedBox(height: 4),
          _ToolButton(
            keyValue: 'tool-eraser-button$keySuffix',
            tooltip: 'Eraser Tool',
            // No dedicated eraser glyph in this icon set; the "magic
            // eraser" wand reads closest.
            icon: Icons.auto_fix_normal,
            selected: tool == CanvasTool.eraser,
            onPressed: () => onToolChanged(CanvasTool.eraser),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.keyValue,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String keyValue;
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey<String>(keyValue),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 20,
      isSelected: selected,
      style: IconButton.styleFrom(
        foregroundColor: selected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
        backgroundColor: selected
            ? colorScheme.surfaceContainerHigh
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
