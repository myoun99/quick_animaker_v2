import 'package:flutter/material.dart';

class EditorPanelBody extends StatelessWidget {
  const EditorPanelBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      key: const ValueKey<String>('editor-panel-body'),
      child: SingleChildScrollView(padding: padding, child: child),
    );
  }
}
