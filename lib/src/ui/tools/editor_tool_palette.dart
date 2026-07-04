import 'package:flutter/material.dart';

import 'editor_tool_mode.dart';

class EditorToolPalette extends StatelessWidget {
  const EditorToolPalette({
    super.key,
    required this.selectedToolMode,
    required this.onToolModeSelected,
  });

  final EditorToolMode selectedToolMode;
  final ValueChanged<EditorToolMode> onToolModeSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey<String>('editor-tool-palette'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(
              key: const ValueKey<String>('editor-tool-palette-brush'),
              mode: EditorToolMode.brush,
              selectedToolMode: selectedToolMode,
              tooltip: 'Brush',
              icon: Icons.brush_outlined,
              onSelected: onToolModeSelected,
            ),
            const SizedBox(height: 6),
            _ToolButton(
              key: const ValueKey<String>('editor-tool-palette-eraser'),
              mode: EditorToolMode.eraser,
              selectedToolMode: selectedToolMode,
              tooltip: 'Eraser',
              icon: Icons.cleaning_services_outlined,
              onSelected: onToolModeSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.mode,
    required this.selectedToolMode,
    required this.tooltip,
    required this.icon,
    required this.onSelected,
  });

  final EditorToolMode mode;
  final EditorToolMode selectedToolMode;
  final String tooltip;
  final IconData icon;
  final ValueChanged<EditorToolMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = mode == selectedToolMode;
    return IconButton.filledTonal(
      tooltip: tooltip,
      isSelected: selected,
      selectedIcon: Icon(icon),
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(40),
        fixedSize: const Size.square(40),
        padding: EdgeInsets.zero,
        side: selected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      onPressed: () => onSelected(mode),
    );
  }
}
