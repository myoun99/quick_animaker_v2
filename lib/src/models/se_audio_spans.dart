import 'audio_clip.dart';
import 'layer.dart';
import 'timeline_coverage.dart';

/// One audible window of an SE layer: a timeline block whose frame carries
/// a linked sound. The BLOCK is the instance — the sound starts where the
/// block starts and never plays past its end (the audible tail also clamps
/// to the file's own length, which only the peaks pipeline knows).
class SeAudioSpan {
  const SeAudioSpan({
    required this.clip,
    required this.clipIndex,
    required this.startFrame,
    required this.lengthFrames,
  });

  final AudioClip clip;

  /// Index into [Layer.audioClips] (the removal hook's handle).
  final int clipIndex;

  /// Cut-local start of the carrying block.
  final int startFrame;

  /// The carrying block's length — the hard playback/display window.
  final int lengthFrames;

  int get endFrameExclusive => startFrame + lengthFrames;
}

/// Every audible window of [layer], in block order. A frame exposed by
/// several blocks (linked/held reuse — footsteps) yields one span per
/// block; clips whose frame has no block are inert (deleted blocks fall
/// silent, and return when the frame is exposed again — frame-link
/// semantics, same as drawings).
List<SeAudioSpan> seAudioSpans(Layer layer) {
  if (layer.audioClips.isEmpty) {
    return const [];
  }
  final spans = <SeAudioSpan>[];
  for (final block in drawingBlocks(layer.timeline)) {
    for (var index = 0; index < layer.audioClips.length; index += 1) {
      final clip = layer.audioClips[index];
      if (clip.frameId == block.frameId) {
        spans.add(
          SeAudioSpan(
            clip: clip,
            clipIndex: index,
            startFrame: block.startIndex,
            lengthFrames: block.endIndexExclusive - block.startIndex,
          ),
        );
      }
    }
  }
  return spans;
}
