import '../core/collection_equality.dart';
import 'canvas_size.dart';
import 'cut_camera.dart';
import 'cut_id.dart';
import 'cut_metadata.dart';
import 'layer.dart';
import 'layer_section_defaults.dart';
import 'transform_track.dart';

class Cut {
  Cut({
    required this.id,
    required this.name,
    required List<Layer> layers,
    required this.duration,
    required this.canvasSize,
    this.metadata = const CutMetadata.empty(),
    this.leadingGapFrames = 0,
    CutCamera? camera,
    TransformTrack? transformTrack,
  }) : assert(leadingGapFrames >= 0),
       layers = List.unmodifiable(layers),
       camera = camera ?? CutCamera.empty(),
       transformTrack = transformTrack ?? TransformTrack.empty();

  final CutId id;
  final String name;
  final List<Layer> layers;
  final int duration;

  /// Empty frames BEFORE this cut on the track's global axis (black on
  /// playback/export). Track list order stays the single source of cut
  /// sequence — a gap is an attribute of the boundary, so overlap is
  /// unrepresentable and reorders need no renumbering.
  final int leadingGapFrames;

  final CanvasSize canvasSize;
  final CutMetadata metadata;
  final CutCamera camera;

  /// CUT-level transform on the cut's playback frame axis — the V-track's
  /// track-level effects. Only the opacity lane is consumed today (cut
  /// fade in/out over the whole composed frame); the other lanes wait for
  /// V-track transform UI. Applied at playback/export display time, never
  /// baked into composites (a fade would shard the composite cache per
  /// frame).
  final TransformTrack transformTrack;

  /// The composed frame's opacity at [frameIndex] (the cut fade), 1 when
  /// the opacity lane is unkeyed.
  double fadeOpacityAt(int frameIndex) {
    return transformTrack.opacity
        .resolveAt(
          frameIndex: frameIndex,
          orElse: () => 1.0,
          lerp: (a, b, t) => a + (b - a) * t,
        )
        .clamp(0.0, 1.0);
  }

  Cut copyWith({
    CutId? id,
    String? name,
    List<Layer>? layers,
    int? duration,
    CanvasSize? canvasSize,
    CutMetadata? metadata,
    int? leadingGapFrames,
    CutCamera? camera,
    TransformTrack? transformTrack,
  }) {
    return Cut(
      id: id ?? this.id,
      name: name ?? this.name,
      layers: layers ?? this.layers,
      duration: duration ?? this.duration,
      canvasSize: canvasSize ?? this.canvasSize,
      metadata: metadata ?? this.metadata,
      leadingGapFrames: leadingGapFrames ?? this.leadingGapFrames,
      camera: camera ?? this.camera,
      transformTrack: transformTrack ?? this.transformTrack,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'layers': layers.map((layer) => layer.toJson()).toList(),
    'duration': duration,
    'canvasSize': canvasSize.toJson(),
    'metadata': metadata.toJson(),
    // Omitted at 0: legacy files load gap-free with no migration.
    if (leadingGapFrames > 0) 'leadingGap': leadingGapFrames,
    'camera': camera.toJson(),
    if (transformTrack.isNotEmpty) 'transform': transformTrack.toJson(),
  };

  factory Cut.fromJson(Map<String, dynamic> json) {
    final id = CutId.fromJson(json['id'] as Map<String, dynamic>);
    return Cut(
      id: id,
      name: json['name'] as String,
      // Older files predate the SE/instruction fixture rows; backfill them
      // on load so every cut meets the S1·S2 + CAM floors.
      layers: withEnsuredSectionLayers(
        id,
        (json['layers'] as List<dynamic>)
            .map((layer) => Layer.fromJson(layer as Map<String, dynamic>))
            .toList(),
      ),
      duration: json['duration'] as int,
      canvasSize: CanvasSize.fromJson(
        json['canvasSize'] as Map<String, dynamic>,
      ),
      metadata: json['metadata'] == null
          ? const CutMetadata.empty()
          : CutMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      leadingGapFrames: (json['leadingGap'] as int?) ?? 0,
      camera: json['camera'] == null
          ? null
          : CutCamera.fromJson(json['camera'] as Map<String, dynamic>),
      // Pre-absorption files carried a separate `folders` table; folders
      // are layers now and the key is ignored (no production data —
      // [[no-production-data-yet]]).
      transformTrack: json['transform'] == null
          ? null
          : TransformTrack.fromJson(json['transform'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cut &&
          other.id == id &&
          other.name == name &&
          listEquals(other.layers, layers) &&
          other.duration == duration &&
          other.canvasSize == canvasSize &&
          other.metadata == metadata &&
          other.leadingGapFrames == leadingGapFrames &&
          other.camera == camera &&
          other.transformTrack == transformTrack;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(layers),
    duration,
    canvasSize,
    metadata,
    leadingGapFrames,
    camera,
    transformTrack,
  );

  @override
  String toString() =>
      'Cut(id: $id, name: $name, layers: $layers, duration: $duration, canvasSize: $canvasSize, metadata: $metadata, camera: $camera, transformTrack: $transformTrack)';
}
