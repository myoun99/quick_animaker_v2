import 'package:flutter/widgets.dart';

import '../../models/project_background.dart';

/// Paints the project background (R10-⑥) into [rect]: the solid paper
/// color, or the alpha checkerboard for the transparent (display-only)
/// choice. Canvas-space cells — they zoom with the artwork, so the
/// checker always reads at drawing resolution.
void paintProjectPaper(Canvas canvas, Rect rect, ProjectBackground background) {
  if (!background.transparent) {
    canvas.drawRect(rect, Paint()..color = Color(background.argb));
    return;
  }
  const cell = 8.0;
  canvas.save();
  canvas.clipRect(rect);
  canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
  final gray = Paint()..color = const Color(0xFFCCCCCC);
  final firstColumn = (rect.left / cell).floor();
  final firstRow = (rect.top / cell).floor();
  for (var row = firstRow; row * cell < rect.bottom; row += 1) {
    for (var column = firstColumn; column * cell < rect.right; column += 1) {
      if ((row + column).isEven) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTWH(column * cell, row * cell, cell, cell),
        gray,
      );
    }
  }
  canvas.restore();
}
