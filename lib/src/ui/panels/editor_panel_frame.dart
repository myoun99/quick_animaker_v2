import 'package:flutter/material.dart';

import 'editor_panel_body.dart';
import 'editor_panel_header.dart';

class EditorPanelFrame extends StatelessWidget {
  const EditorPanelFrame({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.bodyPadding = const EdgeInsets.all(10),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ValueKey<String>('editor-panel-frame-$title'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.hasBoundedHeight;
          final maxHeight = hasBoundedHeight
              ? constraints.maxHeight.clamp(0.0, double.infinity).toDouble()
              : double.infinity;
          final headerHeight = hasBoundedHeight
              ? EditorPanelHeader.height.clamp(0.0, maxHeight).toDouble()
              : EditorPanelHeader.height;
          final body = EditorPanelBody(padding: bodyPadding, child: child);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: headerHeight,
                child: EditorPanelHeader(title: title, trailing: trailing),
              ),
              if (hasBoundedHeight)
                SizedBox(
                  height: (maxHeight - headerHeight)
                      .clamp(0.0, double.infinity)
                      .toDouble(),
                  child: body,
                )
              else
                body,
            ],
          );
        },
      ),
    );
  }
}
