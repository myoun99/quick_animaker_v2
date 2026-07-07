/// One sound file placed on an SE layer: [filePath] starts playing at the
/// cut-local [startFrame]. The clip's length comes from the file itself
/// (the waveform/peaks pipeline measures it) — the model stores placement
/// only.
///
/// v1 stores the ABSOLUTE path (the first file reference a project
/// carries); relative-to-project paths arrive with project bundling.
class AudioClip {
  const AudioClip({required this.filePath, required this.startFrame})
    : assert(startFrame >= 0);

  final String filePath;

  /// Cut-local frame the clip starts on.
  final int startFrame;

  AudioClip copyWith({String? filePath, int? startFrame}) {
    return AudioClip(
      filePath: filePath ?? this.filePath,
      startFrame: startFrame ?? this.startFrame,
    );
  }

  Map<String, dynamic> toJson() => {'file': filePath, 'start': startFrame};

  factory AudioClip.fromJson(Map<String, dynamic> json) {
    return AudioClip(
      filePath: json['file'] as String,
      startFrame: json['start'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioClip &&
          other.filePath == filePath &&
          other.startFrame == startFrame;

  @override
  int get hashCode => Object.hash(filePath, startFrame);

  @override
  String toString() => 'AudioClip(filePath: $filePath, start: $startFrame)';
}
