import 'package:flutter/material.dart';

import '../panels/editor_panel_frame.dart';
import 'brush_tool_state.dart';

/// Left-dock tool switcher: brush ⇄ eraser. Both tools share the brush
/// options (size, hardness, tip) — the eraser only flips the dabs into
/// destination-out.
class ToolsPanel extends StatelessWidget {
  const ToolsPanel({
    super.key,
    required this.tool,
    required this.onToolChanged,
  });

  final CanvasTool tool;
  final ValueChanged<CanvasTool> onToolChanged;

  @override
  Widget build(BuildContext context) {
    return EditorPanelFrame(
      title: 'Tools',
      child: Row(
        key: const ValueKey<String>('tools-panel'),
        children: [
          _ToolButton(
            keyValue: 'tool-brush-button',
            tooltip: 'Brush Tool',
            icon: Icons.brush_outlined,
            selected: tool == CanvasTool.brush,
            onPressed: () => onToolChanged(CanvasTool.brush),
          ),
          const SizedBox(width: 4),
          _ToolButton(
            keyValue: 'tool-eraser-button',
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
