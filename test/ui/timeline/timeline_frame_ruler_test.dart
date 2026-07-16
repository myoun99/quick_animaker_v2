import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_ruler.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

void main() {
  testWidgets('renders supplied frame ruler range and preserves header keys', (
    tester,
  ) async {
    int? selectedFrameIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineFrameRuler(
            frameStartIndex: 2,
            frameEndIndexExclusive: 5,
            currentFrameIndex: 3,
            playbackFrameCount: 5,
            leadingFrameSpacerWidth: 96,
            trailingFrameSpacerWidth: 144,
            metrics: TimelineGridMetrics.defaults,
            onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-ruler')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-row')),
      findsOneWidget,
    );
    final rulerBoundary = find.byKey(
      const ValueKey<String>('timeline-cut-end-boundary-ruler'),
    );
    expect(rulerBoundary, findsOneWidget);
    expect(
      tester.getTopLeft(rulerBoundary).dx -
          tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('timeline-frame-ruler')),
              )
              .dx,
      5 * TimelineGridMetrics.defaults.frameCellWidth,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-header-leading-spacer'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-header-trailing-spacer'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-5')),
      findsNothing,
    );

    // The header cells are PASSIVE (UI-R10 #25): selection rides the
    // grid's ruler scrub listener, not per-cell taps — the standalone
    // ruler forwards nothing.
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-frame-header-4')),
      warnIfMissed: false,
    );
    expect(selectedFrameIndex, isNull);
  });
}
