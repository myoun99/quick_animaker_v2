import 'package:flutter/material.dart';

class EditorPanelDock extends StatelessWidget {
  const EditorPanelDock({super.key, required this.children, this.width = 260});

  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('editor-panel-dock-right'),
      width: width,
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: ListView.separated(
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}
