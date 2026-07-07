import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_cut_helpers.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/editor_session_manager.dart';
import 'package:quick_animaker_v2/src/ui/export/export_dialog.dart';
import 'package:quick_animaker_v2/src/ui/export/export_plan.dart';
import 'package:quick_animaker_v2/src/ui/export/video_export_service.dart';

import 'fake_ffmpeg_process.dart';

void main() {
  Frame frame(String id) =>
      Frame(id: FrameId(id), duration: 1, strokes: const []);

  /// Two cuts (2 + 3 frames) on the active track, a third cut on another
  /// track that exports must never touch. The first cut's drawing layer
  /// carries two authored cels (no brush artwork — surfaces stay empty).
  EditorSessionManager exportSession() {
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
                duration: 2,
                canvasSize: const CanvasSize(width: 8, height: 8),
                layers: [
                  Layer(
                    id: const LayerId('layer'),
                    name: 'A',
                    frames: [frame('f1'), frame('f2')],
                  ),
                  createCameraLayer(cutId: const CutId('cut')),
                ],
              ),
              Cut(
                id: const CutId('cut-b'),
                name: 'Cut B',
                duration: 3,
                canvasSize: const CanvasSize(width: 8, height: 8),
                layers: [
                  Layer(
                    id: const LayerId('layer-b'),
                    name: 'A',
                    frames: const [],
                  ),
                  createCameraLayer(cutId: const CutId('cut-b')),
                ],
              ),
            ],
          ),
          Track(
            id: const TrackId('other-track'),
            name: 'Other',
            cuts: [
              Cut(
                id: const CutId('cut-c'),
                name: 'Cut C',
                duration: 10,
                canvasSize: const CanvasSize(width: 8, height: 8),
                layers: [createCameraLayer(cutId: const CutId('cut-c'))],
              ),
            ],
          ),
        ],
        createdAt: DateTime.utc(2026),
      ),
    );
  }

  Future<ExportDialogState> pumpDialog(
    WidgetTester tester,
    EditorSessionManager session, {
    ExportDirectoryPicker? exportDirectoryPicker,
    ExportVideoPathPicker? exportVideoPathPicker,
    ExportXdtsPathPicker? exportXdtsPathPicker,
    VideoExportService videoExportService = const VideoExportService(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportDialog(
            session: session,
            exportDirectoryPicker: exportDirectoryPicker,
            exportVideoPathPicker: exportVideoPathPicker,
            exportXdtsPathPicker: exportXdtsPathPicker,
            videoExportService: videoExportService,
          ),
        ),
      ),
    );
    return tester.state<ExportDialogState>(find.byType(ExportDialog));
  }

  Future<void> selectMp4Format(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('export-format-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP4 video').last);
    await tester.pumpAndSettle();
  }

  Future<void> selectXdtsFormat(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('export-format-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('XDTS timesheet').last);
    await tester.pumpAndSettle();
  }

  Directory tempDirectory(String prefix) {
    // Sync IO: real async IO futures never complete inside the widget-test
    // fake-async zone.
    final directory = Directory.systemTemp.createTempSync(prefix);
    addTearDown(() => directory.deleteSync(recursive: true));
    return directory;
  }

  List<String> fileNames(Directory directory) =>
      directory
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();

  /// Width/height straight from the PNG IHDR chunk (big-endian at 16/20).
  (int, int) pngDimensions(File file) {
    final bytes = file.readAsBytesSync();
    int be32(int offset) =>
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    return (be32(16), be32(20));
  }

  testWidgets('summarizes the default camera export of the active cut', (
    tester,
  ) async {
    await pumpDialog(tester, exportSession());

    expect(find.text('2 frames at 32×18 through the camera.'), findsOneWidget);
  });

  testWidgets('exports the active cut through the camera', (tester) async {
    final directory = tempDirectory('export_dialog_camera');
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportDirectoryPicker: () async => directory.path,
    );

    await tester.runAsync(state.export);
    await tester.pump();

    expect(fileNames(directory), ['frame_0001.png', 'frame_0002.png']);
    for (final file in directory.listSync().whereType<File>()) {
      expect(pngDimensions(file), (32, 18));
    }
    expect(find.text('Exported 2 frames.'), findsOneWidget);
  });

  testWidgets('canvas size mode exports raw canvas pixels', (tester) async {
    final directory = tempDirectory('export_dialog_canvas');
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportDirectoryPicker: () async => directory.path,
    );

    await tester.tap(find.byKey(const ValueKey<String>('export-size-canvas')));
    await tester.pump();
    expect(find.text('2 frames at 8×8 (raw canvas).'), findsOneWidget);

    await tester.runAsync(state.export);
    await tester.pump();

    expect(fileNames(directory), ['frame_0001.png', 'frame_0002.png']);
    for (final file in directory.listSync().whereType<File>()) {
      expect(pngDimensions(file), (8, 8));
    }
  });

  testWidgets('all cuts exports every cut of the active track in order', (
    tester,
  ) async {
    final directory = tempDirectory('export_dialog_all');
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportDirectoryPicker: () async => directory.path,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('export-range-all-cuts')),
    );
    await tester.pump();
    expect(find.text('5 frames at 32×18 through the camera.'), findsOneWidget);

    await tester.runAsync(state.export);
    await tester.pump();

    expect(fileNames(directory), [
      'frame_0001.png',
      'frame_0002.png',
      'frame_0003.png',
      'frame_0004.png',
      'frame_0005.png',
    ]);
    expect(find.text('Exported 5 frames.'), findsOneWidget);
  });

  testWidgets('frame range exports the chosen 1-based inclusive range', (
    tester,
  ) async {
    final directory = tempDirectory('export_dialog_range');
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportDirectoryPicker: () async => directory.path,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('export-range-frame-range')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('export-range-start-field')),
      '2',
    );
    await tester.pump();

    await tester.runAsync(state.export);
    await tester.pump();

    expect(fileNames(directory), ['frame_0001.png']);
    expect(find.text('Exported 1 frame.'), findsOneWidget);
  });

  testWidgets('an invalid frame range disables export and shows the valid '
      'range', (tester) async {
    await pumpDialog(tester, exportSession());

    await tester.tap(
      find.byKey(const ValueKey<String>('export-range-frame-range')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('export-range-start-field')),
      '0',
    );
    await tester.pump();

    expect(find.text('Enter a valid frame range (1–2).'), findsOneWidget);
    final runButton = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('export-run-button')),
    );
    expect(runButton.onPressed, isNull);
  });

  testWidgets('instance export lists cels and skips the empty ones', (
    tester,
  ) async {
    final directory = tempDirectory('export_dialog_cels');
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportDirectoryPicker: () async => directory.path,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('export-instance-toggle')),
    );
    await tester.pump();
    expect(
      find.text('2 cels as transparent PNGs, no compositing.'),
      findsOneWidget,
    );
    expect(find.text('Example: A1.png'), findsOneWidget);

    await tester.runAsync(state.export);
    await tester.pump();

    // No brush artwork in the test store, so both cels skip their files.
    expect(fileNames(directory), isEmpty);
    expect(find.text('Exported 0 cels (2 empty skipped).'), findsOneWidget);
  });

  testWidgets('cel options rebuild the example name and the opaque summary', (
    tester,
  ) async {
    await pumpDialog(tester, exportSession());

    // The dialog body scrolls, so bring each control on-screen first.
    Future<void> tapVisible(String key) async {
      final finder = find.byKey(ValueKey<String>(key));
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
    }

    Future<void> typeVisible(String key, String text) async {
      final finder = find.byKey(ValueKey<String>(key));
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.enterText(finder, text);
      await tester.pump();
    }

    await tapVisible('export-instance-toggle');

    await typeVisible('export-cel-digits-field', '4');
    expect(find.text('Example: A0001.png'), findsOneWidget);

    await tapVisible('export-cel-include-cut');
    expect(find.text('Example: Cut_A0001.png'), findsOneWidget);

    await tapVisible('export-cel-include-layer');
    expect(find.text('Example: Cut_0001.png'), findsOneWidget);

    await typeVisible('export-cel-suffix-field', '_fix');
    expect(find.text('Example: Cut_0001_fix.png'), findsOneWidget);

    await tapVisible('export-cel-layer-folder');
    expect(find.text('Example: A/Cut_0001_fix.png'), findsOneWidget);

    await tapVisible('export-cel-transparent-toggle');
    expect(
      find.text('2 cels as opaque white PNGs, no compositing.'),
      findsOneWidget,
    );
    expect(find.text('Opaque background (white paper)'), findsOneWidget);
  });

  testWidgets('MP4 export pipes rendered frames into ffmpeg at project fps', (
    tester,
  ) async {
    final process = FakeFfmpegProcess();
    List<String>? capturedArguments;
    final state = await pumpDialog(
      tester,
      exportSession(),
      // Deliberately without the .mp4 extension: the dialog appends it.
      exportVideoPathPicker: (suggestedName) async {
        expect(suggestedName, 'Project.mp4');
        return 'C:/out/take';
      },
      videoExportService: VideoExportService(
        processStarter: (executable, arguments) async {
          capturedArguments = arguments;
          return process;
        },
      ),
    );

    await selectMp4Format(tester);
    expect(
      find.text('Encoded with FFmpeg — it must be installed and on PATH.'),
      findsOneWidget,
    );

    await tester.runAsync(state.export);
    await tester.pump();

    final arguments = capturedArguments!;
    expect(arguments.last, 'C:/out/take.mp4');
    final framerateIndex = arguments.indexOf('-framerate');
    expect(arguments[framerateIndex + 1], '24');
    expect(process.receivedPngCount, 2);
    expect(find.text('Exported video (2 frames).'), findsOneWidget);
  });

  testWidgets('video export with mixed canvas sizes is blocked', (
    tester,
  ) async {
    final session = EditorSessionManager(
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
                duration: 2,
                canvasSize: const CanvasSize(width: 8, height: 8),
                layers: [createCameraLayer(cutId: const CutId('cut'))],
              ),
              Cut(
                id: const CutId('cut-b'),
                name: 'Cut B',
                duration: 2,
                canvasSize: const CanvasSize(width: 16, height: 16),
                layers: [createCameraLayer(cutId: const CutId('cut-b'))],
              ),
            ],
          ),
        ],
        createdAt: DateTime.utc(2026),
      ),
    );
    await pumpDialog(tester, session);

    await tester.tap(
      find.byKey(const ValueKey<String>('export-range-all-cuts')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('export-size-canvas')));
    await tester.pump();
    await selectMp4Format(tester);

    expect(find.textContaining('Video needs one picture size'), findsOneWidget);
    final runButton = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('export-run-button')),
    );
    expect(runButton.onPressed, isNull);

    // The camera size is constant, so switching back re-enables export.
    await tester.tap(find.byKey(const ValueKey<String>('export-size-camera')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey<String>('export-run-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('instance export forces the PNG sequence format', (tester) async {
    await pumpDialog(tester, exportSession());
    await selectMp4Format(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('export-instance-toggle')),
    );
    await tester.pump();

    final dropdown = tester.widget<DropdownButton<ExportFormat>>(
      find.byKey(const ValueKey<String>('export-format-dropdown')),
    );
    expect(dropdown.value, ExportFormat.pngSequence);
    expect(dropdown.onChanged, isNull);
  });

  testWidgets('XDTS export writes the active cut sheet through the save '
      'picker', (tester) async {
    final directory = tempDirectory('export_dialog_xdts');
    final path = '${directory.path}${Platform.pathSeparator}sheet.xdts';
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportXdtsPathPicker: (suggestedName) async {
        expect(suggestedName, 'CUT1.xdts');
        return path;
      },
    );

    await selectXdtsFormat(tester);
    expect(
      find.text('1 XDTS sheet (cels + serifu + camerawork columns).'),
      findsOneWidget,
    );
    // Size/frame-range controls are moot for sheet data.
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey<String>('export-size-camera')),
          )
          .onSelected,
      isNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey<String>('export-range-frame-range')),
          )
          .onSelected,
      isNull,
    );

    await tester.runAsync(state.export);
    await tester.pump();

    final content = File(path).readAsStringSync();
    expect(content, startsWith('exchangeDigitalTimeSheet Save Data\n'));
    expect(content, contains('"cut": "1"'));
    expect(content, contains('"version": 5'));
    expect(find.text('Exported 1 XDTS sheet.'), findsOneWidget);
  });

  testWidgets('XDTS all-cuts export writes one sheet per cut into the '
      'directory', (tester) async {
    final directory = tempDirectory('export_dialog_xdts_all');
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportDirectoryPicker: () async => directory.path,
    );

    await selectXdtsFormat(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('export-range-all-cuts')),
    );
    await tester.pump();

    await tester.runAsync(state.export);
    await tester.pump();

    expect(fileNames(directory), ['CUT1.xdts', 'CUT2.xdts']);
    expect(find.text('Exported 2 XDTS sheets.'), findsOneWidget);
  });

  testWidgets('cancelling the video path picker leaves no status', (
    tester,
  ) async {
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportVideoPathPicker: (_) async => null,
    );

    await selectMp4Format(tester);
    await tester.runAsync(state.export);
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('export-status')), findsNothing);
  });

  testWidgets('cancelling the directory picker leaves no status', (
    tester,
  ) async {
    final state = await pumpDialog(
      tester,
      exportSession(),
      exportDirectoryPicker: () async => null,
    );

    await tester.runAsync(state.export);
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('export-status')), findsNothing);
  });
}
