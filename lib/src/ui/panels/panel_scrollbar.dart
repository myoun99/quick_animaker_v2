import 'package:flutter/material.dart';

/// Width reserved next to a scrollable so the always-visible panel
/// scrollbar owns its own lane instead of overlaying content. Scrollables
/// wrapped in [PanelScrollbar] should pad their scroll-end edge by this.
const double panelScrollbarGutter = 10;

/// The shared panel scrollbar: always visible with a visible track.
///
/// Visual properties (thickness, colors, radius) come from the app-level
/// [ScrollbarThemeData] so every panel renders the same bar. Pair with
/// [panelScrollbarGutter] padding on the wrapped scrollable so the bar sits
/// in allocated space.
class PanelScrollbar extends StatelessWidget {
  const PanelScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(controller: controller, child: child);
  }
}
