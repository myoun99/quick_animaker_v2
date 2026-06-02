import 'package:flutter/material.dart';

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
    super.key,
    required this.currentFrameIndex,
    required this.frameCount,
    required this.onSelectFrame,
  });

  final int currentFrameIndex;
  final int frameCount;
  final ValueChanged<int> onSelectFrame;

  static const int _minimumVisibleCells = 24;

  @override
  Widget build(BuildContext context) {
    final visibleFrameCount = frameCount < _minimumVisibleCells
        ? _minimumVisibleCells
        : frameCount;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
              child: Text(
                'Timeline • Current frame: $currentFrameIndex',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: visibleFrameCount,
                itemBuilder: (context, index) {
                  final selected = index == currentFrameIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    child: OutlinedButton(
                      key: ValueKey<String>('timeline-frame-$index'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        foregroundColor: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                        minimumSize: const Size(72, 44),
                      ),
                      onPressed: () => onSelectFrame(index),
                      child: Text(selected ? 'Frame $index' : '$index'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
