import 'folder_id.dart';
import 'layer_blend_mode.dart';
import 'transform_track.dart';

/// A layer folder: a PURE ORGANIZATIONAL grouping over the cut's flat
/// layer stack (the flat list stays the single truth of render/timeline
/// order). No timesheet presence, no timesheet-enable button — "레이어를
/// 그냥 모아놓은 정도" (user direction), plus its own FX lanes so the
/// whole folder can be moved/faded as one (the A-cel instancing story:
/// link-duplicate the group, fold it into a folder, place it with the
/// folder's FX).
///
/// Structural invariants (kept by the commands, validated in tests):
/// - Members occupy a CONTIGUOUS run of the layer stack (like attach
///   groups — a collapsed folder moves as one block).
/// - Attach groups never split across a folder boundary.
/// - Nesting is allowed ([parentId]); cycles are not.
///
/// In a linked (겸용) cut, folder EXISTENCE/name/membership are shared
/// structure (mirrored by commands); [collapsed] and [isVisible] and the
/// FX lanes are per-use ("레인만 각자, 나머지는 하나" — the eye/static
/// opacity of LAYERS mirror, but the folder's display toggles stay local
/// so one use can park a folder without blinding the others... final
/// call rides with L2's mirror table).
class LayerFolder {
  LayerFolder({
    required this.id,
    required this.name,
    this.parentId,
    this.collapsed = false,
    this.isVisible = true,
    this.opacity = 1.0,
    this.blendMode = LayerBlendMode.normal,
    TransformTrack? transformTrack,
  }) : transformTrack = transformTrack ?? TransformTrack.empty();

  final FolderId id;
  final String name;

  /// The enclosing folder; null = top level. Nesting is allowed.
  final FolderId? parentId;

  /// Layer-list twirl state (persisted like CSP does).
  final bool collapsed;

  /// Folder eye: hides every member at composite time.
  final bool isVisible;

  /// Static folder opacity, applied to the folder's composed buffer
  /// (L3) — NOT per member, so overlapping members don't double-fade.
  final double opacity;

  /// R27 #29: the folder's composite blend against everything below it —
  /// the layer blend applied to the folder's COMPOSED buffer, so
  /// overlapping members blend once as a group instead of one by one.
  final LayerBlendMode blendMode;

  /// Folder FX lanes (position/scale/rotation/opacity over the cut's
  /// frame axis) — applied to the folder's composed buffer (L3).
  final TransformTrack transformTrack;

  LayerFolder copyWith({
    FolderId? id,
    String? name,
    Object? parentId = _sentinel,
    bool? collapsed,
    bool? isVisible,
    double? opacity,
    LayerBlendMode? blendMode,
    TransformTrack? transformTrack,
  }) {
    return LayerFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: identical(parentId, _sentinel)
          ? this.parentId
          : parentId as FolderId?,
      collapsed: collapsed ?? this.collapsed,
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      transformTrack: transformTrack ?? this.transformTrack,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    if (parentId != null) 'parentId': parentId!.toJson(),
    if (collapsed) 'collapsed': collapsed,
    if (!isVisible) 'isVisible': isVisible,
    if (opacity != 1.0) 'opacity': opacity,
    if (blendMode != LayerBlendMode.normal) 'blendMode': blendMode.toJson(),
    if (transformTrack.isNotEmpty) 'transform': transformTrack.toJson(),
  };

  factory LayerFolder.fromJson(Map<String, dynamic> json) {
    return LayerFolder(
      id: FolderId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      parentId: json['parentId'] == null
          ? null
          : FolderId.fromJson(json['parentId'] as Map<String, dynamic>),
      collapsed: json['collapsed'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: LayerBlendMode.fromJson(json['blendMode']),
      transformTrack: json['transform'] == null
          ? null
          : TransformTrack.fromJson(json['transform'] as Map<String, dynamic>),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerFolder &&
          other.id == id &&
          other.name == name &&
          other.parentId == parentId &&
          other.collapsed == collapsed &&
          other.isVisible == isVisible &&
          other.opacity == opacity &&
          other.blendMode == blendMode &&
          other.transformTrack == transformTrack;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parentId,
    collapsed,
    isVisible,
    opacity,
    blendMode,
    transformTrack,
  );

  @override
  String toString() =>
      'LayerFolder(id: $id, name: $name, parentId: $parentId, '
      'collapsed: $collapsed)';
}

/// Folder membership + ancestry helpers over a cut's folder table and its
/// layers' `folderId` tags.
extension LayerFolderTableQueries on List<LayerFolder> {
  LayerFolder? byId(FolderId? id) {
    if (id == null) {
      return null;
    }
    for (final folder in this) {
      if (folder.id == id) {
        return folder;
      }
    }
    return null;
  }

  /// [folderId]'s chain up to the top level, nearest first. Safe on
  /// malformed tables: stops if a parent is missing or a cycle appears.
  List<LayerFolder> ancestryOf(FolderId? folderId) {
    final chain = <LayerFolder>[];
    final seen = <FolderId>{};
    var current = byId(folderId);
    while (current != null && seen.add(current.id)) {
      chain.add(current);
      current = byId(current.parentId);
    }
    return chain;
  }

  /// Whether every member of the chain is visible (a hidden ancestor
  /// hides the whole subtree).
  bool subtreeVisible(FolderId? folderId) {
    for (final folder in ancestryOf(folderId)) {
      if (!folder.isVisible) {
        return false;
      }
    }
    return true;
  }

  /// Whether any ancestor is collapsed (the layer row hides in the list).
  bool subtreeCollapsed(FolderId? folderId) {
    for (final folder in ancestryOf(folderId)) {
      if (folder.collapsed) {
        return true;
      }
    }
    return false;
  }
}

/// Validates the folder-structure invariants over a cut's stack order:
/// every layer's folder exists, folder runs are CONTIGUOUS (a folder's
/// members — including nested subfolders' members — form one unbroken
/// run), and the parent chain is acyclic. Returns a human-readable
/// problem description, or null when the structure is sound.
String? folderStructureProblem({
  required List<LayerFolder> folders,
  required List<FolderId?> layerFolderIdsInStackOrder,
}) {
  for (final folder in folders) {
    final seen = <FolderId>{folder.id};
    var parent = folders.byId(folder.parentId);
    while (parent != null) {
      if (!seen.add(parent.id)) {
        return 'Folder ${folder.id} has a cyclic parent chain.';
      }
      parent = folders.byId(parent.parentId);
    }
    if (folder.parentId != null && folders.byId(folder.parentId) == null) {
      return 'Folder ${folder.id} has a missing parent ${folder.parentId}.';
    }
  }
  for (final folderId in layerFolderIdsInStackOrder) {
    if (folderId != null && folders.byId(folderId) == null) {
      return 'A layer references missing folder $folderId.';
    }
  }
  // Contiguity per folder: the set of stack indices whose ancestry
  // contains the folder must be one unbroken run.
  for (final folder in folders) {
    var runState = _RunState.before;
    for (final folderId in layerFolderIdsInStackOrder) {
      final inFolder = folders
          .ancestryOf(folderId)
          .any((ancestor) => ancestor.id == folder.id);
      switch (runState) {
        case _RunState.before:
          if (inFolder) {
            runState = _RunState.inside;
          }
        case _RunState.inside:
          if (!inFolder) {
            runState = _RunState.after;
          }
        case _RunState.after:
          if (inFolder) {
            return 'Folder ${folder.id} members are not contiguous in the '
                'layer stack.';
          }
      }
    }
  }
  return null;
}

enum _RunState { before, inside, after }
