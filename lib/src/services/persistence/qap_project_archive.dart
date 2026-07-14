/// The .qap container (P3): ONE self-contained ZIP — `project.json`
/// (timeline + metadata, with a formatVersion) and `cels/<n>.bin` (baked
/// tile rasters; deflate does the rest). Drawings live INSIDE the file
/// (user direction: no scattered sidecars); media stays EXTERNAL
/// Premiere-style, with save-directory-relative paths recorded so a Drive
/// folder opened on another machine relinks by itself.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../models/audio_clip.dart';
import '../../models/project.dart';
import 'brush_drawing_binary_codec.dart';

/// v2 (R19 bake-only): cels persist as BAKED tile rasters
/// (`cels/<n>.bin`) — the truth. The v1 command-drawing reader is DELETED
/// (R20-E3): no production v1 file was ever written (user-confirmed), so
/// `drawings/`/`tips.bin` entries are simply ignored.
const int qapFormatVersion = 2;

/// A parsed .qap archive: the project (media paths NOT yet resolved — see
/// [remapProjectMediaPaths]), its baked cels and the saved relative-path
/// manifest ({absolute path at save time: save-dir-relative path}).
class QapArchiveContents {
  const QapArchiveContents({
    required this.project,
    required this.cels,
    required this.mediaRelativePaths,
  });

  final Project project;
  final List<QapCelEntry> cels;
  final Map<String, String> mediaRelativePaths;
}

/// Builds the .qap bytes. [saveDirectory] (the file's parent, normalized
/// with forward slashes) keys the relative-path manifest: media living
/// under it is recorded relative, everything else stays absolute-only.
Uint8List buildQapArchiveBytes({
  required Project project,
  required List<QapCelEntry> cels,
  String? saveDirectory,
}) {
  final mediaRelativePaths = <String, String>{};
  if (saveDirectory != null) {
    for (final path in _projectMediaPaths(project)) {
      final relative = _relativeTo(path, saveDirectory);
      if (relative != null) {
        mediaRelativePaths[path] = relative;
      }
    }
  }

  final archive = Archive()
    ..add(
      ArchiveFile.string(
        'project.json',
        jsonEncode({
          'formatVersion': qapFormatVersion,
          'project': project.toJson(),
          if (mediaRelativePaths.isNotEmpty) 'mediaPaths': mediaRelativePaths,
        }),
      ),
    );
  // v2 (R19 bake-only): baked cel rasters ARE the drawing truth; no
  // drawings/tips entries are written anymore.
  for (var i = 0; i < cels.length; i += 1) {
    archive.add(ArchiveFile.bytes('cels/$i.bin', encodeCelEntry(cels[i])));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Parses .qap bytes; throws [FormatException] on a newer format or a
/// missing project entry.
QapArchiveContents parseQapArchiveBytes(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  final projectEntry = archive.find('project.json');
  if (projectEntry == null) {
    throw const FormatException('Not a QuickAnimaker project (.qap).');
  }
  final decoded =
      jsonDecode(utf8.decode(projectEntry.readBytes()!))
          as Map<String, dynamic>;
  if ((decoded['formatVersion'] as int? ?? 0) > qapFormatVersion) {
    throw const FormatException(
      'This project was saved by a newer QuickAnimaker.',
    );
  }
  final project = Project.fromJson(decoded['project'] as Map<String, dynamic>);
  final mediaPathsJson = decoded['mediaPaths'];
  final mediaRelativePaths = <String, String>{
    if (mediaPathsJson is Map)
      for (final entry in mediaPathsJson.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
  };

  // v2 truth: baked cel rasters. (v1 drawings/tips entries are ignored —
  // reader deleted, no production v1 file exists.)
  final cels = <QapCelEntry>[
    for (final file in archive.files)
      if (file.isFile && file.name.startsWith('cels/'))
        decodeCelEntry(file.readBytes()!),
  ];

  return QapArchiveContents(
    project: project,
    cels: cels,
    mediaRelativePaths: mediaRelativePaths,
  );
}

/// Rewrites the project's media references ({old path: new path}) — the
/// pool entries AND every SE audio clip (cut- and track-owned) so links
/// stay consistent. Unmapped paths pass through.
Project remapProjectMediaPaths(Project project, Map<String, String> oldToNew) {
  if (oldToNew.isEmpty) {
    return project;
  }
  String remap(String path) => oldToNew[path] ?? path;
  List<AudioClip> remapClips(List<AudioClip> clips) => [
    for (final clip in clips) clip.copyWith(filePath: remap(clip.filePath)),
  ];

  return project.copyWith(
    mediaAssets: [
      for (final asset in project.mediaAssets)
        asset.copyWith(path: remap(asset.path)),
    ],
    tracks: [
      for (final track in project.tracks)
        track.copyWith(
          seLayers: [
            for (final layer in track.seLayers)
              layer.audioClips.isEmpty
                  ? layer
                  : layer.copyWith(audioClips: remapClips(layer.audioClips)),
          ],
          cuts: [
            for (final cut in track.cuts)
              cut.copyWith(
                layers: [
                  for (final layer in cut.layers)
                    layer.audioClips.isEmpty
                        ? layer
                        : layer.copyWith(
                            audioClips: remapClips(layer.audioClips),
                          ),
                ],
              ),
          ],
        ),
    ],
  );
}

/// The distinct media file paths a project references (pool + clips).
Set<String> _projectMediaPaths(Project project) {
  final paths = <String>{for (final asset in project.mediaAssets) asset.path};
  for (final track in project.tracks) {
    for (final layer in track.seLayers) {
      for (final clip in layer.audioClips) {
        paths.add(clip.filePath);
      }
    }
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        for (final clip in layer.audioClips) {
          paths.add(clip.filePath);
        }
      }
    }
  }
  return paths;
}

/// [path] relative to [directory] when it lives underneath it (separator-
/// and case-insensitively on the drive prefix); null otherwise. Forward
/// slashes throughout so the manifest is portable across platforms.
String? _relativeTo(String path, String directory) {
  final normalizedPath = path.replaceAll('\\', '/');
  var normalizedDirectory = directory.replaceAll('\\', '/');
  if (!normalizedDirectory.endsWith('/')) {
    normalizedDirectory = '$normalizedDirectory/';
  }
  if (normalizedPath.toLowerCase().startsWith(
    normalizedDirectory.toLowerCase(),
  )) {
    return normalizedPath.substring(normalizedDirectory.length);
  }
  return null;
}
