import 'package:flutter/material.dart';

/// Slim toolbar strip atop a panel body hosting the panel's controls.
/// The TAB names the panel — this bar never repeats the title.
class EditorPanelHeader extends StatelessWidget {
  const EditorPanelHeader({super.key, required this.trailing});

  final Widget trailing;

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
      child: Row(children: [const Spacer(), trailing]),
    );
  }
}
