import 'frame_id.dart';

/// One sound linked to an SE layer FRAME — exactly like drawings link to
/// frames: the sound belongs to the instance, every timeline block exposing
/// that frame carries it (block start = sound start, block length clamps
/// playback), and removing the block removes the sound with it. Linked
/// blocks sharing the frame share the sound (footsteps reuse).
///
/// The clip's own length comes from the file (the waveform/peaks pipeline
/// measures it) — the model stores the link only.
///
/// v1 stores the ABSOLUTE path (the first file reference a project
/// carries); relative-to-project paths arrive with project bundling.
class AudioClip {
  const AudioClip({
    required this.filePath,
    required this.frameId,
    this.offsetFrames = 0,
  }) : assert(offsetFrames >= 0, 'offsetFrames must be non-negative');

  final String filePath;

  /// The SE frame (instance) this sound belongs to.
  final FrameId frameId;

  /// Frames skipped INTO the sound file where the carrying block starts —
  /// the audio lane's slide-the-sound trim. 0 = the file plays from its
  /// beginning; never negative (a sound cannot start before its block:
  /// move the block instead).
  final int offsetFrames;

  AudioClip copyWith({String? filePath, FrameId? frameId, int? offsetFrames}) {
    return AudioClip(
      filePath: filePath ?? this.filePath,
      frameId: frameId ?? this.frameId,
      offsetFrames: offsetFrames ?? this.offsetFrames,
    );
  }

  Map<String, dynamic> toJson() => {
    'file': filePath,
    'frame': frameId.value,
    if (offsetFrames != 0) 'offset': offsetFrames,
  };

  factory AudioClip.fromJson(Map<String, dynamic> json) {
    return AudioClip(
      filePath: json['file'] as String,
      frameId: FrameId(json['frame'] as String),
      offsetFrames: json['offset'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioClip &&
          other.filePath == filePath &&
          other.frameId == frameId &&
          other.offsetFrames == offsetFrames;

  @override
  int get hashCode => Object.hash(filePath, frameId, offsetFrames);

  @override
  String toString() =>
      'AudioClip(filePath: $filePath, frameId: $frameId, '
      'offsetFrames: $offsetFrames)';
}
