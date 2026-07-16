import 'package:flutter/material.dart';

import '../widgets/app_scrollbar.dart';

/// Width reserved next to a scrollable so the always-visible panel
/// scrollbar owns its own lane instead of overlaying content. Scrollables
/// wrapped in [PanelScrollbar] should pad their scroll-end edge by this.
const double panelScrollbarGutter = 12;

/// The shared panel scrollbar: the app-wide [AppScrollbar] overlaid on the
/// wrapped scrollable's end edge (right for vertical, bottom for
/// horizontal — detected from the controller's attached position). Pair
/// with [panelScrollbarGutter] padding on the wrapped scrollable so the bar
/// sits in allocated space.
class PanelScrollbar extends StatefulWidget {
  const PanelScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<PanelScrollbar> createState() => _PanelScrollbarState();
}

class _PanelScrollbarState extends State<PanelScrollbar> {
  bool _metricsRefreshScheduled = false;

  Axis get _axis {
    if (widget.controller.hasClients) {
      return axisDirectionToAxis(widget.controller.position.axisDirection);
    }
    return Axis.vertical;
  }

  @override
  Widget build(BuildContext context) {
    final axis = _axis;
    final vertical = axis == Axis.vertical;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        // Metrics notifications arrive during layout — defer the rebuild
        // (axis detection on first attach, thumb resize on content growth).
        if (!_metricsRefreshScheduled) {
          _metricsRefreshScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _metricsRefreshScheduled = false;
            if (mounted) {
              setState(() {});
            }
          });
        }
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: vertical ? null : 0,
            right: 0,
            top: vertical ? 0 : null,
            bottom: 0,
            width: vertical ? panelScrollbarGutter : null,
            height: vertical ? null : panelScrollbarGutter,
            child: AppControllerScrollbar(
              controller: widget.controller,
              axis: axis,
            ),
          ),
        ],
      ),
    );
  }
}
