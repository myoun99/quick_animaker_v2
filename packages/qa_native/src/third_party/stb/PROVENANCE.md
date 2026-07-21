# stb — vendored, unmodified

- Source: https://github.com/nothings/stb
- Files: `stb_vorbis.c` (v1.22), `stb_image_write.h` (v1.16)
- Commit: `31c1ad37456438565541f4919958214b6e762fb4` (both files, one pin)
- License: dual **MIT / public domain (Unlicense)** — same family as the
  dr_libs and miniaudio bundles beside it; no attribution obligation, no
  copyleft.
- Modifications: **none**. Updates must stay a straight overwrite of the
  upstream files at a pinned commit, recorded here.

Why stb_vorbis is here: the EXPORT-AUDIO round removed ffmpeg from every
audio path. ogg was the one format the vendored dr_libs family does not
read (there is no dr_ogg), so the ffmpeg waveform fallback existed for it
alone. stb_vorbis closes that gap natively — decoded once at import like
every other format, waveforms on tablets included.

Why stb_image_write is here: the export window's JPG output (EX4).
Flutter's engine encodes PNG only; stb's baseline JPEG writer runs the
same everywhere (tablets included, no ffmpeg, no pub dependency) and its
output is byte-deterministic — testable the way the rest of the engine
is.
