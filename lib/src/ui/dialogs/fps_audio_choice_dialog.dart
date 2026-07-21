import 'package:flutter/material.dart';

import '../../models/project_frame_rate.dart';
import '../text/app_strings.dart';

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
  required AppStrings strings,
}) {
  return showDialog<FpsAudioChoice>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey<String>('fps-audio-choice-dialog'),
      title: Text(
        strings.fpsAudioTitleTemplate
            .replaceAll('{from}', from.label)
            .replaceAll('{to}', to.label),
      ),
      content: SizedBox(
        width: 440,
        child: Text(
          strings.fpsAudioBody,
          style: const TextStyle(fontSize: 13),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('fps-audio-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.commonCancel),
        ),
        TextButton(
          key: const ValueKey<String>('fps-audio-keep'),
          onPressed: () => Navigator.of(context).pop(FpsAudioChoice.keep),
          child: Text(strings.fpsAudioKeep),
        ),
        FilledButton(
          key: const ValueKey<String>('fps-audio-pull'),
          onPressed: () => Navigator.of(context).pop(FpsAudioChoice.pull),
          child: Text(strings.fpsAudioPull),
        ),
      ],
    ),
  );
}
