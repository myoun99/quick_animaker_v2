import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('ProjectRepository', () {
    test('starts empty when no initial project is provided', () {
      final repository = ProjectRepository();

      expect(repository.currentProject, isNull);
      expect(repository.hasProject, isFalse);
      expect(repository.requireProject, throwsStateError);
    });

    test('holds and replaces the current project', () {
      final firstProject = _project(id: 'project-1', name: 'First');
      final secondProject = _project(id: 'project-2', name: 'Second');
      final repository = ProjectRepository(initialProject: firstProject);

      expect(repository.currentProject, firstProject);
      expect(repository.hasProject, isTrue);

      repository.replaceProject(secondProject);

      expect(repository.currentProject, secondProject);
      expect(repository.requireProject(), secondProject);
    });

    test('updates the current project with immutable copies', () {
      final originalProject = _project(id: 'project-1', name: 'Original');
      final repository = ProjectRepository(initialProject: originalProject);

      repository.updateProject((project) => project.copyWith(name: 'Updated'));

      expect(repository.requireProject().name, 'Updated');
      expect(originalProject.name, 'Original');
    });

    test('adds, replaces, and removes tracks through project copies', () {
      final originalProject = _project(id: 'project-1', name: 'Project');
      final repository = ProjectRepository(initialProject: originalProject);
      final track = _track(id: 'track-1', name: 'Video');
      final replacementTrack = _track(id: 'track-1', name: 'Renamed Video');

      repository.addTrack(track);

      expect(repository.requireProject().tracks, [track]);
      expect(originalProject.tracks, isEmpty);

      repository.replaceTrack(replacementTrack);

      expect(repository.requireProject().tracks, [replacementTrack]);

      repository.removeTrack(const TrackId('track-1'));

      expect(repository.requireProject().tracks, isEmpty);
    });

    test('throws when replacing or removing a missing track', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      expect(
        () => repository.replaceTrack(_track(id: 'missing', name: 'Missing')),
        throwsStateError,
      );
      expect(
        () => repository.removeTrack(const TrackId('missing')),
        throwsStateError,
      );
    });

    test('clears the current project', () {
      final repository = ProjectRepository(
        initialProject: _project(id: 'project-1', name: 'Project'),
      );

      repository.clearProject();

      expect(repository.currentProject, isNull);
      expect(repository.hasProject, isFalse);
    });
  });
}

Project _project({required String id, required String name}) {
  return Project(
    id: ProjectId(id),
    name: name,
    tracks: const [],
    createdAt: DateTime.utc(2026, 6, 2),
  );
}

Track _track({required String id, required String name}) {
  return Track(
    id: TrackId(id),
    name: name,
    cuts: const [],
  );
}
