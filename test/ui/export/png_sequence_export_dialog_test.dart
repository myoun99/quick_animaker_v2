import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_cut_helpers.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/export/png_sequence_export_dialog.dart';

void main() {
  EditorSessionManager smallSession({int duration = 3}) {
    return EditorSessionManager(
      initialProject: Project(
        id: const ProjectId('project'),
        name: 'Project',
        cameraSize: const CanvasSize(width: 32, height: 18),
        tracks: [
          Track(
            id: const TrackId('track'),
            name: 'Track',
            cuts: [
              Cut(
                id: const CutId('cut'),
                name: 'Cut',
                duration: duration,
                canvasSize: const CanvasSize(width: 8, height: 8),
                layers: [
                  Layer(
                    id: const LayerId('layer'),
                    name: 'A',
                    frames: const [],
                    timeline: const {},
                  ),
                  createCameraLayer(cutId: const CutId('cut')),
                ],
              ),
            ],
          ),
        ],
        createdAt: DateTime.utc(2026),
      ),
    );
  }

  Future<PngSequenceExportDialogState> pumpDialog(
    WidgetTester tester,
    EditorSessionManager session, {
    ExportDirectoryPicker? exportDirectoryPicker,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PngSequenceExportDialog(
            session: session,
            exportDirectoryPicker: exportDirectoryPicker,
          ),
        ),
      ),
    );
    return tester.state<PngSequenceExportDialogState>(
      find.byType(PngSequenceExportDialog),
    );
  }

  testWidgets('summarizes the cut and camera output size', (tester) async {
    await pumpDialog(tester, smallSession());

    expect(
      find.text('Cut: 3 frames through the camera at 32×18.'),
      findsOneWidget,
    );
  });

  testWidgets('exports one PNG per frame into the picked directory', (
    tester,
  ) async {
    // Sync IO: real async IO futures never complete inside the widget-test
    // fake-async zone.
    final directory = Directory.systemTemp.createTempSync('png_export_test');
    addTearDown(() => directory.deleteSync(recursive: true));

    final state = await pumpDialog(
      tester,
      smallSession(),
      exportDirectoryPicker: () async => directory.path,
    );

    await tester.runAsync(state.export);
    await tester.pump();

    final files =
        directory
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    expect(files, ['frame_0001.png', 'frame_0002.png', 'frame_0003.png']);
    for (final file in directory.listSync().whereType<File>()) {
      expect(file.lengthSync(), greaterThan(0));
    }
    expect(find.text('Exported 3 frames.'), findsOneWidget);
  });

  testWidgets('cancelling the directory picker leaves no status', (
    tester,
  ) async {
    final state = await pumpDialog(
      tester,
      smallSession(),
      exportDirectoryPicker: () async => null,
    );

    await tester.runAsync(state.export);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('png-export-status')),
      findsNothing,
    );
  });
}
