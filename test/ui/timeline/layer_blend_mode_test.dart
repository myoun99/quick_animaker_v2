import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/app_language.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_blend_mode.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/services/cut_frame_composite_plan.dart';
import 'package:quick_animaker_v2/src/services/playback/cut_frame_composite_signature.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_action_toolbar.dart';

/// R26 #30/#30-1: the layer's composite blend mode — model round-trip,
/// the shared composite visit, cache identity, the session commit and
/// the toolbar's PS/CSP-style blend dropdown (user rule 07-22: the type
/// button went back to function-TBD).
void main() {
  test('JSON: normal is omitted (pre-blend files read back unchanged); a '
      'non-normal blend round-trips', () {
    final plain = Layer(id: const LayerId('a'), name: 'A', frames: const []);
    expect(plain.toJson().containsKey('blendMode'), isFalse);
    expect(Layer.fromJson(plain.toJson()).blendMode, LayerBlendMode.normal);

    final multiplied = plain.copyWith(blendMode: LayerBlendMode.multiply);
    expect(multiplied.toJson()['blendMode'], 'multiply');
    expect(
      Layer.fromJson(multiplied.toJson()).blendMode,
      LayerBlendMode.multiply,
    );
    expect(multiplied == plain, isFalse, reason: 'blend joins equality');
  });

  test('the session commit lands on the layer and the shared composite '
      'visit carries it', () {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    s.createDrawingAtCurrentFrame();
    final layerId = s.activeLayer!.id;

    s.setLayerBlendMode(layerId, LayerBlendMode.screen);
    expect(s.activeLayer!.blendMode, LayerBlendMode.screen);

    final entries = resolveCutFrameCompositeEntries(
      cut: s.activeCutOrNull!,
      frameIndex: 0,
    );
    final entry = entries.singleWhere((e) => e.layer.id == layerId);
    expect(entry.blendMode, LayerBlendMode.screen);
  });

  test('a blend change changes the composite cache identity', () {
    const base = CompositeLayerSignature(
      layerId: LayerId('a'),
      frameId: FrameId('f1'),
      opacity: 1,
      sourceRevision: 3,
    );
    const blended = CompositeLayerSignature(
      layerId: LayerId('a'),
      frameId: FrameId('f1'),
      opacity: 1,
      sourceRevision: 3,
      blendMode: LayerBlendMode.multiply,
    );
    expect(base == blended, isFalse);
    expect(
      base ==
          const CompositeLayerSignature(
            layerId: LayerId('a'),
            frameId: FrameId('f1'),
            opacity: 1,
            sourceRevision: 3,
          ),
      isTrue,
    );
  });

  testWidgets('R26 #30-1: the toolbar\'s PS-style blend dropdown shows '
      'the ACTIVE layer\'s mode, commits a pick, reads CSP Japanese in '
      'ja, and hides for non-ACTION rows', (tester) async {
    final s = EditorSessionManager(initialProject: createDefaultProject());
    addTearDown(s.dispose);
    const buttonKey = ValueKey<String>('timeline-layer-blend-menu-button');
    Widget host() => MaterialApp(
      home: Material(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => TimelineActionToolbar(
            session: s,
            onAddLayer: () {},
            onRenameLayer: () {},
            onDeleteLayer: () {},
            onEditInstance: () {},
            onCreateInstance: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(host());
    expect(find.byKey(buttonKey), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);

    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-layer-blend-multiply')),
    );
    await tester.pumpAndSettle();
    expect(s.activeLayer!.blendMode, LayerBlendMode.multiply);
    expect(find.text('Multiply'), findsOneWidget);

    // ja: Clip Studio's terms (user rule 07-22 — ja localized first).
    s.languageSettings.value = const AppLanguageSettings(
      programLanguage: AppLanguage.ja,
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.text('乗算'), findsOneWidget);

    // A non-ACTION active row (CAM) hides the dropdown entirely.
    final camera = s.layers.firstWhere((l) => l.kind == LayerKind.camera);
    s.selectLayer(camera.id);
    await tester.pumpAndSettle();
    expect(find.byKey(buttonKey), findsNothing);
  });
}
