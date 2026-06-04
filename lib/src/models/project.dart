import 'project_id.dart';
import 'track.dart';

class Project {
  Project({
    required this.id,
    required this.name,
    required List<Track> tracks,
    required this.createdAt,
    this.fps = 24,
  }) : tracks = List.unmodifiable(tracks);

  final ProjectId id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final int fps;

  Project copyWith({
    ProjectId? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdAt,
    int? fps,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      fps: fps ?? this.fps,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'tracks': tracks.map((track) => track.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'fps': fps,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          other.id == id &&
          other.name == name &&
          _listEquals(other.tracks, tracks) &&
          other.createdAt == createdAt &&
          other.fps == fps;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(tracks), createdAt, fps);

  @override
  String toString() =>
      'Project(id: $id, name: $name, tracks: $tracks, createdAt: $createdAt, fps: $fps)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
