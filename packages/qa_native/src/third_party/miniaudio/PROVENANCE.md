# miniaudio (vendored)

Single-header C audio playback/capture library by David Reid, used by
`qa_audio_device.c` to open the output device and drive the mix callback.

| File | Version |
|---|---|
| `miniaudio.h` | v0.11.25 |

**Upstream:** https://github.com/mackron/miniaudio
**Pinned commit:** `9634bedb5b5a2ca38c1ee7108a9358a4e233f14d`

Pinned rather than tracking `master` for the same reason dr_libs is: a
given commit of this repository must always build the same audio path.

## License

**Choice of public domain (Unlicense) or MIT-0** — the same terms as
dr_libs, from the same author. No attribution required, no copyleft. Full
text stays at the bottom of the header; nothing has been stripped.

## Why this one

It is a single file with no build system, supports every platform this
project targets from one source (WASAPI, CoreAudio, ALSA/PulseAudio,
AAudio/OpenSL), and dlopens the platform APIs at runtime so building needs
no audio dev headers — which is what keeps CI's Linux job from needing an
ALSA package.

It also ships a **null backend**, which is why the device layer is
testable here at all: `MA_BACKEND_NULL` runs the real callback on a real
thread with no hardware, so the transport, the mixing and the reported
playback position are all exercised on a CI runner that has no sound card.

## Local modifications

**None.** Byte-for-byte upstream. Behaviour is steered with the `MA_NO_*`
/ `MA_ENABLE_*` defines in `qa_audio_device.c`, never by editing this
file, so the next update stays a straight overwrite.
