import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';

/// R4-⑩ regression probe: storyboard cut blocks must show their rendered
/// thumbnail (the real render pipeline, not a fake) — the block's RawImage
/// replaces the empty placeholder once the async render lands.
void main() {
  testWidgets('storyboard cut blocks show a rendered thumbnail end-to-end', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: HomePage(initialProject: createDefaultProject())),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('timeline-mode-storyboard-button')),
      );
      await tester.pumpAndSettle();

      // Let the async thumbnail render land (real ui.Image work needs
      // runAsync), then rebuild.
      for (var attempt = 0; attempt < 20; attempt += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        if (tester
            .widgetList(
              find.byKey(
                ValueKey<String>(
                  'storyboard-cut-thumb-'
                  '${_firstCutId(tester)}',
                ),
              ),
            )
            .isNotEmpty) {
          break;
        }
      }

      expect(
        find.byKey(
          ValueKey<String>(
            'storyboard-cut-thumb-empty-'
            '${_firstCutId(tester)}',
          ),
        ),
        findsNothing,
        reason: 'the placeholder must give way to the rendered thumbnail',
      );
      expect(
        find.byKey(
          ValueKey<String>('storyboard-cut-thumb-${_firstCutId(tester)}'),
        ),
        findsOneWidget,
      );
    });
  });
}

String _firstCutId(WidgetTester tester) {
  // The default project has exactly one cut; read its id off the block key.
  final block = tester
      .widgetList(
        find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('storyboard-cut-block-');
        }),
      )
      .first;
  return (block.key! as ValueKey<String>).value.substring(
    'storyboard-cut-block-'.length,
  );
}
