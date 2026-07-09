import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/property_track.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/transform_track.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/export/export_frame_renderer.dart';
import 'package:quick_animaker_v2/src/ui/export/export_plan.dart';

/// The renderer must consume the store's VALID display cache read-only (the
/// editing coordinator donates the session surface on every commit) instead
/// of replaying the frame's whole command list — the storyboard-thumbnail
/// replay after each stroke was a main part of the post-stroke UI freeze.
void main() {
  testWidgets('renderCel reads the valid display cache and only replays '
      'commands when it is dirty', (tester) async {
    await tester.runAsync(() async {
      final session = EditorSessionManager(
        initialProject: createDefaultProject(),
      );
      addTearDown(session.dispose);
      final cut = session.activeCut;
      final layer = cut.layers.firstWhere(
        (layer) => layer.kind == LayerKind.animation,
      );
      final frame = Frame(
        id: const FrameId('cel-frame'),
        duration: 1,
        strokes: const [],
      );
      final frameKey = session.brushFrameKeyForCut(cut, layer.id, frame.id);

      // Real drawing content: one BLACK stroke committed into the session's
      // store (a replay of the commands can only ever produce black).
      BrushFrameEditingCoordinator(
        initialFrameKey: frameKey,
        frameStore: session.brushFrameStore,
        sessionStore: BrushFrameEditSessionStore(canvasSize: cut.canvasSize),
        historyPolicy: const BrushHistoryPolicy(
          userUndoLimit: 8,
          deferredBakeRatio: 0,
        ),
      ).commitSourceStroke(
        sourceDabs: [
          BrushDab(
            center: CanvasPoint(x: 4, y: 4),
            color: 0xFF000000,
            size: 4,
            opacity: 1,
            flow: 1,
            hardness: 1,
            tipShape: BrushTipShape.round,
            pressure: 1,
            sequence: 0,
          ),
        ],
      );
      final command = session.brushFrameStore
          .getOrCreateFrame(frameKey)
          .paintCommands
          .single;

      // Tamper the (valid) display cache with a RED sentinel pixel at (0,0):
      // reading the cache shows red, replaying the commands cannot.
      final sentinelPixels = Uint8List(256 * 256 * 4);
      sentinelPixels[0] = 255;
      sentinelPixels[3] = 255;
      session.brushFrameStore.storeRebuiltDisplayCache(
        key: frameKey,
        previewSurface: BitmapSurface(canvasSize: cut.canvasSize).putTile(
          BitmapTile(
            coord: TileCoord(x: 0, y: 0),
            size: 256,
            pixels: sentinelPixels,
          ),
        ),
      );

      Future<ByteData> renderedBytes() async {
        final image = await ExportFrameRenderer(session: session).renderCel(
          ExportCelTask(
            cut: cut,
            layer: layer,
            frame: frame,
            fileName: 'cel.png',
          ),
        );
        final bytes = await image!.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!;
      }

      final fromCache = await renderedBytes();
      expect(fromCache.getUint8(0), 255, reason: 'red sentinel = cache read');
      expect(fromCache.getUint8(1), 0);
      expect(fromCache.getUint8(2), 0);

      // Store-level command edits dirty the cache WITHOUT donating — the
      // renderer must then fall back to replaying the commands: the black
      // stroke reappears and the sentinel is gone.
      session.brushFrameStore.markPaintCommandHiddenByUndo(
        frameKey,
        command.id,
      );
      session.brushFrameStore.restorePaintCommandFromUndo(frameKey, command.id);
      expect(
        session.brushFrameStore.displayCacheOrNull(frameKey)!.dirty,
        isTrue,
      );

      final replayed = await renderedBytes();
      expect(replayed.getUint8(3), 0, reason: 'sentinel gone after replay');
      final strokeOffset = (4 * cut.canvasSize.width + 4) * 4;
      expect(
        replayed.getUint8(strokeOffset + 3),
        greaterThan(0),
        reason: 'the black stroke comes back from the command replay',
      );
    });
    await tester.pumpAndSettle();
  });

  testWidgets("renderComposite honors the dialog's Apply-layer-FX master "
      'toggle (R4 new-feature 1)', (tester) async {
    await tester.runAsync(() async {
      final session = EditorSessionManager(
        initialProject: createDefaultProject(),
      );
      addTearDown(session.dispose);
      // A real exposed frame at 0 carrying one BLACK stroke.
      session.createDrawingAtCurrentFrame();
      var cut = session.activeCut;
      final layer = cut.layers.firstWhere(
        (layer) => layer.kind == LayerKind.animation,
      );
      final frame = layer.frames.single;
      final frameKey = session.brushFrameKeyForCut(cut, layer.id, frame.id);
      BrushFrameEditingCoordinator(
        initialFrameKey: frameKey,
        frameStore: session.brushFrameStore,
        sessionStore: BrushFrameEditSessionStore(canvasSize: cut.canvasSize),
        historyPolicy: const BrushHistoryPolicy(
          userUndoLimit: 8,
          deferredBakeRatio: 0,
        ),
      ).commitSourceStroke(
        sourceDabs: [
          BrushDab(
            center: CanvasPoint(x: 4, y: 4),
            color: 0xFF000000,
            size: 4,
            opacity: 1,
            flow: 1,
            hardness: 1,
            tipShape: BrushTipShape.round,
            pressure: 1,
            sequence: 0,
          ),
        ],
      );
      // Animated opacity 0 at frame 0: the layer's FX hide it entirely.
      session.updateLayerTransformTrack(
        layer.id,
        TransformTrack.empty().copyWith(
          opacity: PropertyTrack<double>().withKey(0, 0),
        ),
      );
      cut = session.activeCut;

      Future<int> strokeRedChannel({required bool applyLayerFx}) async {
        final image =
            await ExportFrameRenderer(
              session: session,
              applyLayerFx: applyLayerFx,
            ).renderComposite(
              ExportFrameTask(cut: cut, frameIndex: 0),
              ExportSizeMode.canvas,
            );
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        final offset = (4 * cut.canvasSize.width + 4) * 4;
        return bytes!.getUint8(offset);
      }

      // FX applied (default): the animated opacity blanks the layer — the
      // white paper shows through.
      expect(await strokeRedChannel(applyLayerFx: true), 255);
      // FX bypassed: the raw layer at its static opacity — black stroke.
      expect(await strokeRedChannel(applyLayerFx: false), lessThan(128));
    });
    await tester.pumpAndSettle();
  });
}
