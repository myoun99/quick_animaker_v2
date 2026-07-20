# QuickAnimaker v2

QuickAnimaker v2 is a Flutter/Dart 2D bitmap animation tool targeting a TVPaint-style production workflow.

**License: all rights reserved.** This repository is public so the source
can be read and so CI can build it on every platform — that is not a
grant of rights. See [LICENSE](LICENSE) and [THIRD_PARTY.md](THIRD_PARTY.md).

For current project policy and architecture direction, start here:

- `docs/Current_Docs_Index.md`

Important:

- `Current_*` documents are the source of truth for current architecture policy.
- Historical `Phase_*_Codex_Task.md` files are task/order records and must not override the matching current documents.
- Before planning or implementing a module, read the matching `Current_*` document directly.

## Color space

QuickAnimaker's working color space is **sRGB** — every brush, fill and
composite treats its 8-bit RGBA bytes as sRGB, matching the drawing
stage of professional 2D pipelines (TVPaint/CSP); delivery color
conversion (Rec.709, DCI-P3, ACES) belongs to the downstream
compositing step. Exported PNG sequences are tagged with the standard
`sRGB`/`gAMA`/`cHRM` chunks so other tools interpret the colors
identically instead of guessing.
