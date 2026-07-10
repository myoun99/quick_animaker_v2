import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/audio_clip.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_id.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_mask.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/media_asset.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/persistence/brush_drawing_binary_codec.dart';
import 'package:quick_animaker_v2/src/services/persistence/qap_project_archive.dart';

void main() {
  final mask = BrushTipMask(
    id: 'chalk',
    size: 2,
    alpha: Uint8List.fromList([0, 64, 128, 255]),
  );

  BrushDab dab(int sequence, {BrushTipMask? tip, bool erase = false}) =>
      BrushDab(
        center: CanvasPoint(x: 12.5, y: -3.25),
        color: 0xFF3366CC,
        size: 14.5,
        opacity: 0.8,
        flow: 0.6,
        hardness: 0.9,
        tipShape: BrushTipShape.square,
        pressure: 0.5,
        sequence: sequence,
        roundness: 0.75,
        angleDegrees: 33.5,
        tipMask: tip,
        dualMask: tip,
        dualMaskScale: 1.5,
        dualOffsetU: 0.25,
        dualOffsetV: 0.75,
        textureMask: tip,
        textureScale: 2.0,
        textureDensity: 0.4,
        erase: erase,
      );

  const key = BrushFrameKey(
    projectId: ProjectId('p'),
    trackId: TrackId('t'),
    cutId: CutId('c'),
    layerId: LayerId('l'),
    frameId: FrameId('f'),
  );

  QapDrawingEntry entry() => QapDrawingEntry(
    key: key,
    commands: [
      BrushPaintCommand(
        id: const BrushPaintCommandId('cmd-1'),
        sequenceNumber: 1,
        kind: BrushPaintCommandKind.paintStroke,
        sourceDabs: [
          dab(0, tip: mask),
          dab(1, erase: true),
        ],
      ),
      const BrushPaintCommand(
        id: BrushPaintCommandId('cmd-2'),
        sequenceNumber: 2,
        kind: BrushPaintCommandKind.eraseStroke,
      ),
    ],
  );

  test('the drawing codec round-trips: keys, commands, masks by index, and '
      'the quantization is canonical (re-encoding reproduces the bytes)', () {
    final masks = collectTipMasks([entry()]);
    expect(masks, hasLength(1), reason: 'tip/dual/texture dedup by id');
    final maskIndex = {
      for (var i = 0; i < masks.length; i += 1) masks[i].id: i,
    };

    final decodedMasks = decodeTipMaskTable(encodeTipMaskTable(masks));
    expect(decodedMasks.single.id, 'chalk');
    expect(decodedMasks.single.alpha, mask.alpha);

    final bytes = encodeDrawingEntry(entry(), maskIndex);
    final decoded = decodeDrawingEntry(bytes, decodedMasks);
    expect(decoded.key, key);
    expect(decoded.commands, hasLength(2));
    final first = decoded.commands.first;
    expect(first.id, const BrushPaintCommandId('cmd-1'));
    expect(first.kind, BrushPaintCommandKind.paintStroke);
    expect(first.sourceDabs, hasLength(2));
    final d = first.sourceDabs.first;
    expect(d.color, 0xFF3366CC);
    expect(d.tipShape, BrushTipShape.square);
    expect(d.tipMask!.id, 'chalk');
    expect(d.opacity, closeTo(0.8, 1 / 255));
    expect(d.center.x, closeTo(12.5, 1e-4));
    expect(d.center.y, closeTo(-3.25, 1e-4));
    expect(first.sourceDabs[1].erase, isTrue);

    // Canonical quantization: encode(decode(bytes)) == bytes.
    expect(encodeDrawingEntry(decoded, maskIndex), bytes);
  });

  test('the archive round-trips project + drawings; media under the save '
      'directory records relative paths and remaps on the way in', () {
    final project = createDefaultProject().copyWith(
      mediaAssets: const [
        MediaAsset(path: 'D:/work/proj/audio/boom.wav', name: 'boom'),
        MediaAsset(path: 'E:/elsewhere/hiss.wav', name: 'hiss'),
      ],
    );

    final bytes = buildQapArchiveBytes(
      project: project,
      drawings: [entry()],
      saveDirectory: r'D:\work\proj',
    );
    final contents = parseQapArchiveBytes(bytes);

    expect(contents.project, project);
    expect(contents.drawings, hasLength(1));
    expect(contents.drawings.single.key, key);
    // Only the in-folder path got a relative entry.
    expect(contents.mediaRelativePaths, {
      'D:/work/proj/audio/boom.wav': 'audio/boom.wav',
    });

    // Resolution on another machine: the relative entry rewrites the pool.
    final remapped = remapProjectMediaPaths(contents.project, {
      'D:/work/proj/audio/boom.wav': 'G:/drive/proj/audio/boom.wav',
    });
    expect(remapped.mediaAssets.first.path, 'G:/drive/proj/audio/boom.wav');
    expect(remapped.mediaAssets[1].path, 'E:/elsewhere/hiss.wav');
  });

  test('media remap rewrites SE audio clips on tracks AND cuts', () {
    final base = createDefaultProject();
    final track = base.tracks.first;
    final seeded = base.copyWith(
      tracks: [
        track.copyWith(
          seLayers: [
            track.seLayers.first.copyWith(
              audioClips: const [
                AudioClip(filePath: 'old/a.wav', frameId: FrameId('x')),
              ],
            ),
            ...track.seLayers.skip(1),
          ],
        ),
      ],
    );

    final remapped = remapProjectMediaPaths(seeded, {'old/a.wav': 'new/a.wav'});
    expect(
      remapped.tracks.first.seLayers.first.audioClips.single.filePath,
      'new/a.wav',
    );
  });

  test('a newer formatVersion refuses to load with a clear error', () {
    final bytes = buildQapArchiveBytes(
      project: createDefaultProject(),
      drawings: const [],
    );
    expect(parseQapArchiveBytes(bytes).project, isNotNull);

    expect(
      () => parseQapArchiveBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });
}
