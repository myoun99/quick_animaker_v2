import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import 'layer_timeline_display_adapter.dart';
import 'layer_timeline_grid.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_orientation.dart';
import 'xsheet_timeline_grid.dart';

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    required this.onAddLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    required this.onToggleLayerTimesheet,
    required this.onLayerMarkSelected,
    this.commaDrag,
    this.isFrameCached,
    required this.orientation,
    required this.onOrientationChanged,
    this.timelineActionToolbar,
    this.showStoryboard = false,
    this.onShowStoryboardChanged,
    this.storyboardPanel,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
  final ValueChanged<LayerId> onToggleLayerTimesheet;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

  /// Comma-drag hooks for the block edge grips, shared by both
  /// orientations; null hides the grips.
  final TimelineCommaDragCallbacks? commaDrag;

  /// Cached-range resolver for the green strip (horizontal ruler and the
  /// X-sheet frame rail).
  final bool Function(int frameIndex)? isFrameCached;

  final TimelineOrientation orientation;
  final ValueChanged<TimelineOrientation> onOrientationChanged;
  final Widget? timelineActionToolbar;

  /// When true (and [storyboardPanel] is provided) the body shows the
  /// storyboard instead of the frame grid.
  final bool showStoryboard;
  final ValueChanged<bool>? onShowStoryboardChanged;

  /// The storyboard content hosted behind the timeline/storyboard toggle.
  final Widget? storyboardPanel;

  bool get _storyboardVisible => showStoryboard && storyboardPanel != null;

  /// Frame-axis zoom factors applied to each orientation's default cell
  /// extent (index 2 = classic geometry).
  static const List<double> _zoomFactors = [0.5, 0.75, 1.0, 1.5, 2.0];
  static const int _defaultZoomIndex = 2;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  int _zoomIndex = TimelinePanel._defaultZoomIndex;

  bool get _canZoomIn => _zoomIndex < TimelinePanel._zoomFactors.length - 1;
  bool get _canZoomOut => _zoomIndex > 0;

  double get _zoomFactor => TimelinePanel._zoomFactors[_zoomIndex];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalLayers = horizontalLayerDisplayOrder(widget.layers);
    final nextOrientation = widget.orientation == TimelineOrientation.horizontal
        ? TimelineOrientation.vertical
        : TimelineOrientation.horizontal;
    final showToolbar =
        widget.timelineActionToolbar != null && !widget._storyboardVisible;

    // The zoom factor scales each orientation's frame-axis cell extent
    // (cell width horizontally, frame row height in the X-sheet).
    final horizontalMetrics = TimelineGridMetrics.defaults.copyWith(
      frameCellWidth: TimelineGridMetrics.defaults.frameCellWidth * _zoomFactor,
    );
    final xsheetMetrics = XSheetTimelineGrid.defaultMetrics.copyWith(
      frameCellWidth:
          XSheetTimelineGrid.defaultMetrics.frameCellWidth * _zoomFactor,
    );

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: widget.timelineActionToolbar == null ? 220 : 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Row(
                children: [
                  if (widget.storyboardPanel != null) ...[
                    _ModeToggle(
                      showStoryboard: widget.showStoryboard,
                      onChanged: widget.onShowStoryboardChanged,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    '${widget.currentFrameIndex + 1}',
                    key: const ValueKey<String>(
                      'timeline-current-frame-counter',
                    ),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (!widget._storyboardVisible) ...[
                    IconButton(
                      key: const ValueKey<String>('timeline-zoom-out-button'),
                      tooltip: 'Zoom Out',
                      onPressed: _canZoomOut
                          ? () => setState(() => _zoomIndex -= 1)
                          : null,
                      icon: const Icon(Icons.zoom_out),
                    ),
                    IconButton(
                      key: const ValueKey<String>('timeline-zoom-in-button'),
                      tooltip: 'Zoom In',
                      onPressed: _canZoomIn
                          ? () => setState(() => _zoomIndex += 1)
                          : null,
                      icon: const Icon(Icons.zoom_in),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'timeline-toolbar-add-layer-button',
                      ),
                      tooltip: 'Add layer',
                      onPressed: widget.onAddLayer,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'timeline-orientation-toggle-button',
                      ),
                      tooltip:
                          widget.orientation == TimelineOrientation.horizontal
                          ? 'Show X-sheet'
                          : 'Show timeline',
                      onPressed: () =>
                          widget.onOrientationChanged(nextOrientation),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ],
                ],
              ),
            ),
            if (showToolbar)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: widget.timelineActionToolbar,
              ),
            Expanded(
              child: widget._storyboardVisible
                  ? widget.storyboardPanel!
                  : widget.orientation == TimelineOrientation.horizontal
                  ? LayerTimelineGrid(
                      layers: horizontalLayers,
                      activeLayerId: widget.activeLayerId,
                      currentFrameIndex: widget.currentFrameIndex,
                      playbackFrameCount: widget.playbackFrameCount,
                      exposureStateForLayer: widget.exposureStateForLayer,
                      frameNameForLayer: widget.frameNameForLayer,
                      onSelectLayer: widget.onSelectLayer,
                      onSelectFrame: widget.onSelectFrame,
                      onAddLayer: widget.onAddLayer,
                      onToggleLayerVisibility: widget.onToggleLayerVisibility,
                      onLayerOpacityChanged: widget.onLayerOpacityChanged,
                      onToggleLayerTimesheet: widget.onToggleLayerTimesheet,
                      onLayerMarkSelected: widget.onLayerMarkSelected,
                      commaDrag: widget.commaDrag,
                      isFrameCached: widget.isFrameCached,
                      metrics: horizontalMetrics,
                    )
                  : XSheetTimelineGrid(
                      layers: xsheetLayerDisplayOrder(widget.layers),
                      activeLayerId: widget.activeLayerId,
                      currentFrameIndex: widget.currentFrameIndex,
                      frameCount: widget.playbackFrameCount,
                      exposureStateForLayer: widget.exposureStateForLayer,
                      frameNameForLayer: widget.frameNameForLayer,
                      onSelectLayer: widget.onSelectLayer,
                      onSelectFrame: widget.onSelectFrame,
                      onAddLayer: widget.onAddLayer,
                      onToggleLayerVisibility: widget.onToggleLayerVisibility,
                      onLayerOpacityChanged: widget.onLayerOpacityChanged,
                      onToggleLayerTimesheet: widget.onToggleLayerTimesheet,
                      onLayerMarkSelected: widget.onLayerMarkSelected,
                      commaDrag: widget.commaDrag,
                      isFrameCached: widget.isFrameCached,
                      metrics: xsheetMetrics,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The timeline/storyboard segmented toggle shown in the panel header.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.showStoryboard, required this.onChanged});

  final bool showStoryboard;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeToggleButton(
            key: const ValueKey<String>('timeline-mode-timeline-button'),
            tooltip: 'Timeline',
            icon: Icons.view_timeline_outlined,
            selected: !showStoryboard,
            onPressed: onChanged == null ? null : () => onChanged!(false),
          ),
          _ModeToggleButton(
            key: const ValueKey<String>('timeline-mode-storyboard-button'),
            tooltip: 'Storyboard',
            icon: Icons.movie_outlined,
            selected: showStoryboard,
            onPressed: onChanged == null ? null : () => onChanged!(true),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  const _ModeToggleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 18,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 26),
      style: IconButton.styleFrom(
        foregroundColor: selected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
        backgroundColor: selected
            ? colorScheme.surfaceContainerHigh
            : Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}
