import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_blend_mode.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/services/cut_frame_composite_plan.dart';
import 'package:quick_animaker_v2/src/services/playback/cut_frame_composite_signature.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_layer_controls_row.dart';

/// R26 #30: the layer's composite blend mode — model round-trip, the
/// shared composite visit, cache identity, the session commit and the
/// type button's flyout entrance.
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

  testWidgets('the type button opens the blend flyout on ACTION rows; '
      'picking Multiply commits and the kind icon tints accent', (
    tester,
  ) async {
    var layer = Layer(id: const LayerId('a'), name: 'A', frames: const []);
    LayerBlendMode? committed;
    Widget host() => MaterialApp(
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 28,
            child: TimelineLayerControlsRow(
              layer: layer,
              active: false,
              metrics: const TimelineGridMetrics(),
              onSelectLayer: (_) {},
              onToggleLayerVisibility: (_) {},
              onLayerOpacityChanged: (_, _) {},
              onToggleLayerTimesheet: (_) {},
              onLayerMarkSelected: (_, _) {},
              onSetLayerBlendMode: (id, mode) => committed = mode,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host());
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-layer-type-button-a')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-layer-blend-multiply-a')),
    );
    await tester.pumpAndSettle();
    expect(committed, LayerBlendMode.multiply);

    // The committed blend tints the kind icon accent (color-only
    // indicator, the selection-style rule).
    layer = layer.copyWith(blendMode: LayerBlendMode.multiply);
    await tester.pumpWidget(host());
    final context = tester.element(
      find.byKey(const ValueKey<String>('timeline-layer-kind-icon-a')),
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey<String>('timeline-layer-kind-icon-a')),
          )
          .color,
      Theme.of(context).colorScheme.primary,
    );
  });
}
