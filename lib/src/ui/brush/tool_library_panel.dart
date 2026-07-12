import 'package:flutter/material.dart';

import 'brush_tool_state.dart';

/// The TOOL LIBRARY panel (R11-④, CSP's sub-tool palette): its content
/// follows the active tool. The brush and the eraser show the brush
/// preset library (each remembers its own selection —
/// PaintToolStateNotifier), the selection tools list their variants
/// (rectangle / lasso), and the single-action tools show a short usage
/// note. Detailed knobs live in the TOOL SETTINGS panel.
class ToolLibraryPanel extends StatelessWidget {
  const ToolLibraryPanel({
    super.key,
    required this.tool,
    required this.onToolChanged,
    required this.brushLibrary,
  });

  final CanvasTool tool;
  final ValueChanged<CanvasTool> onToolChanged;

  /// The brush preset library content (built by the workspace, which owns
  /// the preset state) — shown for the painting tools.
  final Widget brushLibrary;

  @override
  Widget build(BuildContext context) {
    switch (tool) {
      case CanvasTool.brush:
      case CanvasTool.eraser:
        return brushLibrary;
      case CanvasTool.selectRect:
      case CanvasTool.lasso:
        return ListView(
          key: const ValueKey<String>('tool-library-selection'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            _SubToolTile(
              keyValue: 'sub-tool-select-rect',
              icon: Icons.highlight_alt_outlined,
              label: 'Rectangle Select',
              selected: tool == CanvasTool.selectRect,
              onTap: () => onToolChanged(CanvasTool.selectRect),
            ),
            _SubToolTile(
              keyValue: 'sub-tool-lasso',
              icon: Icons.gesture,
              label: 'Lasso Select',
              selected: tool == CanvasTool.lasso,
              onTap: () => onToolChanged(CanvasTool.lasso),
            ),
          ],
        );
      case CanvasTool.eyedropper:
        return const _ToolNote(
          keyValue: 'tool-library-eyedropper',
          note:
              'Eyedropper picks the visible color under the pointer.\n'
              'Hold Alt to pick temporarily while painting.',
        );
      case CanvasTool.fill:
        return const _ToolNote(
          keyValue: 'tool-library-fill',
          note:
              'Fill floods the tapped region with the current color.\n'
              'Tolerance, expand and anti-alias live in Tool Settings.',
        );
    }
  }
}

class _SubToolTile extends StatelessWidget {
  const _SubToolTile({
    required this.keyValue,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String keyValue;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Own Material: the dock body paints a background color, and ListTile
    // ink/selection tints render on the nearest Material ancestor.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: ValueKey<String>(keyValue),
        dense: true,
        leading: Icon(
          icon,
          size: 18,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(label),
        // Selection reads from the color alone (no trailing check glyph —
        // the strip must not jump, per the selection-style rule).
        selected: selected,
        selectedTileColor: colorScheme.surfaceContainerHigh,
        onTap: onTap,
      ),
    );
  }
}

class _ToolNote extends StatelessWidget {
  const _ToolNote({required this.keyValue, required this.note});

  final String keyValue;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey<String>(keyValue),
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
