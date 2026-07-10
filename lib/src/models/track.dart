import '../core/collection_equality.dart';
import 'cut.dart';
import 'layer.dart';
import 'layer_section_defaults.dart';
import 'track_id.dart';
import 'track_se_migration.dart';

enum TrackType { video, audio }

class Track {
  Track({
    required this.id,
    required this.name,
    required List<Cut> cuts,
    List<Layer> seLayers = const [],
    this.type = TrackType.video,
  }) : cuts = List.unmodifiable(cuts),
       seLayers = List.unmodifiable(seLayers);

  final TrackId id;
  final String name;
  final List<Cut> cuts;

  /// The track's SE rows (S1·S2·…): TRACK-owned, timeline keys on the
  /// track's GLOBAL frame axis so a sound may cross cut boundaries. Row
  /// order is list order and the display name is [Layer.name] — the single
  /// ordering every panel renders. Cut trims/reorders do NOT move SE
  /// content (NLE audio-track semantics — the precondition for
  /// cut-crossing sounds).
  final List<Layer> seLayers;

  final TrackType type;

  Track copyWith({
    TrackId? id,
    String? name,
    List<Cut>? cuts,
    List<Layer>? seLayers,
    TrackType? type,
  }) {
    return Track(
      id: id ?? this.id,
      name: name ?? this.name,
      cuts: cuts ?? this.cuts,
      seLayers: seLayers ?? this.seLayers,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'cuts': cuts.map((cut) => cut.toJson()).toList(),
    'seLayers': seLayers.map((layer) => layer.toJson()).toList(),
    'type': type.name,
  };

  factory Track.fromJson(Map<String, dynamic> json) {
    final id = TrackId.fromJson(json['id'] as Map<String, dynamic>);
    final cuts = (json['cuts'] as List<dynamic>)
        .map((cut) => Cut.fromJson(cut as Map<String, dynamic>))
        .toList();
    final seLayersJson = json['seLayers'] as List<dynamic>?;
    if (seLayersJson != null) {
      return Track(
        id: id,
        name: json['name'] as String,
        cuts: cuts,
        seLayers: withEnsuredTrackSeLayers(
          id,
          seLayersJson
              .map((layer) => Layer.fromJson(layer as Map<String, dynamic>))
              .toList(),
        ),
        type: TrackType.values.byName(json['type'] as String),
      );
    }

    // Legacy shape (no seLayers key): SE rows lived on each cut — lift
    // them onto the track's global axis (shape-based migration, the
    // codebase's convention).
    final lifted = liftCutSeLayersToTrack(id, cuts);
    return Track(
      id: id,
      name: json['name'] as String,
      cuts: lifted.cuts,
      seLayers: lifted.seLayers,
      type: TrackType.values.byName(json['type'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          other.id == id &&
          other.name == name &&
          listEquals(other.cuts, cuts) &&
          listEquals(other.seLayers, seLayers) &&
          other.type == type;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(cuts),
    Object.hashAll(seLayers),
    type,
  );

  @override
  String toString() =>
      'Track(id: $id, name: $name, cuts: $cuts, seLayers: $seLayers, '
      'type: $type)';
}
