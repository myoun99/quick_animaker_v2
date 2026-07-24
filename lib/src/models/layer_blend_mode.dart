import 'dart:ui' show BlendMode;

import 'app_language.dart';
import 'separable_blend_mode.dart';

/// The layer's compositing blend against everything below it (R26 #30).
///
/// Applied at COMPOSITE time on every route (playback cache, editing
/// stack, camera renders, export) — never baked into the artwork.
/// [normal] is plain srcOver and the serialized default (omitted from
/// JSON, so pre-blend files read back unchanged). Mirrors across link
/// groups like the eye/opacity ("레인만 각자, 나머지는 하나").
enum LayerBlendMode {
  /// GROUP ROWS ONLY — the folder's default, and Photoshop/CSP's ("통과").
  ///
  /// A pass-through folder creates NO composite buffer: its members blend
  /// straight against everything below the folder, exactly as if the
  /// folder were not there. It is a STRUCTURAL answer, not a blend
  /// formula — [paintBlendMode] never runs for it, because nothing is
  /// ever drawn as "the folder".
  ///
  /// Giving a folder any OTHER mode isolates it: the members compose into
  /// one buffer and that buffer blends once ([isolatesGroup]).
  passThrough,
  normal,
  darken,
  multiply,
  colorBurn,
  lighten,
  screen,
  colorDodge,
  add,
  overlay,
  softLight,
  hardLight,
  difference,
  exclusion;

  /// Whether this mode makes a GROUP isolate into its own buffer. Only
  /// [passThrough] does not — every real blend formula needs the group
  /// composed first to have something to blend.
  bool get isolatesGroup => this != passThrough;

  /// The shared separable data for this mode, or `null` for the two heads
  /// ([passThrough]/[normal]). The separable vocabulary (GPU blend + labels)
  /// lives once on [SeparableBlendMode].
  SeparableBlendMode? get separable => SeparableBlendMode.forName(name);

  /// The ui.Paint blend for the composite draw. [passThrough] answers
  /// srcOver defensively; a pass-through folder is never drawn as a node
  /// at all, so this should not be reached for it.
  BlendMode get paintBlendMode => switch (this) {
    passThrough || normal => BlendMode.srcOver,
    _ => separable!.blendMode,
  };

  /// The menu label (the industry-standard English terms every paint
  /// tool shares).
  String get label => switch (this) {
    passThrough => 'Pass Through',
    normal => 'Normal',
    _ => separable!.label,
  };

  /// The label in the program language. Japanese follows Clip Studio's
  /// terms (user rule 07-22: ja localized first; every other language
  /// keeps the shared English vocabulary artists already read).
  String labelFor(AppLanguage language) => switch (language) {
    AppLanguage.ja => switch (this) {
      passThrough => '通過',
      normal => '通常',
      _ => separable!.labelFor(language),
    },
    _ => label,
  };

  String toJson() => name;

  static LayerBlendMode fromJson(Object? json) {
    return LayerBlendMode.values.firstWhere(
      (value) => value.name == json,
      orElse: () => LayerBlendMode.normal,
    );
  }

  /// The modes a row of this kind may be given. Only GROUP rows offer
  /// [passThrough] — a drawing layer has no members to pass through.
  static List<LayerBlendMode> optionsFor({required bool isGroup}) => [
    for (final mode in LayerBlendMode.values)
      if (isGroup || mode != LayerBlendMode.passThrough) mode,
  ];
}
