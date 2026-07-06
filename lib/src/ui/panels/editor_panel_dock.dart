import 'package:flutter/material.dart';

import 'panel_scrollbar.dart';

class EditorPanelDock extends StatefulWidget {
  const EditorPanelDock({super.key, required this.children, this.width = 260});

  final List<Widget> children;
  final double width;

  @override
  State<EditorPanelDock> createState() => _EditorPanelDockState();
}

class _EditorPanelDockState extends State<EditorPanelDock> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('editor-panel-dock-right'),
      width: widget.width,
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: PanelScrollbar(
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.only(right: panelScrollbarGutter),
          itemCount: widget.children.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => widget.children[index],
        ),
      ),
    );
  }
}
