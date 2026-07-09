import 'package:flutter/material.dart';

/// How the instance-length field displays and parses its value: the
/// timesheet's seconds+komas notation ('1+12') or a bare frame count
/// ('36f').
enum InstanceLengthFormat { secondsPlusKomas, frames }

/// App-run persistence for the shared length field: the last committed
/// length and the chosen notation prefill the next dialog open — BOTH
/// instance dialogs (SE and instruction) share this memory (entrance
/// unification).
class InstanceLengthMemory {
  InstanceLengthMemory._();

  static InstanceLengthFormat format = InstanceLengthFormat.secondsPlusKomas;
  static int lengthFrames = 24;
}

/// Parses [text] under [format]; null = invalid. Seconds+komas accepts
/// 's+k' ('1+12') or a bare koma count ('12'); frames accepts a count with
/// an optional trailing 'f' ('36' / '36f'). Lengths are at least 1 frame.
int? parseInstanceLength(
  String text,
  InstanceLengthFormat format, {
  required int fps,
}) {
  final trimmed = text.trim();
  final int? frames;
  switch (format) {
    case InstanceLengthFormat.secondsPlusKomas:
      final match = RegExp(r'^(\d+)\+(\d+)$').firstMatch(trimmed);
      frames = match != null
          ? int.parse(match.group(1)!) * fps + int.parse(match.group(2)!)
          : int.tryParse(trimmed);
    case InstanceLengthFormat.frames:
      final match = RegExp(r'^(\d+)f?$').firstMatch(trimmed);
      frames = match == null ? null : int.parse(match.group(1)!);
  }
  return frames == null || frames < 1 ? null : frames;
}

/// The display text for [lengthFrames] under [format].
String formatInstanceLength(
  int lengthFrames,
  InstanceLengthFormat format, {
  required int fps,
}) {
  final safeFps = fps < 1 ? 1 : fps;
  return switch (format) {
    InstanceLengthFormat.secondsPlusKomas =>
      '${lengthFrames ~/ safeFps}+${lengthFrames % safeFps}',
    InstanceLengthFormat.frames => '${lengthFrames}f',
  };
}

/// The instance dialogs' shared length input: a text field plus the
/// notation toggle. Prefills from [InstanceLengthMemory]; reports every
/// edit through [onChanged] (null while the text does not parse). The
/// notation choice persists immediately; the value persists when the
/// owning dialog commits ([InstanceLengthMemory.lengthFrames]).
class InstanceLengthField extends StatefulWidget {
  const InstanceLengthField({
    super.key,
    required this.fps,
    required this.onChanged,
  });

  final int fps;
  final ValueChanged<int?> onChanged;

  @override
  State<InstanceLengthField> createState() => _InstanceLengthFieldState();
}

class _InstanceLengthFieldState extends State<InstanceLengthField> {
  InstanceLengthFormat _format = InstanceLengthMemory.format;
  late final TextEditingController _controller = TextEditingController(
    text: formatInstanceLength(
      InstanceLengthMemory.lengthFrames,
      _format,
      fps: widget.fps,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _parsed =>
      parseInstanceLength(_controller.text, _format, fps: widget.fps);

  void _setFormat(InstanceLengthFormat next) {
    if (next == _format) {
      return;
    }
    final current = _parsed;
    setState(() {
      _format = next;
      InstanceLengthMemory.format = next;
      if (current != null) {
        _controller.text = formatInstanceLength(current, next, fps: widget.fps);
      }
    });
    widget.onChanged(_parsed);
  }

  @override
  Widget build(BuildContext context) {
    final secondsPlusKomas = _format == InstanceLengthFormat.secondsPlusKomas;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey<String>('instance-length-field'),
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Length',
              hintText: secondsPlusKomas ? '1+12' : '36f',
              errorText: _parsed == null
                  ? 'e.g. ${secondsPlusKomas ? '1+12' : '36f'}'
                  : null,
            ),
            onChanged: (_) {
              setState(() {});
              widget.onChanged(_parsed);
            },
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<InstanceLengthFormat>(
          key: const ValueKey<String>('instance-length-format-toggle'),
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: const [
            ButtonSegment(
              value: InstanceLengthFormat.secondsPlusKomas,
              label: Text('s+k'),
            ),
            ButtonSegment(value: InstanceLengthFormat.frames, label: Text('F')),
          ],
          selected: {_format},
          onSelectionChanged: (selection) => _setFormat(selection.single),
        ),
      ],
    );
  }
}
