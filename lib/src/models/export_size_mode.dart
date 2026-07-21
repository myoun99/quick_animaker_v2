/// Output picture size: the project camera frame (rendered through each
/// cut's camera) or the cut's raw canvas (no camera, 1:1 pixels).
enum ExportSizeMode {
  camera,
  canvas;

  String get jsonValue => name;

  static ExportSizeMode fromJson(Object? json) => switch (json) {
    'canvas' => ExportSizeMode.canvas,
    _ => ExportSizeMode.camera,
  };
}
