import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// PEN-9: a stylus approaching the timeline stops any COASTING scroll.
///
/// While a fling glides, the scrollable ignore-pointers its children, so
/// a pen landing mid-glide never reaches the cell/selection layers — the
/// drag falls to the scroll recognizer and the pen "scrolls" no matter
/// how the arena is tuned (the tablet's "touch fling, then pen selects →
/// scroll" bug; R22F's eager slop can't help a child that was never hit-
/// tested). EMR pens (S-Pen/Wacom) hover before contact, so stopping the
/// glide on hover restores the child hit-test before the tip lands; the
/// pointer-down stop is the fallback for the first contact of pens that
/// deliver no hover. Stopping a coast is exactly the tap-to-stop gesture,
/// so the pen loses nothing.
///
/// A FINGER drag must never be yanked from under the hand (pens hover
/// while fingers scroll), so only axes whose latest update was not
/// finger-driven — a ballistic coast or an auto-scroll — are stopped.
class StylusGlideStop extends StatefulWidget {
  const StylusGlideStop({
    super.key,
    required this.controllers,
    required this.child,
  });

  /// The wrapped grid's own scroll controllers (the ones whose viewports
  /// sit below this widget — synced mirror controllers need no entry:
  /// they follow by jumpTo, which never ignore-pointers).
  final List<ScrollController> controllers;

  final Widget child;

  @override
  State<StylusGlideStop> createState() => _StylusGlideStopState();
}

class _StylusGlideStopState extends State<StylusGlideStop> {
  /// Axes whose most recent scroll update carried no drag details — a
  /// coasting fling (or a programmatic scroll; stopping those on pen
  /// approach is equally safe).
  final Set<Axis> _coasting = <Axis>{};

  bool _handleNotification(ScrollNotification notification) {
    final axis = notification.metrics.axis;
    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) {
        _coasting.add(axis);
      } else {
        _coasting.remove(axis);
      }
    } else if (notification is ScrollEndNotification) {
      _coasting.remove(axis);
    }
    return false;
  }

  void _stopGlides(PointerEvent event) {
    if (event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return;
    }
    if (_coasting.isEmpty) {
      return;
    }
    for (final controller in widget.controllers) {
      for (final position in controller.positions) {
        if (_coasting.contains(position.axis) &&
            position.isScrollingNotifier.value) {
          position.jumpTo(position.pixels);
        }
      }
    }
    _coasting.clear();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: _stopGlides,
        onPointerDown: _stopGlides,
        child: widget.child,
      ),
    );
  }
}
