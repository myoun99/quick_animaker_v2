import 'canvas_size.dart';
import 'cut_id.dart';

class PlaybackPreviewCacheKey {
  PlaybackPreviewCacheKey({
    required this.cutId,
    required this.frameIndex,
    required this.previewSize,
  }) {
    _validateFrameIndex(frameIndex);
  }

  final CutId cutId;
  final int frameIndex;
  final CanvasSize previewSize;

  PlaybackPreviewCacheKey copyWith({
    CutId? cutId,
    int? frameIndex,
    CanvasSize? previewSize,
  }) {
    return PlaybackPreviewCacheKey(
      cutId: cutId ?? this.cutId,
      frameIndex: frameIndex ?? this.frameIndex,
      previewSize: previewSize ?? this.previewSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'cutId': cutId.toJson(),
    'frameIndex': frameIndex,
    'previewSize': previewSize.toJson(),
  };

  factory PlaybackPreviewCacheKey.fromJson(Map<String, dynamic> json) {
    return PlaybackPreviewCacheKey(
      cutId: CutId.fromJson(json['cutId'] as Map<String, dynamic>),
      frameIndex: json['frameIndex'] as int,
      previewSize: CanvasSize.fromJson(
        json['previewSize'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackPreviewCacheKey &&
          other.cutId == cutId &&
          other.frameIndex == frameIndex &&
          other.previewSize == previewSize;

  @override
  int get hashCode => Object.hash(cutId, frameIndex, previewSize);

  @override
  String toString() =>
      'PlaybackPreviewCacheKey(cutId: $cutId, frameIndex: $frameIndex, '
      'previewSize: $previewSize)';
}

void _validateFrameIndex(int frameIndex) {
  if (frameIndex < 0) {
    throw ArgumentError.value(
      frameIndex,
      'frameIndex',
      'PlaybackPreviewCacheKey.frameIndex must be greater than or equal to 0.',
    );
  }
}
