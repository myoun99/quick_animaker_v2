const int defaultCutDurationFrames = 24;

/// RETIRED to zero (UI-R10 #23): the fixed post-cut allowance is gone —
/// the endless frame axis (scroll-driven growth + ruler edge auto-pan)
/// supplies every frame past the cut instead of a canned tail.
const int defaultTimelineSafetyFrameCount = 0;
