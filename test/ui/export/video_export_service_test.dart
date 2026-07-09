import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/export/video_export_service.dart';

import 'fake_ffmpeg_process.dart';

void main() {
  // Frames render as null throughout: these tests cover the process
  // plumbing; real image piping is covered by the export dialog tests.
  Future<ui.Image?> noImage(int index) => Future<ui.Image?>.value();

  test('passes fps and the output path to ffmpeg', () async {
    final process = FakeFfmpegProcess();
    String? capturedExecutable;
    List<String>? capturedArguments;
    final service = VideoExportService(
      processStarter: (executable, arguments) async {
        capturedExecutable = executable;
        capturedArguments = arguments;
        return process;
      },
    );

    final summary = await service.exportVideo(
      count: 3,
      renderImage: noImage,
      outputFilePath: 'C:/out/take.mp4',
      fps: 12,
    );

    expect(capturedExecutable, 'ffmpeg');
    final arguments = capturedArguments!;
    final framerateIndex = arguments.indexOf('-framerate');
    expect(framerateIndex, isNot(-1));
    expect(arguments[framerateIndex + 1], '12');
    expect(arguments.last, 'C:/out/take.mp4');
    expect(summary, (written: 0, processed: 3));
  });

  group('buildFfmpegArguments', () {
    test('without audio the command is the original video-only shape', () {
      final args = VideoExportService.buildFfmpegArguments(
        fps: 24,
        outputFilePath: 'out.mp4',
      );

      expect(args, containsAllInOrder(['-f', 'image2pipe', '-i', '-']));
      expect(args, contains('-vf'));
      expect(args, isNot(contains('-filter_complex')));
      expect(args, isNot(contains('-shortest')));
      expect(args.last, 'out.mp4');
    });

    test('one clip: seek/trim at the input, delay in the graph, aac out', () {
      final args = VideoExportService.buildFfmpegArguments(
        fps: 24,
        outputFilePath: 'out.mp4',
        audioClips: const [
          ExportAudioClip(
            filePath: 'voice.wav',
            seekSeconds: 0.5,
            delaySeconds: 1.25,
            durationSeconds: 2,
          ),
        ],
      );

      expect(
        args,
        containsAllInOrder(['-ss', '0.500', '-t', '2.000', '-i', 'voice.wav']),
      );
      final filter = args[args.indexOf('-filter_complex') + 1];
      // The pad filter moves into the graph (-vf cannot coexist with it).
      expect(args, isNot(contains('-vf')));
      expect(filter, contains('[0:v]pad='));
      expect(filter, contains('[1:a]adelay=1250:all=1[a0]'));
      expect(filter, isNot(contains('amix')));
      expect(args, containsAllInOrder(['-map', '[vout]', '-map', '[a0]']));
      expect(args, containsAllInOrder(['-c:a', 'aac', '-shortest']));
    });

    test('multiple clips mix without renormalizing volumes', () {
      final args = VideoExportService.buildFfmpegArguments(
        fps: 24,
        outputFilePath: 'out.mp4',
        audioClips: const [
          ExportAudioClip(filePath: 'a.wav', durationSeconds: 1),
          ExportAudioClip(
            filePath: 'b.wav',
            delaySeconds: 0.25,
            durationSeconds: 0.75,
          ),
        ],
      );

      // No seek for clips starting inside the range.
      expect(args, isNot(contains('-ss')));
      final filter = args[args.indexOf('-filter_complex') + 1];
      expect(filter, contains('[1:a]adelay=0:all=1[a0]'));
      expect(filter, contains('[2:a]adelay=250:all=1[a1]'));
      expect(filter, contains('[a0][a1]amix=inputs=2:normalize=0[aout]'));
      expect(args, containsAllInOrder(['-map', '[vout]', '-map', '[aout]']));
    });

    test('gain and fades chain volume/afade before adelay, in clip time', () {
      final args = VideoExportService.buildFfmpegArguments(
        fps: 24,
        outputFilePath: 'out.mp4',
        audioClips: const [
          ExportAudioClip(
            filePath: 'voice.wav',
            delaySeconds: 1,
            durationSeconds: 3,
            gain: 1.5,
            fadeInSeconds: 0.5,
            fadeOutSeconds: 1,
          ),
        ],
      );

      final filter = args[args.indexOf('-filter_complex') + 1];
      expect(
        filter,
        contains(
          '[1:a]volume=1.500,afade=t=in:st=0:d=0.500,'
          'afade=t=out:st=2.000:d=1.000,adelay=1000:all=1[a0]',
        ),
      );
    });

    test('a default envelope emits the exact legacy adelay-only chain', () {
      final args = VideoExportService.buildFfmpegArguments(
        fps: 24,
        outputFilePath: 'out.mp4',
        audioClips: const [
          ExportAudioClip(
            filePath: 'voice.wav',
            delaySeconds: 0.25,
            durationSeconds: 2,
          ),
        ],
      );

      final filter = args[args.indexOf('-filter_complex') + 1];
      expect(filter, contains('[1:a]adelay=250:all=1[a0]'));
      expect(filter, isNot(contains('volume=')));
      expect(filter, isNot(contains('afade')));
    });
  });

  test('missing ffmpeg surfaces an install hint', () async {
    final service = VideoExportService(
      processStarter: (executable, arguments) =>
          throw ProcessException(executable, arguments),
    );

    await expectLater(
      service.exportVideo(
        count: 1,
        renderImage: noImage,
        outputFilePath: 'out.mp4',
        fps: 24,
      ),
      throwsA(
        isA<VideoExportException>().having(
          (error) => error.message,
          'message',
          contains('ffmpeg not found'),
        ),
      ),
    );
  });

  test('a non-zero ffmpeg exit surfaces the stderr tail', () async {
    final process = FakeFfmpegProcess(
      exitCodeValue: 1,
      stderrText: 'Unknown encoder libx264\n',
    );
    final service = VideoExportService(
      processStarter: (executable, arguments) async => process,
    );

    await expectLater(
      service.exportVideo(
        count: 1,
        renderImage: noImage,
        outputFilePath: 'out.mp4',
        fps: 24,
      ),
      throwsA(
        isA<VideoExportException>().having(
          (error) => error.message,
          'message',
          contains('Unknown encoder libx264'),
        ),
      ),
    );
  });

  test('cancelling before any frame kills ffmpeg without an error', () async {
    final process = FakeFfmpegProcess(exitCodeValue: 1);
    final service = VideoExportService(
      processStarter: (executable, arguments) async => process,
    );

    final summary = await service.exportVideo(
      count: 5,
      renderImage: noImage,
      outputFilePath: 'out.mp4',
      fps: 24,
      isCancelled: () => true,
    );

    expect(process.killed, isTrue);
    expect(summary, (written: 0, processed: 0));
  });

  test('cancelling mid-run reports the processed frame count', () async {
    final process = FakeFfmpegProcess();
    final service = VideoExportService(
      processStarter: (executable, arguments) async => process,
    );
    var rendered = 0;

    final summary = await service.exportVideo(
      count: 5,
      renderImage: (index) {
        rendered += 1;
        return noImage(index);
      },
      outputFilePath: 'out.mp4',
      fps: 24,
      isCancelled: () => rendered >= 2,
    );

    // No frame bytes ever reached ffmpeg (null renders), so the cancel
    // takes the kill path rather than finalizing a partial video.
    expect(summary.processed, 2);
    expect(process.killed, isTrue);
  });
}
