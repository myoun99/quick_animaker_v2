import 'package:flutter/gestures.dart' show PointerDeviceKind, kTouchSlop;
import 'package:flutter/widgets.dart';

/// The multi-finger touch gesture vocabulary (R11-⑨, user-picked: taps +
/// holds). Every registry action can bind ONE of these in the Shortcuts
/// dialog, exactly like a key binding.
enum TouchGesture {
  twoFingerTap,
  threeFingerTap,
  fourFingerTap,
  twoFingerLongPress,
  threeFingerLongPress;

  String get label => switch (this) {
    TouchGesture.twoFingerTap => '2-Finger Tap',
    TouchGesture.threeFingerTap => '3-Finger Tap',
    TouchGesture.fourFingerTap => '4-Finger Tap',
    TouchGesture.twoFingerLongPress => '2-Finger Hold',
    TouchGesture.threeFingerLongPress => '3-Finger Hold',
  };

  static TouchGesture? fromName(String? name) {
    for (final gesture in TouchGesture.values) {
      if (gesture.name == name) {
        return gesture;
      }
    }
    return null;
  }
}

/// Observes RAW touch pointers over its child and fires the bound
/// [TouchGesture] when a stationary multi-finger tap or hold releases.
///
/// Purely observational (a translucent [Listener]): drawing (one finger),
/// pinch navigation and every widget underneath keep working — a gesture
/// only fires when ALL fingers lift without ever moving past the touch
/// slop, which is exactly the contact pattern pinches and strokes never
/// produce. Mouse and stylus pointers are ignored.
class TouchShortcutLayer extends StatefulWidget {
  const TouchShortcutLayer({
    super.key,
    required this.onGesture,
    required this.child,
  });

  final ValueChanged<TouchGesture> onGesture;
  final Widget child;

  /// Releases faster than this are taps; slower ones are holds.
  static const Duration holdThreshold = Duration(milliseconds: 450);

  /// Contacts held past this are abandoned (a rest, not a shortcut).
  static const Duration gestureDeadline = Duration(seconds: 2);

  @override
  State<TouchShortcutLayer> createState() => _TouchShortcutLayerState();
}

class _TouchShortcutLayerState extends State<TouchShortcutLayer> {
  final Map<int, Offset> _downPositions = <int, Offset>{};
  int _maxSimultaneous = 0;
  bool _moved = false;

  /// Event timestamps (not wall clock): correct under the test binding's
  /// fake clock AND the engine's event times on device.
  Duration? _firstDown;

  void _reset() {
    _downPositions.clear();
    _maxSimultaneous = 0;
    _moved = false;
    _firstDown = null;
  }

  void _handleDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) {
      return;
    }
    if (_downPositions.isEmpty) {
      _moved = false;
      _maxSimultaneous = 0;
      _firstDown = event.timeStamp;
    }
    _downPositions[event.pointer] = event.position;
    if (_downPositions.length > _maxSimultaneous) {
      _maxSimultaneous = _downPositions.length;
    }
  }

  void _handleMove(PointerMoveEvent event) {
    final start = _downPositions[event.pointer];
    if (start == null || _moved) {
      return;
    }
    if ((event.position - start).distance > kTouchSlop) {
      _moved = true;
    }
  }

  void _handleUp(PointerUpEvent event) {
    if (_downPositions.remove(event.pointer) == null) {
      return;
    }
    if (_downPositions.isNotEmpty) {
      return;
    }
    final firstDown = _firstDown;
    final fingers = _maxSimultaneous;
    final moved = _moved;
    _reset();
    if (moved || firstDown == null || fingers < 2) {
      return;
    }
    final held = event.timeStamp - firstDown;
    if (held >= TouchShortcutLayer.gestureDeadline) {
      return;
    }
    final isHold = held >= TouchShortcutLayer.holdThreshold;
    final gesture = switch ((fingers, isHold)) {
      (2, false) => TouchGesture.twoFingerTap,
      (3, false) => TouchGesture.threeFingerTap,
      (>= 4, false) => TouchGesture.fourFingerTap,
      (2, true) => TouchGesture.twoFingerLongPress,
      (3, true) => TouchGesture.threeFingerLongPress,
      _ => null,
    };
    if (gesture != null) {
      widget.onGesture(gesture);
    }
  }

  void _handleCancel(PointerCancelEvent event) {
    if (_downPositions.remove(event.pointer) == null) {
      return;
    }
    if (_downPositions.isEmpty) {
      _reset();
    } else {
      // A cancelled contact invalidates the whole gesture.
      _moved = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleCancel,
      child: widget.child,
    );
  }
}
