import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/onion_skin_settings.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
import 'package:quick_animaker_v2/src/ui/panels/onion_skin_panel.dart';

/// P2 wiring: the session's onion requests, the O shortcut and the panel.
void main() {
  test('onion requests target the ACTIVE layer cels at the playhead with '
      'peg opacities and tints; disabled = empty', () {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    // Two drawings on the default layer: cel at 0, cel at 1.
    s.createDrawingAtCurrentFrame();
    s.selectFrameIndex(1);
    s.createDrawingAtCurrentFrame();

    expect(s.onionSkinCanvasRequests(), isEmpty, reason: 'master off');

    s.toggleOnionSkin();
    final requests = s.onionSkinCanvasRequests();
    expect(requests, hasLength(1), reason: 'one unique drawing before');
    expect(requests.single.opacity, 0.4);
    expect(requests.single.tint, const OnionSkinSettings().tintBefore);
    expect(requests.single.frameKey.layerId, s.activeLayer!.id);

    // Images mode drops the tint, keeps the ghost.
    s.onionSkinSettings.value = s.onionSkinSettings.value.copyWith(
      mode: OnionSkinMode.images,
    );
    expect(s.onionSkinCanvasRequests().single.tint, isNull);
  });

  testWidgets('O toggles onion skin; the panel chips and mode drive the '
      'settings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    // Open the Onion Skin tab in the left dock (Ahem-wide tab labels can
    // push it out of the strip's viewport in tests).
    final tab = find.byKey(const ValueKey<String>('panel-tab-onion-skin'));
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();

    final masterToggle = find.byKey(
      const ValueKey<String>('onion-skin-master-toggle'),
    );
    expect(masterToggle, findsOneWidget);
    expect(tester.widget<Switch>(masterToggle).value, isFalse);

    // The O key flips the master toggle (registry action).
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(masterToggle).value, isTrue);

    // Peg chip 2 (before) toggles off through the panel.
    final peg2 = find.byKey(const ValueKey<String>('onion-peg-before-2'));
    expect(tester.widget<FilterChip>(peg2).selected, isTrue);
    await tester.tap(peg2);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(peg2).selected, isFalse);

    // Mode switch to Images.
    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();
    expect(find.byType(OnionSkinPanel), findsOneWidget);
  });
}
