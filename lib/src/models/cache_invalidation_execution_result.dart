class CacheInvalidationExecutionResult {
  CacheInvalidationExecutionResult({
    required this.layerTileCount,
    required this.frameCompositeCount,
    required this.playbackPreviewCount,
  }) {
    _validateCount(layerTileCount, 'layerTileCount');
    _validateCount(frameCompositeCount, 'frameCompositeCount');
    _validateCount(playbackPreviewCount, 'playbackPreviewCount');
  }

  final int layerTileCount;
  final int frameCompositeCount;
  final int playbackPreviewCount;

  int get totalCount =>
      layerTileCount + frameCompositeCount + playbackPreviewCount;

  bool get didInvalidate => totalCount > 0;

  CacheInvalidationExecutionResult copyWith({
    int? layerTileCount,
    int? frameCompositeCount,
    int? playbackPreviewCount,
  }) {
    return CacheInvalidationExecutionResult(
      layerTileCount: layerTileCount ?? this.layerTileCount,
      frameCompositeCount: frameCompositeCount ?? this.frameCompositeCount,
      playbackPreviewCount: playbackPreviewCount ?? this.playbackPreviewCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheInvalidationExecutionResult &&
          other.layerTileCount == layerTileCount &&
          other.frameCompositeCount == frameCompositeCount &&
          other.playbackPreviewCount == playbackPreviewCount;

  @override
  int get hashCode =>
      Object.hash(layerTileCount, frameCompositeCount, playbackPreviewCount);

  @override
  String toString() =>
      'CacheInvalidationExecutionResult(layerTileCount: $layerTileCount, '
      'frameCompositeCount: $frameCompositeCount, '
      'playbackPreviewCount: $playbackPreviewCount)';
}

void _validateCount(int count, String name) {
  if (count < 0) {
    throw ArgumentError.value(
      count,
      name,
      'CacheInvalidationExecutionResult.$name must be greater than or equal to 0.',
    );
  }
}
