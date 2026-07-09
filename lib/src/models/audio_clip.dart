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
    this.gain = 1.0,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
  }) : assert(offsetFrames >= 0, 'offsetFrames must be non-negative'),
       assert(gain >= 0, 'gain must be non-negative'),
       assert(fadeInFrames >= 0, 'fadeInFrames must be non-negative'),
       assert(fadeOutFrames >= 0, 'fadeOutFrames must be non-negative');

  final String filePath;

  /// The SE frame (instance) this sound belongs to.
  final FrameId frameId;

  /// Frames skipped INTO the sound file where the carrying block starts —
  /// the audio lane's slide-the-sound trim. 0 = the file plays from its
  /// beginning; never negative (a sound cannot start before its block:
  /// move the block instead).
  final int offsetFrames;

  /// Volume multiplier; 1.0 = the file's own level. Playback clamps the
  /// effective volume into what the platform supports; export applies it
  /// exactly (ffmpeg `volume`).
  final double gain;

  /// Frames over which the clip ramps from silence to [gain], anchored at
  /// the audible span's start (the carrying block's start).
  final int fadeInFrames;

  /// Frames over which the clip ramps from [gain] to silence, anchored at
  /// the audible span's end (block/cut end — where playback stops it).
  final int fadeOutFrames;

  AudioClip copyWith({
    String? filePath,
    FrameId? frameId,
    int? offsetFrames,
    double? gain,
    int? fadeInFrames,
    int? fadeOutFrames,
  }) {
    return AudioClip(
      filePath: filePath ?? this.filePath,
      frameId: frameId ?? this.frameId,
      offsetFrames: offsetFrames ?? this.offsetFrames,
      gain: gain ?? this.gain,
      fadeInFrames: fadeInFrames ?? this.fadeInFrames,
      fadeOutFrames: fadeOutFrames ?? this.fadeOutFrames,
    );
  }

  Map<String, dynamic> toJson() => {
    'file': filePath,
    'frame': frameId.value,
    if (offsetFrames != 0) 'offset': offsetFrames,
    if (gain != 1.0) 'gain': gain,
    if (fadeInFrames != 0) 'fadeIn': fadeInFrames,
    if (fadeOutFrames != 0) 'fadeOut': fadeOutFrames,
  };

  factory AudioClip.fromJson(Map<String, dynamic> json) {
    return AudioClip(
      filePath: json['file'] as String,
      frameId: FrameId(json['frame'] as String),
      offsetFrames: json['offset'] as int? ?? 0,
      gain: (json['gain'] as num?)?.toDouble() ?? 1.0,
      fadeInFrames: json['fadeIn'] as int? ?? 0,
      fadeOutFrames: json['fadeOut'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioClip &&
          other.filePath == filePath &&
          other.frameId == frameId &&
          other.offsetFrames == offsetFrames &&
          other.gain == gain &&
          other.fadeInFrames == fadeInFrames &&
          other.fadeOutFrames == fadeOutFrames;

  @override
  int get hashCode => Object.hash(
    filePath,
    frameId,
    offsetFrames,
    gain,
    fadeInFrames,
    fadeOutFrames,
  );

  @override
  String toString() =>
      'AudioClip(filePath: $filePath, frameId: $frameId, '
      'offsetFrames: $offsetFrames, gain: $gain, '
      'fadeInFrames: $fadeInFrames, fadeOutFrames: $fadeOutFrames)';
}
