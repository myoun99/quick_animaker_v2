/// How cel files are named and foldered (CSP-style cel export options).
///
/// The name is `[project_][cut_][layer]frame[suffix].png`: project/cut
/// prefixes join with '_', the layer name sits directly against the frame
/// name (layer 'A' + frame '1' = 'A1'). The frame name is `Frame.name`,
/// falling back to the cel's 1-based position when unnamed.
class ExportCelNaming {
  const ExportCelNaming({
    this.includeProjectName = false,
    this.includeCutName = false,
    this.includeLayerName = true,
    this.frameDigits = 0,
    this.suffix = '',
    this.cutFolder = false,
    this.layerFolder = false,
  });

  final bool includeProjectName;
  final bool includeCutName;
  final bool includeLayerName;

  /// 0 = off; otherwise the first digit run in the frame name is left-padded
  /// with zeros to this width ('1' → '0001' at 4). Names without any digits
  /// are left alone.
  final int frameDigits;

  /// Appended right before '.png' (TVPaint's 後ろ文字付け).
  final String suffix;

  /// Per-cut / per-layer subfolders under the export directory.
  final bool cutFolder;
  final bool layerFolder;

  ExportCelNaming copyWith({
    bool? includeProjectName,
    bool? includeCutName,
    bool? includeLayerName,
    int? frameDigits,
    String? suffix,
    bool? cutFolder,
    bool? layerFolder,
  }) => ExportCelNaming(
    includeProjectName: includeProjectName ?? this.includeProjectName,
    includeCutName: includeCutName ?? this.includeCutName,
    includeLayerName: includeLayerName ?? this.includeLayerName,
    frameDigits: frameDigits ?? this.frameDigits,
    suffix: suffix ?? this.suffix,
    cutFolder: cutFolder ?? this.cutFolder,
    layerFolder: layerFolder ?? this.layerFolder,
  );

  Map<String, dynamic> toJson() => {
    if (includeProjectName) 'includeProjectName': true,
    if (includeCutName) 'includeCutName': true,
    if (!includeLayerName) 'includeLayerName': false,
    if (frameDigits != 0) 'frameDigits': frameDigits,
    if (suffix.isNotEmpty) 'suffix': suffix,
    if (cutFolder) 'cutFolder': true,
    if (layerFolder) 'layerFolder': true,
  };

  static ExportCelNaming fromJson(Map<String, dynamic> json) =>
      ExportCelNaming(
        includeProjectName: json['includeProjectName'] as bool? ?? false,
        includeCutName: json['includeCutName'] as bool? ?? false,
        includeLayerName: json['includeLayerName'] as bool? ?? true,
        frameDigits: (json['frameDigits'] as num?)?.round() ?? 0,
        suffix: json['suffix'] as String? ?? '',
        cutFolder: json['cutFolder'] as bool? ?? false,
        layerFolder: json['layerFolder'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportCelNaming &&
          other.includeProjectName == includeProjectName &&
          other.includeCutName == includeCutName &&
          other.includeLayerName == includeLayerName &&
          other.frameDigits == frameDigits &&
          other.suffix == suffix &&
          other.cutFolder == cutFolder &&
          other.layerFolder == layerFolder;

  @override
  int get hashCode => Object.hash(
    includeProjectName,
    includeCutName,
    includeLayerName,
    frameDigits,
    suffix,
    cutFolder,
    layerFolder,
  );
}
