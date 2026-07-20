# dr_libs (vendored)

Single-header C audio decoders by David Reid, used by `qa_audio_decode.c`
to turn imported audio into PCM at import time.

| File | Version | Purpose |
|---|---|---|
| `dr_wav.h` | v0.14.6 | WAV decoding |
| `dr_mp3.h` | v0.7.4 | MP3 decoding |
| `dr_flac.h` | v0.13.4 | FLAC decoding |

**Upstream:** https://github.com/mackron/dr_libs
**Pinned commit:** `6d78776c2c05358e351e3c67878a8b681c76c5d1`

Pinned rather than tracking `master` so a given commit of this repository
always builds the same decoder bytes — the same reason the parity suites
exist at all.

## License

All three are **"choice of public domain (Unlicense) or MIT-0"**, stated at
the top of each file and in full at the bottom. Neither option requires
attribution or imposes copyleft, so bundling them in a shipped binary
carries no obligation. Full text stays in the headers; nothing has been
stripped.

This is unrelated to the brush-file rule (no third-party brush *assets* may
ship): that is about content, this is a permissively licensed code library.

## Why vendored rather than fetched at build time

A `FetchContent`/submodule setup would make the build need the network and
make CI's three toolchains depend on GitHub being up. These are three files
with no build system of their own; checking them in is the smaller thing.

## Updating

Download at a NEW pinned commit, update the table and SHA above, then run
the full suite — `qa_audio_decode_test.dart` decodes WAVs written by this
project's own Dart encoder, so a behavioural change in dr_wav shows up
there rather than in someone's project.

## Local modifications

**None.** These are byte-for-byte upstream. Keep it that way: build-time
behaviour is steered with the `DR_*_NO_STDIO` / `DR_*_IMPLEMENTATION`
defines in `qa_audio_decode.c`, never by editing these files, so the next
update stays a straight overwrite.
