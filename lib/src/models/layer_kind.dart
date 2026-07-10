enum LayerKind {
  animation('animation'),
  storyboard('storyboard'),

  /// Art cel for backgrounds and books (BG/BOOK). Draws and composites
  /// exactly like an animation layer and shares the drawing timeline
  /// section; the kind only marks the material for icons and sheet roles.
  art('art'),

  /// Sound-effect track: rows for the timesheet's SE column. Drawable like
  /// an animation layer (exposure blocks mark SE timing; frame names carry
  /// the labels); sorts into its own timeline section between the drawing
  /// cels and the camera. Every cut keeps at least two (the sheet's S1·S2).
  se('se'),

  /// Camera-work instruction row (FI/FO/PAN … chips): carries instruction
  /// events, never drawing frames, and sorts into the camera section. Every
  /// cut keeps at least one.
  instruction('instruction'),

  /// The cut's camera track: selecting it puts the canvas into camera
  /// manipulation mode and its timeline row shows camera keyframes. Exactly
  /// one per cut, auto-created, holds no drawing frames.
  camera('camera');

  const LayerKind(this.jsonValue);

  final String jsonValue;

  String toJson() => jsonValue;

  static LayerKind fromJson(Object? json) {
    for (final kind in LayerKind.values) {
      if (json == kind.jsonValue) {
        return kind;
      }
    }

    throw ArgumentError.value(
      json,
      'kind',
      'Layer kind must be "animation", "storyboard", "art", "se", '
          '"instruction" or "camera".',
    );
  }
}

/// Whether rows of [kind] hold drawing frames on the cel timeline (exposure
/// blocks, X cells, marks, comma drags). Camera rows mirror keyframes and
/// instruction rows carry instruction events instead.
bool layerKindHoldsDrawings(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation ||
    LayerKind.storyboard ||
    LayerKind.art ||
    LayerKind.se => true,
    LayerKind.instruction || LayerKind.camera => false,
  };
}

/// Whether the brush may land on [kind]'s cels (R6-④): only the
/// drawing-section kinds. SE cels exist for timing/dialogue data (the
/// upcoming on-canvas dialogue display is driven by their transform, not
/// strokes) and instruction/camera rows carry notation — the pen must
/// never draw on any of them.
bool layerKindAcceptsBrushInput(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation || LayerKind.storyboard || LayerKind.art => true,
    LayerKind.se || LayerKind.instruction || LayerKind.camera => false,
  };
}
