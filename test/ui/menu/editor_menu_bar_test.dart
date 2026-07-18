import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';
import 'package:quick_animaker_v2/src/ui/debug/input_inspector.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';

/// The top menu bar (W2): every submenu lists its commands, enablement
/// tracks the session's `can*` gates, the Window menu keeps the retired
/// Panels menu's item keys, and Reset Workspace Layout restores the
/// factory docks.
void main() {
  Future<ProjectRepository> pumpHome(WidgetTester tester) async {
    late ProjectRepository repository;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(onRepositoryCreated: (repo) => repository = repo),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> openMenu(WidgetTester tester, String menuKey) async {
    // The strip scrolls horizontally on narrow windows — bring the menu
    // button into view first.
    await tester.ensureVisible(find.byKey(ValueKey<String>(menuKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>(menuKey)));
    await tester.pumpAndSettle();
  }

  testWidgets('the strip replaces the AppBar and keeps the quick-action '
      'keys', (tester) async {
    await pumpHome(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey<String>('undo-button')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('redo-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('export-png-button')),
      findsOneWidget,
    );
    for (final menu in ['file', 'edit', 'cut', 'layer', 'playback', 'help']) {
      expect(
        find.byKey(ValueKey<String>('menu-$menu')),
        findsOneWidget,
        reason: 'the $menu menu must be on the bar',
      );
    }
    expect(
      find.byKey(const ValueKey<String>('panels-menu-button')),
      findsOneWidget,
    );
  });

  testWidgets('File: export opens; the persistence entries are live (P3)', (
    tester,
  ) async {
    await pumpHome(tester);
    await openMenu(tester, 'menu-file');

    for (final slot in ['file-open', 'file-save', 'file-save-as']) {
      final item = tester.widget<MenuItemButton>(
        find.byKey(ValueKey<String>('menu-$slot')),
      );
      expect(item.onPressed, isNotNull, reason: '$slot is live since P3');
    }

    await tester.tap(find.byKey(const ValueKey<String>('menu-file-export')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('export-run-button')),
      findsOneWidget,
    );
  });

  testWidgets('Edit: undo enablement tracks history and the item undoes', (
    tester,
  ) async {
    final repository = await pumpHome(tester);
    final cutsBefore = repository.requireProject().tracks.first.cuts.length;

    await openMenu(tester, 'menu-edit');
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey<String>('menu-edit-undo')),
          )
          .onPressed,
      isNull,
      reason: 'nothing to undo on a fresh project',
    );
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey<String>('menu-edit-keyboard-shortcuts')),
          )
          .onPressed,
      isNotNull,
      reason: 'the shortcuts editor is live (P1)',
    );
    // Close the menu, make an undoable edit through the Cut menu.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await openMenu(tester, 'menu-cut');
    await tester.tap(find.byKey(const ValueKey<String>('menu-cut-new')));
    await tester.pumpAndSettle();
    expect(
      repository.requireProject().tracks.first.cuts.length,
      cutsBefore + 1,
    );

    await openMenu(tester, 'menu-edit');
    await tester.tap(find.byKey(const ValueKey<String>('menu-edit-undo')));
    await tester.pumpAndSettle();
    expect(repository.requireProject().tracks.first.cuts.length, cutsBefore);
  });

  testWidgets('Layer: add layer lands in the project', (tester) async {
    final repository = await pumpHome(tester);
    final layersBefore = repository
        .requireProject()
        .tracks
        .first
        .cuts
        .first
        .layers
        .length;

    await openMenu(tester, 'menu-layer');
    await tester.tap(find.byKey(const ValueKey<String>('menu-layer-add')));
    await tester.pumpAndSettle();

    expect(
      repository.requireProject().tracks.first.cuts.first.layers.length,
      layersBefore + 1,
    );
  });

  testWidgets('Window: the panel checkboxes keep the retired Panels-menu '
      'keys and toggle panels', (tester) async {
    await pumpHome(tester);

    // Close a panel by its tab X, reopen it from Window (the old flow).
    await tester.tap(find.byKey(const ValueKey<String>('panel-close-brushes')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('panel-tab-brushes')),
      findsNothing,
    );

    await openMenu(tester, 'panels-menu-button');
    await tester.tap(
      find.byKey(const ValueKey<String>('panels-menu-item-brushes')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('panel-tab-brushes')),
      findsOneWidget,
    );
  });

  testWidgets('Window: Reset Workspace Layout restores closed panels', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey<String>('panel-close-brushes')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('panel-tab-brushes')),
      findsNothing,
    );

    await openMenu(tester, 'panels-menu-button');
    await tester.tap(
      find.byKey(const ValueKey<String>('menu-window-reset-layout')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('panel-tab-brushes')),
      findsOneWidget,
    );
  });

  testWidgets('Help: About opens the framework about dialog', (tester) async {
    await pumpHome(tester);

    await openMenu(tester, 'menu-help');
    await tester.tap(find.byKey(const ValueKey<String>('menu-help-about')));
    await tester.pumpAndSettle();

    expect(find.byType(AboutDialog), findsOneWidget);
  });

  testWidgets('Edit: Input Inspector toggles the diagnosis overlay (PEN-1)', (
    tester,
  ) async {
    addTearDown(InputInspector.reset);
    await pumpHome(tester);

    // The Edit menu is long — the inspector entry sits at the bottom and
    // needs scrolling into the menu panel's view first.
    Future<void> tapInspectorItem() async {
      final item = find.byKey(
        const ValueKey<String>('menu-edit-input-inspector'),
      );
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await openMenu(tester, 'menu-edit');
    await tapInspectorItem();
    expect(
      find.byKey(const ValueKey<String>('input-inspector-card')),
      findsOneWidget,
    );

    await openMenu(tester, 'menu-edit');
    await tapInspectorItem();
    expect(
      find.byKey(const ValueKey<String>('input-inspector-card')),
      findsNothing,
    );
  });
}
