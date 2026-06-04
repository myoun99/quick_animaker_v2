import 'cut.dart';
import 'track_id.dart';

enum TrackType { video, audio }

class Track {
  Track({
    required this.id,
    required this.name,
    required List<Cut> cuts,
    this.type = TrackType.video,
  }) : cuts = List.unmodifiable(cuts);

  final TrackId id;
  final String name;
  final List<Cut> cuts;
  final TrackType type;

  Track copyWith({
    TrackId? id,
    String? name,
    List<Cut>? cuts,
    TrackType? type,
  }) {
    return Track(
      id: id ?? this.id,
      name: name ?? this.name,
      cuts: cuts ?? this.cuts,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'cuts': cuts.map((cut) => cut.toJson()).toList(),
    'type': type.name,
  };

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: TrackId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      cuts: (json['cuts'] as List<dynamic>)
          .map((cut) => Cut.fromJson(cut as Map<String, dynamic>))
          .toList(),
      type: TrackType.values.byName(json['type'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          other.id == id &&
          other.name == name &&
          _listEquals(other.cuts, cuts) &&
          other.type == type;

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(cuts), type);

  @override
  String toString() => 'Track(id: $id, name: $name, cuts: $cuts, type: $type)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
