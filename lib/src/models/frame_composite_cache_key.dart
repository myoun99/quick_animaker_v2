import 'cut_id.dart';

class FrameCompositeCacheKey {
  FrameCompositeCacheKey({required this.cutId, required this.frameIndex}) {
    _validateFrameIndex(frameIndex);
  }

  final CutId cutId;
  final int frameIndex;

  FrameCompositeCacheKey copyWith({CutId? cutId, int? frameIndex}) {
    return FrameCompositeCacheKey(
      cutId: cutId ?? this.cutId,
      frameIndex: frameIndex ?? this.frameIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'cutId': cutId.toJson(),
    'frameIndex': frameIndex,
  };

  factory FrameCompositeCacheKey.fromJson(Map<String, dynamic> json) {
    return FrameCompositeCacheKey(
      cutId: CutId.fromJson(json['cutId'] as Map<String, dynamic>),
      frameIndex: json['frameIndex'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameCompositeCacheKey &&
          other.cutId == cutId &&
          other.frameIndex == frameIndex;

  @override
  int get hashCode => Object.hash(cutId, frameIndex);

  @override
  String toString() =>
      'FrameCompositeCacheKey(cutId: $cutId, frameIndex: $frameIndex)';
}

void _validateFrameIndex(int frameIndex) {
  if (frameIndex < 0) {
    throw ArgumentError.value(
      frameIndex,
      'frameIndex',
      'FrameCompositeCacheKey.frameIndex must be greater than or equal to 0.',
    );
  }
}
