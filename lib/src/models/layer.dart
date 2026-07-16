import 'dart:collection';

import '../core/collection_equality.dart';
import 'attached_placement.dart';
import 'audio_clip.dart';
import 'camera_instruction.dart';
import 'frame.dart';
import 'frame_id.dart';
import 'layer_id.dart';
import 'layer_kind.dart';
import 'layer_mark.dart';
import 'timeline_coverage.dart';
import 'timeline_exposure.dart';
import 'timeline_exposure_type.dart';
import 'timeline_repeat.dart';
import 'transform_track.dart';

/// A cel layer. Its single [timeline] map records everything authored on
/// the frame axis: drawing block starts (frame + explicit hold length) and
/// inbetween marks. Emptiness has no entry — uncovered cells are the
/// timesheet "X" cells. There is no separate marks map and no blank entry
/// type (legacy files carrying either are migrated in [Layer.fromJson]).
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
    Map<FrameId, FrameId> baseFrameLinks = const {},
    List<TimelineRepeatRegion> repeatRegions = const [],
  }) : frames = List.unmodifiable(frames),
       timeline = _immutableTimeline(timeline ?? _deriveTimeline(frames)),
       instructions = immutableInstructionMap(instructions ?? const {}),
       audioClips = List.unmodifiable(audioClips),
       transformTrack = transformTrack ?? TransformTrack.empty(),
       baseFrameLinks = Map.unmodifiable(baseFrameLinks),
       repeatRegions = List.unmodifiable(repeatRegions);

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

  /// CELL-level links: base frame id → this layer's frame id. Linking per
  /// cel (not per block start) keeps attach cels riding linked-cel reuse
  /// and comma drags automatically. A base cel without a link simply shows
  /// nothing on this layer; links to deleted base cels are orphans that
  /// come back with the cel (audio-clip semantics).
  final Map<FrameId, FrameId> baseFrameLinks;

  /// TVP-style REPEAT specs (UI-R8): live regions whose GHOST exposures
  /// are derived from the current timeline by [rederiveRepeatRegions] on
  /// every edit — see [TimelineRepeatRegion].
  final List<TimelineRepeatRegion> repeatRegions;

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
    Map<FrameId, FrameId>? baseFrameLinks,
    List<TimelineRepeatRegion>? repeatRegions,
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
      baseFrameLinks: baseFrameLinks ?? this.baseFrameLinks,
      repeatRegions: repeatRegions ?? this.repeatRegions,
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
    if (repeatRegions.isNotEmpty)
      'repeatRegions': [
        for (final region in repeatRegions) region.toJson(),
      ],
    if (transformTrack.isNotEmpty) 'transform': transformTrack.toJson(),
    if (attachedToLayerId != null) ...{
      'attachedTo': attachedToLayerId!.toJson(),
      'attachedPlacement': attachedPlacement.toJson(),
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
      repeatRegions: json['repeatRegions'] == null
          ? const []
          : [
              for (final region in json['repeatRegions'] as List<dynamic>)
                TimelineRepeatRegion.fromJson(region as Map<String, dynamic>),
            ],
      transformTrack: json['transform'] == null
          ? null
          : TransformTrack.fromJson(json['transform'] as Map<String, dynamic>),
      attachedToLayerId: json['attachedTo'] == null
          ? null
          : LayerId.fromJson(json['attachedTo'] as Map<String, dynamic>),
      attachedPlacement: AttachedPlacement.fromJson(json['attachedPlacement']),
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
          mapEquals(other.baseFrameLinks, baseFrameLinks) &&
          listEquals(other.repeatRegions, repeatRegions);

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
    attachedPlacement,
    Object.hashAllUnordered(
      baseFrameLinks.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAll(repeatRegions),
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
    this.repeatRegionId,
  });

  final int index;

  /// 'drawing' | 'blank' | 'mark'
  final String type;
  final FrameId? frameId;
  final int? length;
  final bool ghost;
  final String? repeatRegionId;
}

/// Decodes a timeline from JSON, migrating legacy formats in one pass:
///
/// - legacy `blank` entries become nothing — each one cuts the preceding
///   drawing's hold at its index;
/// - legacy drawing entries without `length` get their old visual length:
///   up to the next entry (drawing or blank), or `Frame.duration` for the
///   last block (the old trailing infinite hold becomes finite);
/// - the legacy separate `marks` map merges in as mark entries, dropping
///   any mark that collides with a drawing start index (drawing wins).
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
      repeatRegionId: exposureJson['repeatRegionId'] as String?,
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
  final rawItems = items.values.toList(growable: false);
  for (var i = 0; i < rawItems.length; i += 1) {
    final item = rawItems[i];
    switch (item.type) {
      case 'mark':
        timeline[item.index] = const TimelineExposure.mark();
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
        timeline[item.index] = TimelineExposure.drawing(
          item.frameId!,
          length: length,
          ghost: item.ghost,
          repeatRegionId: item.repeatRegionId,
        );
    }
  }

  _mergeLegacyMarks(timeline, legacyMarksJson);
  return timeline;
}

void _mergeLegacyMarks(
  SplayTreeMap<int, TimelineExposure> timeline,
  Object? legacyMarksJson,
) {
  if (legacyMarksJson == null) {
    return;
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
    final existing = timeline[index];
    if (existing != null && existing.type == TimelineExposureType.drawing) {
      // Legacy marks could overlay a drawing start; the unified model keeps
      // the drawing.
      continue;
    }
    timeline[index] = const TimelineExposure.mark();
  }
}
