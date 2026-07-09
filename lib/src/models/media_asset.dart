import '../core/collection_equality.dart';

/// What a media pool entry holds. Audio only today; images/video join when
/// the storyboard grows reference-media support.
enum MediaAssetKind {
  audio('audio');

  const MediaAssetKind(this.jsonValue);

  final String jsonValue;

  String toJson() => jsonValue;

  /// Unknown or absent values decode to [audio] so files stay open-able
  /// across versions.
  static MediaAssetKind fromJson(Object? json) {
    for (final value in values) {
      if (value.jsonValue == json) {
        return value;
      }
    }
    return audio;
  }
}

/// One entry of the project's media pool (the Premiere/Resolve-style
/// browser): a file the project references, under a user-facing display
/// name.
///
/// The pool is keyed by the ABSOLUTE file path — clips reference sounds by
/// path ([AudioClip.filePath]), so an asset is that path's metadata plus
/// the browse/reuse surface. Relinking a moved file rewrites the path here
/// AND on every referencing clip in one undo step (the Resolve offline →
/// relink flow); nothing else about the link model changes.
class MediaAsset {
  const MediaAsset({
    required this.path,
    required this.name,
    this.kind = MediaAssetKind.audio,
  });

  /// Absolute file path — the pool key clips reference.
  final String path;

  /// Display name; seeds with the file name and is user-editable.
  final String name;

  final MediaAssetKind kind;

  MediaAsset copyWith({String? path, String? name, MediaAssetKind? kind}) {
    return MediaAsset(
      path: path ?? this.path,
      name: name ?? this.name,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'kind': kind.toJson(),
  };

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      path: json['path'] as String,
      name: json['name'] as String,
      kind: MediaAssetKind.fromJson(json['kind']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAsset &&
          other.path == path &&
          other.name == name &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(path, name, kind);

  @override
  String toString() => 'MediaAsset(path: $path, name: $name, kind: $kind)';
}

/// The default display name for [path]: its file name (last segment of
/// either separator style — the model stays dart:io-free).
String mediaAssetDefaultName(String path) {
  final segments = path.split(RegExp(r'[\\/]'));
  final name = segments.isEmpty ? path : segments.last;
  return name.isEmpty ? path : name;
}

/// Validates pool uniqueness: one entry per path.
void validateMediaAssetPaths(List<MediaAsset> assets) {
  final paths = <String>{};
  for (final asset in assets) {
    if (!paths.add(asset.path)) {
      throw ArgumentError.value(
        asset.path,
        'mediaAssets',
        'Media asset paths must be unique.',
      );
    }
  }
}

/// Immutable validated copy of [assets].
List<MediaAsset> immutableMediaAssetList(List<MediaAsset> assets) {
  validateMediaAssetPaths(assets);
  return List.unmodifiable(assets);
}

/// Convenience equality for pool lists (command no-op guards).
bool mediaAssetListEquals(List<MediaAsset> a, List<MediaAsset> b) =>
    listEquals(a, b);
