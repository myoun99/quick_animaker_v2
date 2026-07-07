import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/audio_clip.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';

void main() {
  test('AudioClip round-trips through json', () {
    const clip = AudioClip(filePath: r'C:\sound\voice.wav', startFrame: 12);

    expect(AudioClip.fromJson(clip.toJson()), clip);
    expect(clip.toJson(), {'file': r'C:\sound\voice.wav', 'start': 12});
  });

  test('Layer serializes audio clips only when present and round-trips', () {
    final bare = Layer(
      id: const LayerId('se'),
      name: 'S1',
      kind: LayerKind.se,
      frames: const [],
      timeline: const {},
    );
    expect(bare.toJson().containsKey('audioClips'), isFalse);
    expect(Layer.fromJson(bare.toJson()), bare);

    final withClips = bare.copyWith(
      audioClips: const [
        AudioClip(filePath: 'a.wav', startFrame: 0),
        AudioClip(filePath: 'b.mp3', startFrame: 24),
      ],
    );
    final restored = Layer.fromJson(withClips.toJson());
    expect(restored, withClips);
    expect(restored.audioClips[1].startFrame, 24);
  });
}
