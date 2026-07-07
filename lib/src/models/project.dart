import '../core/collection_equality.dart';
import 'canvas_size.dart';
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
  }) : tracks = List.unmodifiable(tracks);

  final ProjectId id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final int fps;
  final CanvasSize cameraSize;

  /// Sheet-header text (title/episode/artist) the timesheet document reads.
  final TimesheetInfo timesheetInfo;

  Project copyWith({
    ProjectId? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdAt,
    int? fps,
    CanvasSize? cameraSize,
    TimesheetInfo? timesheetInfo,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      fps: fps ?? this.fps,
      cameraSize: cameraSize ?? this.cameraSize,
      timesheetInfo: timesheetInfo ?? this.timesheetInfo,
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
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: ProjectId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      tracks: (json['tracks'] as List<dynamic>)
          .map((track) => Track.fromJson(track as Map<String, dynamic>))
          .toList(),
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
          other.timesheetInfo == timesheetInfo;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(tracks),
    createdAt,
    fps,
    cameraSize,
    timesheetInfo,
  );

  @override
  String toString() =>
      'Project(id: $id, name: $name, tracks: $tracks, createdAt: $createdAt, fps: $fps, cameraSize: $cameraSize)';
}
