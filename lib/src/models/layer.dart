import 'dart:collection';

import '../core/collection_equality.dart';
import '../core/copy_with_sentinel.dart';
import 'attached_mode.dart';
import 'attached_placement.dart';
import 'audio_clip.dart';
import 'folder_id.dart';
import 'camera_instruction.dart';
import 'frame.dart';
import 'frame_id.dart';
import 'layer_id.dart';
import 'layer_kind.dart';
import 'layer_mark.dart';
import 'timeline_coverage.dart';
import 'timeline_exposure.dart';
import 'timeline_repeat.dart';
import 'transform_track.dart';

/// A cel layer. Its single [timeline] map records everything authored on
/// the frame axis: drawing block starts (frame + explicit hold length),
/// each carrying its own inbetween-dot offsets
/// ([TimelineExposure.breakdownOffsets]). Emptiness has no entry —
/// uncovered cells are the timesheet "X" cells. There is no separate marks
/// map, no blank entry type, and no standalone mark entry (legacy files
/// carrying any of those are migrated in [Layer.fromJson]).
class Layer {
  Layer({
    required this.id,
    required this.name,
    required List<Frame> frames,
    Map<int, TimelineExposure>? timeline,
    Map<int, InstructionEvent>? instructions,
    List<AudioClip> audioClips = const [],
    this.isVisible = true,
    this.muted = false,
    this.opacity = 1.0,
    this.kind = LayerKind.animation,
    this.onTimesheet = true,
    this.mark = LayerMark.none,
    this.isFillReference = false,
    TransformTrack? transformTrack,
    this.attachedToLayerId,
    this.attachedPlacement = AttachedPlacement.above,
    this.attachedMode = AttachedMode.synced,
    Map<FrameId, FrameId> baseFrameLinks = const {},
    List<TimelineRunBehavior> runBehaviors = const [],
    this.folderId,
  }) : frames = List.unmodifiable(frames),
       timeline = _immutableTimeline(timeline ?? _deriveTimeline(frames)),
       instructions = immutableInstructionMap(instructions ?? const {}),
       audioClips = List.unmodifiable(audioClips),
       transformTrack = transformTrack ?? TransformTrack.empty(),
       baseFrameLinks = Map.unmodifiable(baseFrameLinks),
       runBehaviors = List.unmodifiable(runBehaviors);

  final LayerId id;
  final String name;
  final List<Frame> frames;
  final SplayTreeMap<int, TimelineExposure> timeline;

  /// Camera-work instruction spans (instruction rows only; empty elsewhere).
  /// Keyed by start frame; see [InstructionEvent].
  final SplayTreeMap<int, InstructionEvent> instructions;

  /// Sound files placed on this SE layer (empty on other kinds).
  final List<AudioClip> audioClips;
  final bool isVisible;

  /// Whether this layer's sounds are silenced (SE rows' speaker button —
  /// the audio counterpart of [isVisible]): playback and export skip the
  /// clips of muted layers, the waveforms keep displaying.
  final bool muted;
  final double opacity;
  final LayerKind kind;

  /// Whether this layer's exposures are recorded on the timesheet output
  /// (preview/export). Only meaningful for cel layers — the camera track has
  /// its own sheet column regardless.
  final bool onTimesheet;

  /// Organizational color label; see [LayerMark].
  final LayerMark mark;

  /// The enclosing folder in the cut's folder table (L1); null = top
  /// level. Pure organization — render/timeline order stays the cut's
  /// flat layer list. Attach groups share one folder (never split across
  /// a folder boundary; the commands keep the invariant).
  final FolderId? folderId;

  /// Reference layer for the FILL tool (R20-C2, the CSP lighthouse):
  /// when any visible layer of the cut carries this flag, fills read
  /// ONLY the flagged layers as their source picture — paint on a color
  /// layer never blocks or leaks a fill traced against the line art.
  /// Display/export composite untouched.
  final bool isFillReference;

  /// The layer's keyframed transform (the AE Transform group), applied at
  /// COMPOSITE time — playback, export, thumbnails and the editing canvas's
  /// layer stack — never baked into the artwork. Empty = identity (the
  /// untouched default for every layer).
  final TransformTrack transformTrack;

  /// Non-null makes this an ATTACH LAYER riding the named base layer (W5):
  /// it shares the base's exposure timing and FX (transform + opacity
  /// lanes) while keeping its own cels, eye, static opacity and mark. Its
  /// own [timeline] stays empty — cels resolve through [baseFrameLinks].
  /// v1: bases are drawing-kind layers only, no nesting.
  final LayerId? attachedToLayerId;

  /// Whether this attach layer draws above or below its base (meaningful
  /// only while [attachedToLayerId] is set; the layer list keeps attach
  /// layers adjacent to their base in [below…, base, above…] order).
  final AttachedPlacement attachedPlacement;

  /// The attach TIMING mode (UI-R21 #3): [AttachedMode.synced] mirrors
  /// the base through [baseFrameLinks] (own [timeline] stays empty);
  /// [AttachedMode.free] authors its own timeline like a normal drawing
  /// layer. Meaningful only while [attachedToLayerId] is set.
  final AttachedMode attachedMode;

  /// CELL-level links: base frame id → this layer's frame id. Linking per
  /// cel (not per block start) keeps attach cels riding linked-cel reuse
  /// and comma drags automatically. A base cel without a link simply shows
  /// nothing on this layer; links to deleted base cels are orphans that
  /// come back with the cel (audio-clip semantics).
  final Map<FrameId, FrameId> baseFrameLinks;

  /// TVP-style run-edge properties (UI-R9 #10 N/H/R): live specs whose
  /// GHOST exposures are derived from the current timeline by
  /// [rederiveRunBehaviors] on every edit and cut-duration change — see
  /// [TimelineRunBehavior].
  final List<TimelineRunBehavior> runBehaviors;

  Layer copyWith({
    LayerId? id,
    String? name,
    List<Frame>? frames,
    Map<int, TimelineExposure>? timeline,
    Map<int, InstructionEvent>? instructions,
    List<AudioClip>? audioClips,
    bool? isVisible,
    bool? muted,
    double? opacity,
    LayerKind? kind,
    bool? onTimesheet,
    LayerMark? mark,
    bool? isFillReference,
    TransformTrack? transformTrack,
    LayerId? attachedToLayerId,
    AttachedPlacement? attachedPlacement,
    AttachedMode? attachedMode,
    Map<FrameId, FrameId>? baseFrameLinks,
    List<TimelineRunBehavior>? runBehaviors,
    Object? folderId = copyWithSentinel,
  }) {
    final nextFrames = frames ?? this.frames;
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      frames: nextFrames,
      timeline: timeline ?? this.timeline,
      instructions: instructions ?? this.instructions,
      audioClips: audioClips ?? this.audioClips,
      isVisible: isVisible ?? this.isVisible,
      muted: muted ?? this.muted,
      opacity: opacity ?? this.opacity,
      kind: kind ?? this.kind,
      onTimesheet: onTimesheet ?? this.onTimesheet,
      mark: mark ?? this.mark,
      isFillReference: isFillReference ?? this.isFillReference,
      transformTrack: transformTrack ?? this.transformTrack,
      // Detaching is not expressible here (attach rows are created and
      // deleted whole); copyWith only carries the linkage along.
      attachedToLayerId: attachedToLayerId ?? this.attachedToLayerId,
      attachedPlacement: attachedPlacement ?? this.attachedPlacement,
      attachedMode: attachedMode ?? this.attachedMode,
      baseFrameLinks: baseFrameLinks ?? this.baseFrameLinks,
      runBehaviors: runBehaviors ?? this.runBehaviors,
      // Sentinel: moving a layer OUT of its folder (null) must be
      // expressible.
      folderId: identical(folderId, copyWithSentinel)
          ? this.folderId
          : folderId as FolderId?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'frames': frames.map((frame) => frame.toJson()).toList(),
    'timeline': timeline.entries
        .map((entry) => {'index': entry.key, 'exposure': entry.value.toJson()})
        .toList(),
    if (instructions.isNotEmpty)
      'instructions': instructionMapToJson(instructions),
    if (audioClips.isNotEmpty)
      'audioClips': audioClips.map((clip) => clip.toJson()).toList(),
    'isVisible': isVisible,
    if (muted) 'muted': true,
    'opacity': opacity,
    'kind': kind.toJson(),
    'onTimesheet': onTimesheet,
    'mark': mark.toJson(),
    if (isFillReference) 'fillReference': true,
    if (folderId != null) 'folderId': folderId!.toJson(),
    if (runBehaviors.isNotEmpty)
      'runBehaviors': [for (final behavior in runBehaviors) behavior.toJson()],
    if (transformTrack.isNotEmpty) 'transform': transformTrack.toJson(),
    if (attachedToLayerId != null) ...{
      'attachedTo': attachedToLayerId!.toJson(),
      'attachedPlacement': attachedPlacement.toJson(),
      // Default synced omitted — pre-mode files read back unchanged.
      if (attachedMode != AttachedMode.synced)
        'attachedMode': attachedMode.toJson(),
      if (baseFrameLinks.isNotEmpty)
        'baseFrameLinks': [
          for (final entry in baseFrameLinks.entries)
            {'base': entry.key.toJson(), 'frame': entry.value.toJson()},
        ],
    },
  };

  /// Migrates a legacy free-floating clip ({'file', 'start'}) onto the SE
  /// frame whose block covered its start frame; clips landing on empty
  /// cells have nothing to link to and drop.
  static AudioClip? _audioClipFromJson(
    Map<String, dynamic> json,
    Map<int, TimelineExposure> timeline,
  ) {
    if (json.containsKey('frame')) {
      return AudioClip.fromJson(json);
    }
    final startFrame = json['start'] as int? ?? 0;
    for (final block in drawingBlocks(SplayTreeMap.of(timeline))) {
      if (block.startIndex <= startFrame &&
          startFrame < block.endIndexExclusive) {
        return AudioClip(
          filePath: json['file'] as String,
          frameId: block.frameId,
        );
      }
    }
    return null;
  }

  factory Layer.fromJson(Map<String, dynamic> json) {
    final frames = (json['frames'] as List<dynamic>)
        .map((frame) => Frame.fromJson(frame as Map<String, dynamic>))
        .toList();
    final timeline = json.containsKey('timeline')
        ? _timelineFromJson(
            json['timeline'],
            legacyMarksJson: json['marks'],
            frames: frames,
          )
        : _deriveTimeline(frames);
    return Layer(
      id: LayerId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      frames: frames,
      timeline: timeline,
      instructions: instructionMapFromJson(json['instructions']),
      audioClips: json['audioClips'] == null
          ? const []
          : [
              for (final clip in json['audioClips'] as List<dynamic>)
                ?_audioClipFromJson(clip as Map<String, dynamic>, timeline),
            ],
      isVisible: json['isVisible'] as bool,
      muted: json['muted'] as bool? ?? false,
      opacity: (json['opacity'] as num).toDouble(),
      kind: json.containsKey('kind')
          ? LayerKind.fromJson(json['kind'])
          : LayerKind.animation,
      onTimesheet: json.containsKey('onTimesheet')
          ? json['onTimesheet'] as bool
          : true,
      mark: json.containsKey('mark')
          ? LayerMark.fromJson(json['mark'])
          : LayerMark.none,
      isFillReference: json['fillReference'] as bool? ?? false,
      // Legacy 'repeatRegions' JSON is ignored (no production data): its
      // stale ghost entries strip on the first rederive.
      runBehaviors: json['runBehaviors'] == null
          ? const []
          : [
              for (final behavior in json['runBehaviors'] as List<dynamic>)
                TimelineRunBehavior.fromJson(behavior as Map<String, dynamic>),
            ],
      transformTrack: json['transform'] == null
          ? null
          : TransformTrack.fromJson(json['transform'] as Map<String, dynamic>),
      attachedToLayerId: json['attachedTo'] == null
          ? null
          : LayerId.fromJson(json['attachedTo'] as Map<String, dynamic>),
      attachedPlacement: AttachedPlacement.fromJson(json['attachedPlacement']),
      attachedMode: AttachedMode.fromJson(json['attachedMode']),
      folderId: json['folderId'] == null
          ? null
          : FolderId.fromJson(json['folderId'] as Map<String, dynamic>),
      baseFrameLinks: json['baseFrameLinks'] == null
          ? const {}
          : {
              for (final link in json['baseFrameLinks'] as List<dynamic>)
                FrameId.fromJson(
                  (link as Map<String, dynamic>)['base']
                      as Map<String, dynamic>,
                ): FrameId.fromJson(
                  link['frame'] as Map<String, dynamic>,
                ),
            },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Layer &&
          other.id == id &&
          other.name == name &&
          listEquals(other.frames, frames) &&
          mapEquals(other.timeline, timeline) &&
          mapEquals(other.instructions, instructions) &&
          listEquals(other.audioClips, audioClips) &&
          other.isVisible == isVisible &&
          other.muted == muted &&
          other.opacity == opacity &&
          other.kind == kind &&
          other.onTimesheet == onTimesheet &&
          other.mark == mark &&
          other.isFillReference == isFillReference &&
          other.transformTrack == transformTrack &&
          other.attachedToLayerId == attachedToLayerId &&
          other.attachedPlacement == attachedPlacement &&
          other.attachedMode == attachedMode &&
          mapEquals(other.baseFrameLinks, baseFrameLinks) &&
          listEquals(other.runBehaviors, runBehaviors) &&
          other.folderId == folderId;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(frames),
    Object.hashAll(
      timeline.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAll(
      instructions.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAll(audioClips),
    isVisible,
    muted,
    opacity,
    kind,
    onTimesheet,
    mark,
    isFillReference,
    transformTrack,
    attachedToLayerId,
    Object.hash(attachedPlacement, attachedMode),
    Object.hashAllUnordered(
      baseFrameLinks.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAll(runBehaviors),
    folderId,
  );

  @override
  String toString() =>
      'Layer(id: $id, name: $name, frames: $frames, timeline: $timeline, '
      'instructions: $instructions, '
      'isVisible: $isVisible, opacity: $opacity, kind: $kind, '
      'onTimesheet: $onTimesheet, mark: $mark)';
}

SplayTreeMap<int, TimelineExposure> _immutableTimeline(
  Map<int, TimelineExposure> timeline,
) {
  final result = SplayTreeMap<int, TimelineExposure>();
  for (final entry in timeline.entries) {
    if (entry.key < 0) {
      throw ArgumentError.value(
        entry.key,
        'timeline',
        'Timeline indexes must be non-negative.',
      );
    }
    result[entry.key] = entry.value;
  }
  validateTimelineCoverage(result);
  return result;
}

SplayTreeMap<int, TimelineExposure> _deriveTimeline(List<Frame> frames) {
  final timeline = SplayTreeMap<int, TimelineExposure>();
  var index = 0;
  for (final frame in frames) {
    final length = frame.duration <= 0 ? 1 : frame.duration;
    timeline[index] = TimelineExposure.drawing(frame.id, length: length);
    index += length;
  }
  return timeline;
}

/// Raw parse of one legacy or current timeline item.
class _RawTimelineItem {
  const _RawTimelineItem({
    required this.index,
    required this.type,
    this.frameId,
    this.length,
    this.ghost = false,
    this.ghostOwnerId,
    this.breakdownOffsets = const [],
  });

  final int index;

  /// 'drawing' | 'blank' | 'mark'
  final String type;
  final FrameId? frameId;
  final int? length;
  final bool ghost;
  final String? ghostOwnerId;
  final List<int> breakdownOffsets;
}

/// Decodes a timeline from JSON, migrating legacy formats in one pass:
///
/// - legacy `blank` entries become nothing — each one cuts the preceding
///   drawing's hold at its index;
/// - legacy drawing entries without `length` get their old visual length:
///   up to the next entry (drawing or blank), or `Frame.duration` for the
///   last block (the old trailing infinite hold becomes finite);
/// - legacy standalone `mark` entries and the legacy separate `marks` map
///   fold into the covering drawing's [TimelineExposure.breakdownOffsets];
///   marks on a drawing start (offset 0) or on uncovered cells drop
///   (block-owned dots can't live off a block, and no production data
///   exists to preserve).
SplayTreeMap<int, TimelineExposure> _timelineFromJson(
  Object? json, {
  Object? legacyMarksJson,
  required List<Frame> frames,
}) {
  final items = SplayTreeMap<int, _RawTimelineItem>();

  void addItem(int index, Map<String, dynamic> exposureJson) {
    if (index < 0) {
      throw const FormatException('Timeline indexes must be non-negative.');
    }
    if (items.containsKey(index)) {
      throw FormatException('Duplicate timeline index: $index');
    }
    final type = exposureJson['type'];
    if (type != 'drawing' && type != 'blank' && type != 'mark') {
      throw FormatException('Unknown timeline exposure type: $type');
    }
    final frameIdJson = exposureJson['frameId'];
    final lengthJson = exposureJson['length'];
    if (type == 'drawing' && frameIdJson == null) {
      throw const FormatException(
        'Drawing timeline exposure requires frameId.',
      );
    }
    if (type != 'drawing' && frameIdJson != null) {
      throw FormatException('$type timeline exposure cannot have frameId.');
    }
    items[index] = _RawTimelineItem(
      index: index,
      type: type as String,
      frameId: frameIdJson == null
          ? null
          : FrameId.fromJson(frameIdJson as Map<String, dynamic>),
      length: lengthJson is int && lengthJson >= 1 ? lengthJson : null,
      ghost: exposureJson['ghost'] == true,
      ghostOwnerId:
          (exposureJson['ghostOwner'] ?? exposureJson['repeatRegionId'])
              as String?,
      breakdownOffsets: [
        for (final offset
            in exposureJson['breakdown'] as List<dynamic>? ?? const [])
          offset as int,
      ],
    );
  }

  if (json is List<dynamic>) {
    for (final item in json) {
      final entry = item as Map<String, dynamic>;
      addItem(entry['index'] as int, entry['exposure'] as Map<String, dynamic>);
    }
  } else if (json is Map<String, dynamic>) {
    for (final entry in json.entries) {
      final index = int.tryParse(entry.key);
      if (index == null) {
        throw FormatException('Invalid timeline index: ${entry.key}');
      }
      addItem(index, entry.value as Map<String, dynamic>);
    }
  } else {
    throw const FormatException('Layer timeline must be a list or object.');
  }

  final frameDurations = <FrameId, int>{
    for (final frame in frames)
      frame.id: frame.duration <= 0 ? 1 : frame.duration,
  };

  final timeline = SplayTreeMap<int, TimelineExposure>();
  final legacyMarkIndexes = <int>[];
  final rawItems = items.values.toList(growable: false);
  for (var i = 0; i < rawItems.length; i += 1) {
    final item = rawItems[i];
    switch (item.type) {
      case 'mark':
        // Legacy standalone dot: folded into its covering block below.
        legacyMarkIndexes.add(item.index);
      case 'blank':
        // Legacy hold terminator: consumed as the previous block's boundary.
        break;
      case 'drawing':
        var length = item.length;
        if (length == null) {
          // Legacy entry: old visuals held until the next drawing/blank
          // entry; the last block held its Frame.duration.
          int? boundary;
          for (var j = i + 1; j < rawItems.length; j += 1) {
            if (rawItems[j].type != 'mark') {
              boundary = rawItems[j].index;
              break;
            }
          }
          length = boundary != null
              ? boundary - item.index
              : (frameDurations[item.frameId] ?? 1);
        }
        // Never overlap the next drawing regardless of what the file says.
        for (var j = i + 1; j < rawItems.length; j += 1) {
          if (rawItems[j].type == 'drawing') {
            final maxLength = rawItems[j].index - item.index;
            if (length! > maxLength) {
              length = maxLength;
            }
            break;
          }
        }
        if (length! < 1) {
          length = 1;
        }
        var exposure = TimelineExposure.drawing(
          item.frameId!,
          length: length,
          ghost: item.ghost,
          ghostOwnerId: item.ghostOwnerId,
        );
        if (item.breakdownOffsets.isNotEmpty) {
          // copyWith normalizes (sorts, dedupes, clamps to the length).
          exposure = exposure.copyWith(breakdownOffsets: item.breakdownOffsets);
        }
        timeline[item.index] = exposure;
    }
  }

  _foldLegacyMarks(timeline, [
    ...legacyMarkIndexes,
    ..._legacyMarkIndexes(legacyMarksJson),
  ]);
  return timeline;
}

List<int> _legacyMarkIndexes(Object? legacyMarksJson) {
  if (legacyMarksJson == null) {
    return const [];
  }

  final indexes = <int>[];
  if (legacyMarksJson is List<dynamic>) {
    for (final item in legacyMarksJson) {
      indexes.add((item as Map<String, dynamic>)['index'] as int);
    }
  } else if (legacyMarksJson is Map<String, dynamic>) {
    for (final key in legacyMarksJson.keys) {
      final index = int.tryParse(key);
      if (index == null) {
        throw FormatException('Invalid timeline mark index: $key');
      }
      indexes.add(index);
    }
  } else {
    throw const FormatException('Layer marks must be a list or object.');
  }
  for (final index in indexes) {
    if (index < 0) {
      throw const FormatException(
        'Timeline mark indexes must be non-negative.',
      );
    }
  }
  return indexes;
}

/// Folds legacy standalone marks into the covering drawing block's
/// [TimelineExposure.breakdownOffsets]. Marks on a block start (the dot
/// would sit on the drawing itself) or on uncovered cells drop.
void _foldLegacyMarks(
  SplayTreeMap<int, TimelineExposure> timeline,
  Iterable<int> markIndexes,
) {
  for (final index in markIndexes) {
    final start = timeline.lastKeyBefore(index + 1);
    if (start == null) {
      continue;
    }
    final exposure = timeline[start]!;
    final offset = index - start;
    if (offset < 1 || offset >= exposure.length!) {
      continue;
    }
    timeline[start] = exposure.copyWith(
      breakdownOffsets: [...exposure.breakdownOffsets, offset],
    );
  }
}
