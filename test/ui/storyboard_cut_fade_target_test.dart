import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/cut_metadata.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/export/export_frame_renderer.dart';
import 'package:quick_animaker_v2/src/ui/export/export_plan.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_cut_fade_policy.dart';

/// R4-⑨ fade target: FO=black (default) / WO=white, shared by playback and
/// the MP4 bake through cutFadeTargetColor.
void main() {
  Cut cut({CutFadeTarget target = CutFadeTarget.black}) => Cut(
    id: const CutId('fade-cut'),
    name: 'Fade Cut',
    duration: 12,
    canvasSize: const CanvasSize(width: 8, height: 8),
    layers: const [],
    metadata: CutMetadata(fadeTarget: target),
  );

  test('CutMetadata serializes the fade target (default omitted)', () {
    expect(const CutMetadata.empty().toJson().containsKey('fadeTarget'), false);
    final white = CutMetadata(fadeTarget: CutFadeTarget.white);
    final restored = CutMetadata.fromJson(white.toJson());
    expect(restored.fadeTarget, CutFadeTarget.white);
    // Unknown names (newer files) fall back to the black default.
    expect(
      CutMetadata.fromJson({'fadeTarget': 'plaid'}).fadeTarget,
      CutFadeTarget.black,
    );
  });

  test('cutFadeTargetColor maps FO to black and WO to white', () {
    expect(cutFadeTargetColor(cut()), const ui.Color(0xFF000000));
    expect(
      cutFadeTargetColor(cut(target: CutFadeTarget.white)),
      const ui.Color(0xFFFFFFFF),
    );
  });

  testWidgets('the MP4 bake fades toward the cut\'s target color', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final session = EditorSessionManager(
        initialProject: createDefaultProject(),
      );
      addTearDown(session.dispose);

      Future<(int, int, int)> centerPixelOf(Cut faded) async {
        final image = await ExportFrameRenderer(session: session)
            .renderCompositeForVideo(
              ExportFrameTask(cut: faded, frameIndex: 11),
              ExportSizeMode.canvas,
            );
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final centerOffset =
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        image.dispose();
        return (
          bytes!.getUint8(centerOffset),
          bytes.getUint8(centerOffset + 1),
          bytes.getUint8(centerOffset + 2),
        );
      }

      Cut fadedOut(CutFadeTarget target) => cut(target: target).copyWith(
        transformTrack: cutTransformWithFade(
          cut(),
          fadeInFrames: 0,
          fadeOutFrames: 11,
        ),
      );

      // The final frame sits at fade 0: fully the target color.
      final black = await centerPixelOf(fadedOut(CutFadeTarget.black));
      expect(black, (0, 0, 0));

      final white = await centerPixelOf(fadedOut(CutFadeTarget.white));
      expect(white, (255, 255, 255));
    });
  });
}
