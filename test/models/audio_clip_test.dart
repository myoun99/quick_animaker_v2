import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/audio_clip.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/se_audio_spans.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';

void main() {
  test('AudioClip round-trips through json', () {
    const clip = AudioClip(
      filePath: r'C:\sound\voice.wav',
      frameId: FrameId('se-frame'),
    );

    expect(AudioClip.fromJson(clip.toJson()), clip);
    expect(clip.toJson(), {'file': r'C:\sound\voice.wav', 'frame': 'se-frame'});
  });

  test('offsetFrames round-trips, serializes only when set and stays '
      'backward compatible', () {
    const trimmed = AudioClip(
      filePath: 'a.wav',
      frameId: FrameId('se-frame'),
      offsetFrames: 12,
    );
    expect(trimmed.toJson()['offset'], 12);
    expect(AudioClip.fromJson(trimmed.toJson()), trimmed);

    // Untrimmed clips keep the old json shape; old files decode to 0.
    const plain = AudioClip(filePath: 'a.wav', frameId: FrameId('se-frame'));
    expect(plain.toJson().containsKey('offset'), isFalse);
    expect(
      AudioClip.fromJson({'file': 'a.wav', 'frame': 'se-frame'}).offsetFrames,
      0,
    );
    expect(plain, isNot(trimmed));
    expect(trimmed.copyWith(offsetFrames: 0), plain);
  });

  Layer seLayer() => Layer(
    id: const LayerId('se'),
    name: 'S1',
    kind: LayerKind.se,
    frames: [
      Frame(id: const FrameId('se-frame'), duration: 1, strokes: const []),
    ],
    timeline: const {
      4: TimelineExposure.drawing(FrameId('se-frame'), length: 6),
      16: TimelineExposure.drawing(FrameId('se-frame'), length: 3),
    },
  );

  test('Layer serializes audio clips only when present and round-trips', () {
    final bare = seLayer();
    expect(bare.toJson().containsKey('audioClips'), isFalse);
    expect(Layer.fromJson(bare.toJson()), bare);

    final withClips = bare.copyWith(
      audioClips: const [
        AudioClip(filePath: 'a.wav', frameId: FrameId('se-frame')),
      ],
    );
    final restored = Layer.fromJson(withClips.toJson());
    expect(restored, withClips);
    expect(restored.audioClips.single.frameId, const FrameId('se-frame'));
  });

  test('legacy free-floating clips migrate onto their covering block', () {
    final layer = seLayer();
    final json = layer.toJson();
    json['audioClips'] = [
      {'file': 'covered.wav', 'start': 6}, // inside the 4..10 block
      {'file': 'orphan.wav', 'start': 12}, // empty cell → drops
    ];

    final restored = Layer.fromJson(json);

    expect(restored.audioClips, hasLength(1));
    expect(restored.audioClips.single.filePath, 'covered.wav');
    expect(restored.audioClips.single.frameId, const FrameId('se-frame'));
  });

  test('seAudioSpans windows the sound per carrying block (linked reuse)', () {
    final layer = seLayer().copyWith(
      audioClips: const [
        AudioClip(filePath: 'steps.wav', frameId: FrameId('se-frame')),
      ],
    );

    final spans = seAudioSpans(layer);

    expect(spans, hasLength(2), reason: 'both blocks expose the frame');
    expect(spans[0].startFrame, 4);
    expect(spans[0].lengthFrames, 6);
    expect(spans[1].startFrame, 16);
    expect(spans[1].lengthFrames, 3);
    expect(spans.every((span) => span.clipIndex == 0), isTrue);
  });
}
