import 'package:flutter/foundation.dart' show VoidCallback;

/// The ink views' SHARED finger census (R26 #5).
///
/// A single canvas view can count its own contacts, but the TIMESHEET
/// mounts one [InteractiveBrushEditCanvasView] per sheet window — two
/// fingers landing on two different windows each looked like a lone
/// contact, so both drew a line while the user was only trying to pinch
/// the panel. Every touch contact registers here, app-wide, so any view
/// can ask "how many fingers are down on ink surfaces right now?".
///
/// Process-wide static state on purpose: there is one pair of hands.
class CanvasTouchContacts {
  CanvasTouchContacts._();

  static final Set<int> _pointers = <int>{};
  static final Set<VoidCallback> _multiTouchListeners = <VoidCallback>{};

  /// Fingers currently down on ANY ink surface.
  static int get count => _pointers.length;

  /// Views listen so a stroke already running on ANOTHER view can stand
  /// down the moment a second finger lands — the sibling never sees that
  /// pointer's own down event.
  static void addMultiTouchListener(VoidCallback listener) =>
      _multiTouchListeners.add(listener);

  static void removeMultiTouchListener(VoidCallback listener) =>
      _multiTouchListeners.remove(listener);

  static void add(int pointer) {
    _pointers.add(pointer);
    if (_pointers.length < 2) {
      return;
    }
    for (final listener in _multiTouchListeners.toList(growable: false)) {
      listener();
    }
  }

  static void remove(int pointer) => _pointers.remove(pointer);

  /// Drops a view's contacts wholesale — a view disposed mid-touch never
  /// gets its pointer-up, and a leaked contact would block drawing until
  /// the app restarts.
  static void removeAll(Iterable<int> pointers) =>
      _pointers.removeAll(pointers);

  /// Test seam.
  static void reset() => _pointers.clear();
}
