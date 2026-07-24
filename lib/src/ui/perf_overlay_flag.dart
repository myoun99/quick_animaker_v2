/// The frame-timing overlay switch — a MEASUREMENT tool, not a feature.
///
/// Turn it on for a run without touching source:
///
/// ```
/// flutter run --profile --dart-define=QA_PERF_OVERLAY=true
/// ```
///
/// Flutter then draws two graphs over the app: the UI thread (build,
/// layout, paint — the Dart work) above the RASTER thread (turning the
/// recorded picture into pixels). Each bar is one frame; the horizontal
/// line is the current display's frame budget, so bars crossing it are
/// the jank. Read them while DOING the thing — Flutter renders on demand,
/// so an idle app sitting at 0 fps is not a finding.
///
/// What it is for here: the three canvas workloads have opposite
/// requirements and only measurement tells them apart — a stroke wants
/// the lowest possible latency at the display's full rate (120Hz on
/// ProMotion, which `CADisableMinimumFrameDurationOnPhone` in
/// ios/Runner/Info.plist unlocks), playback wants exactly the cel rate
/// and nothing more, and a scrub wants neither to drop frames nor to
/// re-raster cels it already has.
///
/// Judge on a DEBUG build (the project's performance bar) and take the
/// bottleneck apart with `--profile` + DevTools once the overlay says
/// which thread is losing.
///
/// Defaults to false, pinned by a test: a build must never ship with the
/// overlay on.
const bool kShowPerformanceOverlay = bool.fromEnvironment('QA_PERF_OVERLAY');
