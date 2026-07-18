import 'package:flutter/foundation.dart';

/// The sheet-TEXT mode toggle (UI-R23 feedback #1):
///
/// - NOTATION (default) — the timesheet shorthand as today: frame names
///   at block starts, held cells blank, hold ghosts as the continuing
///   dash, repeat ghosts as dimmed cel names.
/// - DATA — every covered cell prints the frame it ACTUALLY exposes (the
///   cel-studio full sheet): held cells and hold-ghost cells spell the
///   resolved name out, so what plays on every frame can be audited
///   against the notation (and matches sheets that print per-cell data).
///
/// Display-only: the underlying timeline data never changes — the toggle
/// switches which TEXT the cells print. Lives app-wide (both grids); the
/// main app shell rebuilds off the notifier (the accent-settings idiom).
abstract final class TimelineSheet {
  static final ValueNotifier<bool> dataMode = ValueNotifier<bool>(false);

  /// Whether cells print the RESOLVED per-frame data instead of notation.
  static bool get showsData => dataMode.value;
}
