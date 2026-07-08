import 'package:flutter/material.dart';

/// Vertical writing the paper way: one upright glyph per line, top to
/// bottom — never rotated (the user reads section headings face-on, like
/// the timesheet painter's vertical text). Exposes ONE semantics node with
/// the whole [text].
class UprightVerticalText extends StatelessWidget {
  const UprightVerticalText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        // scaleDown: long headings shrink to their host (a one-row section
        // bracket is shorter than its label) instead of overflowing.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final glyph in text.characters)
                Text(glyph, style: style, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
