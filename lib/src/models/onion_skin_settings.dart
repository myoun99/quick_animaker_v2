import '../core/collection_equality.dart';

/// One onion-skin peg (Callipeg's light-table model): one unique drawing
/// before/after the current one, individually toggleable with its own
/// opacity.
class OnionPeg {
  const OnionPeg({required this.enabled, required this.opacity});

  final bool enabled;
  final double opacity;

  OnionPeg copyWith({bool? enabled, double? opacity}) => OnionPeg(
    enabled: enabled ?? this.enabled,
    opacity: opacity ?? this.opacity,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnionPeg && other.enabled == enabled && other.opacity == opacity;

  @override
  int get hashCode => Object.hash(enabled, opacity);
}

/// How onion frames color: side tints (Colors — the Callipeg default) or
/// the artwork's own colors (Images), opacity only.
enum OnionSkinMode { colors, images }

/// The editor's onion-skin state (session view state, not project data) —
/// Callipeg's peg model: up to [maxPegs] pegs per side, each toggleable
/// with its own opacity, side tint colors and a Colors/Images mode.
class OnionSkinSettings {
  const OnionSkinSettings({
    this.enabled = false,
    this.beforePegs = defaultBeforePegs,
    this.afterPegs = defaultAfterPegs,
    this.tintBefore = 0xFFE53935,
    this.tintAfter = 0xFF43A047,
    this.mode = OnionSkinMode.colors,
  });

  static const int maxPegs = 8;

  /// Callipeg's defaults: two drawings back, one ahead.
  static const List<OnionPeg> defaultBeforePegs = [
    OnionPeg(enabled: true, opacity: 0.4),
    OnionPeg(enabled: true, opacity: 0.2),
    OnionPeg(enabled: false, opacity: 0.15),
    OnionPeg(enabled: false, opacity: 0.1),
  ];
  static const List<OnionPeg> defaultAfterPegs = [
    OnionPeg(enabled: true, opacity: 0.3),
    OnionPeg(enabled: false, opacity: 0.15),
    OnionPeg(enabled: false, opacity: 0.1),
    OnionPeg(enabled: false, opacity: 0.1),
  ];

  /// The master toggle (the `O` shortcut / toolbar button).
  final bool enabled;

  /// Peg k = the (k+1)-th unique drawing before/after the current one.
  final List<OnionPeg> beforePegs;
  final List<OnionPeg> afterPegs;

  /// Side tint colors (ARGB) for [OnionSkinMode.colors].
  final int tintBefore;
  final int tintAfter;

  final OnionSkinMode mode;

  OnionSkinSettings copyWith({
    bool? enabled,
    List<OnionPeg>? beforePegs,
    List<OnionPeg>? afterPegs,
    int? tintBefore,
    int? tintAfter,
    OnionSkinMode? mode,
  }) {
    return OnionSkinSettings(
      enabled: enabled ?? this.enabled,
      beforePegs: beforePegs ?? this.beforePegs,
      afterPegs: afterPegs ?? this.afterPegs,
      tintBefore: tintBefore ?? this.tintBefore,
      tintAfter: tintAfter ?? this.tintAfter,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnionSkinSettings &&
          other.enabled == enabled &&
          listEquals(other.beforePegs, beforePegs) &&
          listEquals(other.afterPegs, afterPegs) &&
          other.tintBefore == tintBefore &&
          other.tintAfter == tintAfter &&
          other.mode == mode;

  @override
  int get hashCode => Object.hash(
    enabled,
    Object.hashAll(beforePegs),
    Object.hashAll(afterPegs),
    tintBefore,
    tintAfter,
    mode,
  );
}
