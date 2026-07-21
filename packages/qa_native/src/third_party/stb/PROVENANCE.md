# stb_vorbis — vendored, unmodified

- Source: https://github.com/nothings/stb
- File: `stb_vorbis.c` (v1.22)
- Commit: `31c1ad37456438565541f4919958214b6e762fb4`
- License: dual **MIT / public domain (Unlicense)** — same family as the
  dr_libs and miniaudio bundles beside it; no attribution obligation, no
  copyleft.
- Modifications: **none**. Updates must stay a straight overwrite of the
  upstream file at a pinned commit, recorded here.

Why it is here: the EXPORT-AUDIO round removed ffmpeg from every audio
path. ogg was the one format the vendored dr_libs family does not read
(there is no dr_ogg), so the ffmpeg waveform fallback existed for it
alone. stb_vorbis closes that gap natively — decoded once at import like
every other format, waveforms on tablets included.
