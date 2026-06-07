import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/project.dart';
import '../models/track.dart';

CutId defaultActiveCutIdFor(Project project) {
  for (final track in project.tracks) {
    if (track.type != TrackType.video) {
      continue;
    }

    if (track.cuts.isNotEmpty) {
      return track.cuts.first.id;
    }
  }

  for (final track in project.tracks) {
    if (track.cuts.isNotEmpty) {
      return track.cuts.first.id;
    }
  }

  throw StateError('Project has no cuts.');
}

Cut? findCutById(Project project, CutId cutId) {
  for (final track in project.tracks) {
    for (final cut in track.cuts) {
      if (cut.id == cutId) {
        return cut;
      }
    }
  }

  return null;
}

Cut requireCutById(Project project, CutId cutId) {
  final cut = findCutById(project, cutId);
  if (cut == null) {
    throw StateError('Project does not contain cut ${cutId.value}.');
  }

  return cut;
}
