import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/field_slider.dart';
import 'timeline_frame_range_policy.dart' show timelineSecondsLabel;
import 'timeline_panel.dart' show TimelinePanel;

/// The right-side view cluster shared VERBATIM by the timeline and
/// storyboard tabs: frame counter + seconds toggle + zoom slider, plus
/// host-specific trailing controls (the timeline's orientation toggle).
///
/// One widget instead of two hand-copied Rows — the key strings
/// ('timeline-current-frame-counter', 'timeline-time-display-toggle-button',
/// 'timeline-zoom-slider') stay unique on screen because only one tab is
/// ever mounted.
class TimelineViewCluster extends StatelessWidget {
  const TimelineViewCluster({
    super.key,
    required this.frameCursor,
    required this.projectFps,
    required this.showSeconds,
    required this.onShowSecondsChanged,
    required this.pixelsPerFrame,
    required this.onPixelsPerFrameChanged,
    this.trailing = const <Widget>[],
  });

  /// The editing/playback cursor — the counter subscribes to this alone so
  /// a tick rebuilds one Text, nothing else (playback-perf architecture).
  final ValueListenable<int> frameCursor;

  final int projectFps;
  final bool showSeconds;
  final ValueChanged<bool>? onShowSecondsChanged;
  final double pixelsPerFrame;
  final ValueChanged<double>? onPixelsPerFrameChanged;

  /// Host-specific controls after the zoom slider (orientation toggle).
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: frameCursor,
          builder: (context, cursorFrame, _) => Text(
            showSeconds
                ? timelineSecondsLabel(cursorFrame + 1, projectFps)
                : '${cursorFrame + 1}',
            key: const ValueKey<String>('timeline-current-frame-counter'),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const ValueKey<String>('timeline-time-display-toggle-button'),
          tooltip: showSeconds ? 'Show Frames' : 'Show Seconds',
          onPressed: onShowSecondsChanged == null
              ? null
              : () => onShowSecondsChanged!(!showSeconds),
          icon: Icon(
            showSeconds ? Icons.timer : Icons.timer_outlined,
            size: 18,
          ),
        ),
        Icon(Icons.zoom_out, size: 16, color: colorScheme.onSurfaceVariant),
        SizedBox(
          width: 140,
          child: FieldSlider(
            key: const ValueKey<String>('timeline-zoom-slider'),
            min: TimelinePanel.minPixelsPerFrame,
            max: TimelinePanel.maxPixelsPerFrame,
            value: pixelsPerFrame.clamp(
              TimelinePanel.minPixelsPerFrame,
              TimelinePanel.maxPixelsPerFrame,
            ),
            // Zoom reads as percent of the default frame width.
            valueText:
                '${(pixelsPerFrame / TimelinePanel.defaultPixelsPerFrame * 100).round()}%',
            displayFactor: 100 / TimelinePanel.defaultPixelsPerFrame,
            height: 18,
            onChanged: onPixelsPerFrameChanged,
          ),
        ),
        Icon(Icons.zoom_in, size: 16, color: colorScheme.onSurfaceVariant),
        ...trailing,
      ],
    );
  }
}
