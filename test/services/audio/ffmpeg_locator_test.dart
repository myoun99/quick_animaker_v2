import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/services/audio/ffmpeg_locator.dart';

void main() {
  test('windows probes the winget Links shim and Gyan package builds', () {
    const localAppData = r'C:\Users\u\AppData\Local';
    const links = '$localAppData\\Microsoft\\WinGet\\Links\\ffmpeg.exe';
    const packages = '$localAppData\\Microsoft\\WinGet\\Packages';
    const gyan = '$packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe';
    const build = '$gyan\\ffmpeg-8.0-full_build';

    final candidates = ffmpegExecutableCandidates(
      environment: const {'LOCALAPPDATA': localAppData},
      operatingSystem: 'windows',
      fileExists: (path) =>
          path == links || path == '$build\\bin\\ffmpeg.exe',
      listDirectory: (directory) => switch (directory) {
        packages => const [gyan, '$packages\\SomeOther.Tool'],
        gyan => const [build],
        _ => const [],
      },
    );

    expect(candidates, [
      'ffmpeg',
      links,
      '$build\\bin\\ffmpeg.exe',
    ]);
  });

  test('windows without any install still offers the PATH name', () {
    final candidates = ffmpegExecutableCandidates(
      environment: const {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'},
      operatingSystem: 'windows',
      fileExists: (_) => false,
      listDirectory: (_) => const [],
    );

    expect(candidates, ['ffmpeg']);
  });

  test('macos probes homebrew bins', () {
    final candidates = ffmpegExecutableCandidates(
      environment: const {},
      operatingSystem: 'macos',
      fileExists: (path) => path == '/opt/homebrew/bin/ffmpeg',
      listDirectory: (_) => const [],
    );

    expect(candidates, ['ffmpeg', '/opt/homebrew/bin/ffmpeg']);
  });

  test('linux keeps just the PATH name', () {
    final candidates = ffmpegExecutableCandidates(
      environment: const {},
      operatingSystem: 'linux',
      fileExists: (_) => true,
      listDirectory: (_) => const [],
    );

    expect(candidates, ['ffmpeg']);
  });
}
