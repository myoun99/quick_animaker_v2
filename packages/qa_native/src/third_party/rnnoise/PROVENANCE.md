# RNNoise — vendored, three recorded deviations

- Source: https://github.com/xiph/rnnoise (convenience copy of
  https://gitlab.xiph.org/xiph/rnnoise)
- Version: **v0.1.1** (tag), commit
  `6cbfd53eb348a8d394e0757b4025c6ded34eb2b6`
- Files: `include/rnnoise.h` + `src/` (the library sources with the
  BUILT-IN model, `rnn_data.c` ≈ 428 KB; training scripts and build glue
  are not vendored)
- License: **BSD-3-Clause** (`COPYING` beside this file — Mozilla,
  Jean-Marc Valin, Xiph.Org Foundation, Mark Borgerding). Binary
  distributions must reproduce that notice; keep `COPYING` shipping with
  the sources.
- Modifications — exactly these, each marked `qa patch` in the source;
  an update overwrite must reapply them (or move to an upstream state
  that includes b61fb03's fixes with the classic model, which does not
  exist as of 2026-07):
  1. `src/pitch.c` — upstream commit `b61fb03` ("Making code
     C90-compatible") backported: the three VLAs in `rnn_pitch_search`
     and one in `rnn_remove_doubling` become fixed-bound arrays with
     asserts. MSVC compiles no VLA; upstream fixed this only on the
     new-model line.
  2. `src/celt_lpc.c` — same backport for the `rnn_autocorr` VLA.
  3. `src/rnnoise.h` — a byte-identical COPY of `include/rnnoise.h`
     (layout addition, no file edited): the sources include
     `"rnnoise.h"` by quoted lookup, and the single-TU bundle in
     `qa_audio_denoise.c` resolves it beside the sources without any
     build-flag include paths (podspec forwarders have none to give).

Why v0.1.1 and not v0.2: v0.2 externalized the model weights into a
downloaded blob whose C form is 15–29 MB and would grow EVERY platform
binary by roughly that much. v0.1.1 is the classic built-in model — the
one OBS ships for its noise suppression — trained for voice, 428 KB,
and the quality reference most users mean by "RNNoise".

Why it is here at all: the recording program's noise-suppression round
(대사=on/발소리=off — the model is speech-specific and eats footsteps,
which is exactly why the toggle exists). Capture runs at 48 kHz when
suppression is on — RNNoise is a 48 kHz-native design — and the take
then conforms ONCE through the existing pipeline on placement.
