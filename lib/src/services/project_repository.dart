import '../models/project.dart';
import '../models/track.dart';
import '../models/track_id.dart';

class ProjectRepository {
  ProjectRepository({Project? initialProject}) : _currentProject = initialProject;

  Project? _currentProject;

  Project? get currentProject => _currentProject;

  bool get hasProject => _currentProject != null;

  Project requireProject() {
    final project = _currentProject;
    if (project == null) {
      throw StateError('No project is loaded.');
    }
    return project;
  }

  void replaceProject(Project project) {
    _currentProject = project;
  }

  void clearProject() {
    _currentProject = null;
  }

  void updateProject(Project Function(Project project) update) {
    _currentProject = update(requireProject());
  }

  void addTrack(Track track) {
    updateProject((project) {
      return project.copyWith(tracks: [...project.tracks, track]);
    });
  }

  void replaceTrack(Track track) {
    updateProject((project) {
      final index = project.tracks.indexWhere(
        (existingTrack) => existingTrack.id == track.id,
      );
      if (index == -1) {
        throw StateError('Track not found: ${track.id}');
      }

      final tracks = [...project.tracks];
      tracks[index] = track;
      return project.copyWith(tracks: tracks);
    });
  }

  void removeTrack(TrackId trackId) {
    updateProject((project) {
      final tracks = project.tracks
          .where((track) => track.id != trackId)
          .toList(growable: false);
      if (tracks.length == project.tracks.length) {
        throw StateError('Track not found: $trackId');
      }
      return project.copyWith(tracks: tracks);
    });
  }
}
