/// How far a drag at [pos] has pushed past either end of a [extent]-long
/// axis, once it enters the [edge]-wide band at either end: negative near
/// the start, positive near the end, zero in the middle. The caller adds
/// this to its scroll offset to auto-pan.
///
/// Every timeline and storyboard edge-scroll shares this 24px band, so the
/// band width and the past-the-edge math live here once.
double edgeAutoPanDelta(double pos, double extent, {double edge = 24.0}) {
  if (pos > extent - edge) {
    return pos - (extent - edge);
  }
  if (pos < edge) {
    return pos - edge;
  }
  return 0;
}
