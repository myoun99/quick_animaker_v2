import 'package:flutter/material.dart';

import '../../models/project_frame_rate.dart';

/// EXPORT-AUDIO ④ (the RT conform semantics): what happens to SOUND on a
/// pulldown-pair rate change.
enum FpsAudioChoice {
  /// Time-exact: audio keeps its real seconds; frame spans recompute and
  /// drift 0.1% against the drawing.
  keep,

  /// Frame-exact: audio pulls by the exact rational (inaudible pitch
  /// change) so every sound keeps its frame span.
  pull,
}

/// Asks the one question a 23.976↔24-style change poses. 24 ≠ 24000/1001,
/// so "frame-exact AND time-exact" is mathematically impossible — the
/// dialog exists because someone has to choose, and choosing silently
/// would look like a sync bug later.
///
/// Returns null on cancel (the rate does not change either).
Future<FpsAudioChoice?> showFpsAudioChoiceDialog(
  BuildContext context, {
  required ProjectFrameRate from,
  required ProjectFrameRate to,
}) {
  return showDialog<FpsAudioChoice>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey<String>('fps-audio-choice-dialog'),
      title: Text('${from.label} → ${to.label}: what happens to sound?'),
      content: const SizedBox(
        width: 440,
        child: Text(
          'These two rates differ by 0.1% in real speed, and audio exists '
          'in real seconds — it cannot stay both frame-exact and '
          'time-exact.\n\n'
          '• Keep audio timing: sounds keep their real seconds; their '
          'frame positions drift by 0.1% (about one frame every 42 '
          'seconds).\n\n'
          '• Pull audio 0.1%: sounds are resampled by the exact pulldown '
          'ratio (an inaudible pitch change — the standard telecine '
          'conform) so every sound keeps its exact frame span.',
          style: TextStyle(fontSize: 13),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('fps-audio-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey<String>('fps-audio-keep'),
          onPressed: () => Navigator.of(context).pop(FpsAudioChoice.keep),
          child: const Text('Keep audio timing'),
        ),
        FilledButton(
          key: const ValueKey<String>('fps-audio-pull'),
          onPressed: () => Navigator.of(context).pop(FpsAudioChoice.pull),
          child: const Text('Pull audio 0.1%'),
        ),
      ],
    ),
  );
}
