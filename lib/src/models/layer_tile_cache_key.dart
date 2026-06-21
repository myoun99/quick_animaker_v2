import 'frame_id.dart';
import 'layer_id.dart';
import 'tile_coord.dart';

class LayerTileCacheKey {
  const LayerTileCacheKey({
    required this.layerId,
    required this.frameId,
    required this.tileCoord,
  });

  final LayerId layerId;
  final FrameId frameId;
  final TileCoord tileCoord;

  LayerTileCacheKey copyWith({
    LayerId? layerId,
    FrameId? frameId,
    TileCoord? tileCoord,
  }) {
    return LayerTileCacheKey(
      layerId: layerId ?? this.layerId,
      frameId: frameId ?? this.frameId,
      tileCoord: tileCoord ?? this.tileCoord,
    );
  }

  Map<String, dynamic> toJson() => {
    'layerId': layerId.toJson(),
    'frameId': frameId.toJson(),
    'tileCoord': tileCoord.toJson(),
  };

  factory LayerTileCacheKey.fromJson(Map<String, dynamic> json) {
    return LayerTileCacheKey(
      layerId: LayerId.fromJson(json['layerId'] as Map<String, dynamic>),
      frameId: FrameId.fromJson(json['frameId'] as Map<String, dynamic>),
      tileCoord: TileCoord.fromJson(json['tileCoord'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerTileCacheKey &&
          other.layerId == layerId &&
          other.frameId == frameId &&
          other.tileCoord == tileCoord;

  @override
  int get hashCode => Object.hash(layerId, frameId, tileCoord);

  @override
  String toString() =>
      'LayerTileCacheKey(layerId: $layerId, frameId: $frameId, '
      'tileCoord: $tileCoord)';
}
