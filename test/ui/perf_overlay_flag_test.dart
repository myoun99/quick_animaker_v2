import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
import 'package:quick_animaker_v2/src/ui/perf_overlay_flag.dart';

/// The performance overlay is a measurement switch, so the only thing
/// worth pinning is that it stays OFF unless a run asks for it — an
/// overlay left on ships two graphs across the user's canvas.
void main() {
  test('the overlay is off unless --dart-define=QA_PERF_OVERLAY=true', () {
    expect(
      kShowPerformanceOverlay,
      isFalse,
      reason: 'default builds must not draw the frame-timing graphs',
    );
  });

  testWidgets('the app hands the flag to MaterialApp', (tester) async {
    // Built directly (not pumped): mounting HomePage would spin up the
    // whole editor, and what is under test is the wiring.
    final app = const QuickAnimakerApp().build(
      _StubContext(),
    );
    expect(app, isA<ListenableBuilder>());

    final materialApp = (app as ListenableBuilder).builder(
      _StubContext(),
      null,
    );
    expect(
      (materialApp as MaterialApp).showPerformanceOverlay,
      kShowPerformanceOverlay,
    );
  });
}

/// The builders under test never touch their context.
class _StubContext extends StatelessElement {
  _StubContext() : super(const _StubWidget());
}

class _StubWidget extends StatelessWidget {
  const _StubWidget();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
