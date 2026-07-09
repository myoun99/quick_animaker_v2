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
  const AudioClip({required this.filePath, required this.frameId});

  final String filePath;

  /// The SE frame (instance) this sound belongs to.
  final FrameId frameId;

  AudioClip copyWith({String? filePath, FrameId? frameId}) {
    return AudioClip(
      filePath: filePath ?? this.filePath,
      frameId: frameId ?? this.frameId,
    );
  }

  Map<String, dynamic> toJson() => {'file': filePath, 'frame': frameId.value};

  factory AudioClip.fromJson(Map<String, dynamic> json) {
    return AudioClip(
      filePath: json['file'] as String,
      frameId: FrameId(json['frame'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioClip &&
          other.filePath == filePath &&
          other.frameId == frameId;

  @override
  int get hashCode => Object.hash(filePath, frameId);

  @override
  String toString() => 'AudioClip(filePath: $filePath, frameId: $frameId)';
}
