import 'package:flutter/material.dart';

class EditorPanelHeader extends StatelessWidget {
  const EditorPanelHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('editor-panel-header'),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              key: ValueKey<String>('editor-panel-header-title-$title'),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
