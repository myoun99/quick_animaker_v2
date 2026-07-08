import 'dart:io';

/// Candidate paths for the external `ffmpeg` executable, most likely first.
///
/// A GUI app inherits PATH from whoever launched it. On Windows a winget
/// install (`Gyan.FFmpeg`) only appends its Links directory to the USER
/// PATH — processes started before the next sign-in never see it, so the
/// bare `ffmpeg` lookup fails even though the tool is installed. On macOS
/// Finder-launched apps miss Homebrew's bin directories entirely. After the
/// plain PATH name this probes those well-known install locations directly;
/// callers try each candidate until one spawns.
List<String> ffmpegExecutableCandidates({
  Map<String, String>? environment,
  String? operatingSystem,
  bool Function(String path)? fileExists,
  List<String> Function(String directory)? listDirectory,
}) {
  final env = environment ?? Platform.environment;
  final os = operatingSystem ?? Platform.operatingSystem;
  final exists = fileExists ?? _fileExists;
  final list = listDirectory ?? _listDirectory;

  final candidates = <String>['ffmpeg'];
  if (os == 'windows') {
    final localAppData = env['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      final links = '$localAppData\\Microsoft\\WinGet\\Links\\ffmpeg.exe';
      if (exists(links)) {
        candidates.add(links);
      }
      // Portable winget packages keep the real exe at
      // Packages\Gyan.FFmpeg_<source>\ffmpeg-<version>_build\bin\ffmpeg.exe;
      // probe it in case the Links shim is missing too.
      final packagesRoot = '$localAppData\\Microsoft\\WinGet\\Packages';
      for (final package in list(packagesRoot)) {
        if (!_baseName(package).startsWith('Gyan.FFmpeg')) {
          continue;
        }
        for (final build in list(package)) {
          final exe = '$build\\bin\\ffmpeg.exe';
          if (exists(exe)) {
            candidates.add(exe);
          }
        }
      }
    }
  } else if (os == 'macos') {
    for (final path in const [
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
    ]) {
      if (exists(path)) {
        candidates.add(path);
      }
    }
  }
  return candidates;
}

bool _fileExists(String path) {
  try {
    return File(path).existsSync();
  } on FileSystemException {
    return false;
  }
}

List<String> _listDirectory(String directory) {
  try {
    return Directory(
      directory,
    ).listSync(followLinks: false).map((entity) => entity.path).toList();
  } on FileSystemException {
    return const [];
  }
}

String _baseName(String path) {
  final cut = path.lastIndexOf('\\') > path.lastIndexOf('/')
      ? path.lastIndexOf('\\')
      : path.lastIndexOf('/');
  return cut < 0 ? path : path.substring(cut + 1);
}
