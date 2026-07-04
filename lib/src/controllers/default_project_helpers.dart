import '../models/cut_id.dart';
import '../models/layer_id.dart';
import '../models/project.dart';
import '../models/project_id.dart';
import '../models/track.dart';
import '../models/track_id.dart';
import 'default_cut_helpers.dart';

Project createDefaultProject({DateTime? createdAt}) {
  return Project(
    id: const ProjectId('default-project'),
    name: 'Untitled Project',
    createdAt: createdAt ?? DateTime.now().toUtc(),
    tracks: [createDefaultTrack()],
  );
}

Track createDefaultTrack({TrackId trackId = const TrackId('default-track'), String name = 'Track 1'}) {
  return Track(
    id: trackId,
    name: name,
    cuts: [
      createDefaultCut(
        cutId: const CutId('default-cut-1'),
        name: 'Cut 1',
        layerId: const LayerId('default-layer-1'),
      ),
    ],
  );
}
