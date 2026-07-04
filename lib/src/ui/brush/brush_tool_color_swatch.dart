import 'package:flutter/material.dart';

class BrushToolColorSwatch extends StatelessWidget {
  const BrushToolColorSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onSelected,
    required this.label,
  });

  final int color;
  final bool selected;
  final ValueChanged<int> onSelected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final swatchColor = Color(color);
    return Tooltip(
      message: label,
      child: InkWell(
        key: ValueKey<String>('brush-tool-color-swatch-$label'),
        onTap: () => onSelected(color),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: swatchColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
