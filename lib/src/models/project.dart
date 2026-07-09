import '../core/collection_equality.dart';
import 'camera_instruction.dart';
import 'canvas_size.dart';
import 'media_asset.dart';
import 'project_id.dart';
import 'timesheet_info.dart';
import 'track.dart';

const defaultProjectCameraSize = CanvasSize(width: 1920, height: 1080);

class Project {
  Project({
    required this.id,
    required this.name,
    required List<Track> tracks,
    required this.createdAt,
    this.fps = 24,
    this.cameraSize = defaultProjectCameraSize,
    this.timesheetInfo = TimesheetInfo.empty,
    CameraInstructionSet? cameraInstructions,
    List<MediaAsset> mediaAssets = const [],
  }) : tracks = List.unmodifiable(tracks),
       cameraInstructions = cameraInstructions ?? CameraInstructionSet.standard,
       mediaAssets = immutableMediaAssetList(mediaAssets);

  final ProjectId id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final int fps;
  final CanvasSize cameraSize;

  /// Sheet-header text (title/episode/artist) the timesheet document reads.
  final TimesheetInfo timesheetInfo;

  /// The instruction vocabulary instruction rows pick from; seeds with the
  /// standard 撮影 terms and is user-editable.
  final CameraInstructionSet cameraInstructions;

  /// The media pool the browser panel lists, keyed by absolute path.
  /// Loading reconciles it against every clip reference, so legacy projects
  /// (and hand-edited files) always open with a complete pool.
  final List<MediaAsset> mediaAssets;

  MediaAsset? mediaAssetByPath(String path) {
    for (final asset in mediaAssets) {
      if (asset.path == path) {
        return asset;
      }
    }
    return null;
  }

  Project copyWith({
    ProjectId? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdAt,
    int? fps,
    CanvasSize? cameraSize,
    TimesheetInfo? timesheetInfo,
    CameraInstructionSet? cameraInstructions,
    List<MediaAsset>? mediaAssets,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      fps: fps ?? this.fps,
      cameraSize: cameraSize ?? this.cameraSize,
      timesheetInfo: timesheetInfo ?? this.timesheetInfo,
      cameraInstructions: cameraInstructions ?? this.cameraInstructions,
      mediaAssets: mediaAssets ?? this.mediaAssets,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'tracks': tracks.map((track) => track.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'fps': fps,
    'cameraSize': cameraSize.toJson(),
    'timesheetInfo': timesheetInfo.toJson(),
    'cameraInstructions': cameraInstructions.toJson(),
    'mediaAssets': mediaAssets.map((asset) => asset.toJson()).toList(),
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    final tracks = (json['tracks'] as List<dynamic>)
        .map((track) => Track.fromJson(track as Map<String, dynamic>))
        .toList();
    final storedAssets = json['mediaAssets'] == null
        ? const <MediaAsset>[]
        : (json['mediaAssets'] as List<dynamic>)
              .map(
                (asset) => MediaAsset.fromJson(asset as Map<String, dynamic>),
              )
              .toList();
    return Project(
      id: ProjectId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      tracks: tracks,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fps: json['fps'] as int,
      cameraSize: json['cameraSize'] == null
          ? defaultProjectCameraSize
          : CanvasSize.fromJson(json['cameraSize'] as Map<String, dynamic>),
      timesheetInfo: json['timesheetInfo'] == null
          ? TimesheetInfo.empty
          : TimesheetInfo.fromJson(
              json['timesheetInfo'] as Map<String, dynamic>,
            ),
      cameraInstructions: json['cameraInstructions'] == null
          ? null
          : CameraInstructionSet.fromJson(
              json['cameraInstructions'] as Map<String, dynamic>,
            ),
      mediaAssets: reconciledMediaAssets(storedAssets, tracks),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          other.id == id &&
          other.name == name &&
          listEquals(other.tracks, tracks) &&
          other.createdAt == createdAt &&
          other.fps == fps &&
          other.cameraSize == cameraSize &&
          other.timesheetInfo == timesheetInfo &&
          other.cameraInstructions == cameraInstructions &&
          listEquals(other.mediaAssets, mediaAssets);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(tracks),
    createdAt,
    fps,
    cameraSize,
    timesheetInfo,
    cameraInstructions,
    Object.hashAll(mediaAssets),
  );

  @override
  String toString() =>
      'Project(id: $id, name: $name, tracks: $tracks, createdAt: $createdAt, fps: $fps, cameraSize: $cameraSize)';
}

/// [stored] plus a synthesized entry (file-name display name) for every
/// clip-referenced path the pool does not know yet, in first-reference
/// order. Legacy projects predate the pool entirely; newer files can also
/// arrive with pool/clips out of sync (hand edits, merges) — loading always
/// reconciles rather than trusting the stored list.
List<MediaAsset> reconciledMediaAssets(
  List<MediaAsset> stored,
  List<Track> tracks,
) {
  final known = {for (final asset in stored) asset.path};
  final synthesized = <MediaAsset>[];
  for (final track in tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        for (final clip in layer.audioClips) {
          if (known.add(clip.filePath)) {
            synthesized.add(
              MediaAsset(
                path: clip.filePath,
                name: mediaAssetDefaultName(clip.filePath),
              ),
            );
          }
        }
      }
    }
  }
  return synthesized.isEmpty ? stored : [...stored, ...synthesized];
}
