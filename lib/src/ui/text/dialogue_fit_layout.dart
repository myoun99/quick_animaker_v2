/// Pure layout math for the SE dialogue "fit" rule: the entry's dialogue
/// glyphs spread evenly across the whole block, like justified text on the
/// paper sheet's SE column. Shared by the timeline row overlay and the
/// timesheet painter, so screen and print distribute identically.
///
/// Returns the main-axis center for each glyph: glyph `i` of [glyphCount]
/// sits at `(i + 0.5) * mainExtent / glyphCount`. A single glyph centers in
/// the span; zero glyphs yield an empty list.
List<double> dialogueGlyphCenters({
  required int glyphCount,
  required double mainExtent,
}) {
  if (glyphCount <= 0) {
    return const [];
  }
  final step = mainExtent / glyphCount;
  return [for (var i = 0; i < glyphCount; i += 1) (i + 0.5) * step];
}
