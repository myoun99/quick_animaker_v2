import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/layer_mark.dart';
import 'package:quick_animaker_v2/src/ui/theme/app_theme.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_row_filter.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_row_filter_bar.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('the filter chip bar is hidden when no filter is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        TimelineRowFilterBar(
          rowFilter: TimelineRowFilter.none,
          onSetRowFilter: (_) {},
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('row-filter-clear-all')),
      findsNothing,
    );
  });

  testWidgets('each active facet gets a dismissible chip; tapping removes it', (
    tester,
  ) async {
    TimelineRowFilter current = const TimelineRowFilter(
      markColors: {LayerMark.red},
      onTimesheetOnly: true,
    );
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder: (context, setState) => TimelineRowFilterBar(
            rowFilter: current,
            onSetRowFilter: (next) => setState(() => current = next),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('row-filter-chip-mark-red')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('row-filter-chip-sheet')),
      findsOneWidget,
    );

    // Removing the red chip drops only that facet.
    await tester.tap(
      find.byKey(const ValueKey<String>('row-filter-chip-mark-red')),
    );
    await tester.pumpAndSettle();
    expect(current.markColors, isEmpty);
    expect(current.onTimesheetOnly, isTrue);

    // Clear-all empties the rest.
    await tester.tap(
      find.byKey(const ValueKey<String>('row-filter-clear-all')),
    );
    await tester.pumpAndSettle();
    expect(current.isActive, isFalse);
  });
}
