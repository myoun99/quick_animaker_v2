/// How an attach layer relates to its base's TIMING (UI-R21 #3, the two
/// attach types):
///
/// - [synced] — the original W5 behavior: the row owns no timeline; its
///   cels ride the base's exposures through the cell links and the row
///   displays as a ghost mirror. Timing edits stand down.
/// - [free] — the row authors its own timeline exactly like a normal
///   drawing layer (create/delete/stretch/move cels freely). It is still
///   an attach row in every structural sense: it rides the base's
///   transform/FX (no fx of its own), folds with the group, cascades on
///   base delete, and can never carry attach rows itself.
enum AttachedMode {
  free,
  synced;

  static AttachedMode fromJson(Object? json) {
    return AttachedMode.values.firstWhere(
      (mode) => mode.name == json,
      orElse: () => AttachedMode.synced,
    );
  }

  String toJson() => name;
}
