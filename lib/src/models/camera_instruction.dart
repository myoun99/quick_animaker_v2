import 'dart:collection';

import '../core/collection_equality.dart';

/// Camera-work instruction vocabulary and events for instruction rows.
///
/// A [CameraInstructionDef] is one entry of the project's instruction
/// vocabulary — FI, FO, PAN, T.U … — pairing a display name with a symbolic
/// [iconKey] (the UI maps keys to actual icons; the model stays pure) and an
/// optional accent color. The default set seeds the standard 撮影 terms; the
/// user extends/edits it freely, which is the whole point of the registry.
///
/// An [InstructionEvent] is one span on an instruction row: it starts at its
/// map key on the layer, holds for [length] frames and can carry the sheet's
/// A → B endpoint values as free text (e.g. a PAN's start/end positions).
class CameraInstructionDef {
  const CameraInstructionDef({
    required this.id,
    required this.name,
    required this.iconKey,
    this.colorValue,
  });

  /// Stable id events reference; never renamed (the [name] is the label).
  final String id;

  /// The sheet label — 'FI', 'PAN', a custom term.
  final String name;

  /// Symbolic icon key resolved by the UI's curated palette; unknown keys
  /// fall back to a generic glyph so files stay open-able across versions.
  final String iconKey;

  /// Optional accent (ARGB), null = theme default.
  final int? colorValue;

  CameraInstructionDef copyWith({
    String? name,
    String? iconKey,
    int? Function()? colorValue,
  }) {
    return CameraInstructionDef(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue == null ? this.colorValue : colorValue(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconKey': iconKey,
    if (colorValue != null) 'color': colorValue,
  };

  factory CameraInstructionDef.fromJson(Map<String, dynamic> json) {
    return CameraInstructionDef(
      id: json['id'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String,
      colorValue: json['color'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraInstructionDef &&
          other.id == id &&
          other.name == name &&
          other.iconKey == iconKey &&
          other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(id, name, iconKey, colorValue);

  @override
  String toString() =>
      'CameraInstructionDef(id: $id, name: $name, iconKey: $iconKey, '
      'color: $colorValue)';
}

/// The project-level instruction vocabulary, in display order.
class CameraInstructionSet {
  CameraInstructionSet({required List<CameraInstructionDef> defs})
    : defs = List.unmodifiable(defs) {
    final ids = <String>{};
    for (final def in this.defs) {
      if (!ids.add(def.id)) {
        throw ArgumentError.value(
          def.id,
          'defs',
          'Instruction ids must be unique.',
        );
      }
    }
  }

  final List<CameraInstructionDef> defs;

  CameraInstructionDef? defById(String id) {
    for (final def in defs) {
      if (def.id == id) {
        return def;
      }
    }
    return null;
  }

  /// The standard 撮影 vocabulary (撮ま! chapters): camera work, transitions
  /// and filter effects. Projects without a stored set open with this.
  static final CameraInstructionSet standard = CameraInstructionSet(
    defs: const [
      // Camera work.
      CameraInstructionDef(id: 'fix', name: 'FIX', iconKey: 'fix'),
      CameraInstructionDef(id: 'pan', name: 'PAN', iconKey: 'pan'),
      CameraInstructionDef(id: 'pan-up', name: 'PAN UP', iconKey: 'pan-up'),
      CameraInstructionDef(
        id: 'pan-down',
        name: 'PAN DOWN',
        iconKey: 'pan-down',
      ),
      CameraInstructionDef(id: 'sl', name: 'SL', iconKey: 'slide'),
      CameraInstructionDef(id: 'follow', name: 'Follow', iconKey: 'follow'),
      CameraInstructionDef(id: 'tu', name: 'T.U', iconKey: 'track-up'),
      CameraInstructionDef(id: 'tb', name: 'T.B', iconKey: 'track-back'),
      CameraInstructionDef(id: 'qtu', name: 'Q T.U', iconKey: 'track-up'),
      CameraInstructionDef(id: 'qtb', name: 'Q T.B', iconKey: 'track-back'),
      // Transitions.
      CameraInstructionDef(id: 'fi', name: 'FI', iconKey: 'fade-in'),
      CameraInstructionDef(id: 'fo', name: 'FO', iconKey: 'fade-out'),
      CameraInstructionDef(id: 'wi', name: 'WI', iconKey: 'white-in'),
      CameraInstructionDef(id: 'wo', name: 'WO', iconKey: 'white-out'),
      CameraInstructionDef(id: 'ol', name: 'O.L', iconKey: 'overlap'),
      CameraInstructionDef(id: 'wipe', name: 'WIPE', iconKey: 'wipe'),
      // Filter effects.
      CameraInstructionDef(id: 'si', name: 'S.I', iconKey: 'super-impose'),
      CameraInstructionDef(id: 'df', name: 'DF', iconKey: 'diffusion'),
      CameraInstructionDef(id: 'fog', name: 'FOG', iconKey: 'fog'),
    ],
  );

  Map<String, dynamic> toJson() => {
    'defs': defs.map((def) => def.toJson()).toList(),
  };

  factory CameraInstructionSet.fromJson(Map<String, dynamic> json) {
    return CameraInstructionSet(
      defs: (json['defs'] as List<dynamic>)
          .map(
            (def) => CameraInstructionDef.fromJson(def as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraInstructionSet && listEquals(other.defs, defs);

  @override
  int get hashCode => Object.hashAll(defs);

  @override
  String toString() => 'CameraInstructionSet(defs: $defs)';
}

/// One span on an instruction row; keyed by its start frame on the layer.
class InstructionEvent {
  const InstructionEvent({
    required this.instructionId,
    required this.length,
    this.text,
    this.valueA,
    this.valueB,
  });

  /// References a [CameraInstructionDef.id]; a dangling reference (its def
  /// was deleted) renders with the fallback glyph and the raw id.
  final String instructionId;

  /// Covered frames — [start, start + length).
  final int length;

  /// Free per-event text (the mark and the writing are independent, like on
  /// paper): when set it is what displays and prints; the vocabulary name is
  /// only the fallback.
  final String? text;

  /// The sheet's A → B endpoint values, free text ('A', '1.5倍', …).
  final String? valueA;
  final String? valueB;

  /// What displays/prints for this event given its vocabulary [def].
  String displayLabel(CameraInstructionDef? def) {
    final text = this.text;
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return def?.name ?? instructionId;
  }

  InstructionEvent copyWith({
    String? instructionId,
    int? length,
    String? Function()? text,
    String? Function()? valueA,
    String? Function()? valueB,
  }) {
    return InstructionEvent(
      instructionId: instructionId ?? this.instructionId,
      length: length ?? this.length,
      text: text == null ? this.text : text(),
      valueA: valueA == null ? this.valueA : valueA(),
      valueB: valueB == null ? this.valueB : valueB(),
    );
  }

  Map<String, dynamic> toJson() => {
    'instructionId': instructionId,
    'length': length,
    if (text != null) 'text': text,
    if (valueA != null) 'valueA': valueA,
    if (valueB != null) 'valueB': valueB,
  };

  factory InstructionEvent.fromJson(Map<String, dynamic> json) {
    return InstructionEvent(
      instructionId: json['instructionId'] as String,
      length: json['length'] as int,
      text: json['text'] as String?,
      valueA: json['valueA'] as String?,
      valueB: json['valueB'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstructionEvent &&
          other.instructionId == instructionId &&
          other.length == length &&
          other.text == text &&
          other.valueA == valueA &&
          other.valueB == valueB;

  @override
  int get hashCode => Object.hash(instructionId, length, text, valueA, valueB);

  @override
  String toString() =>
      'InstructionEvent(instructionId: $instructionId, length: $length, '
      'text: $text, valueA: $valueA, valueB: $valueB)';
}

/// Validates an instruction map: non-negative starts, positive lengths and
/// no overlapping spans (simultaneous instructions belong on additional
/// instruction rows, like the sheet's CAM 1 · CAM 2 columns).
void validateInstructionCoverage(
  SplayTreeMap<int, InstructionEvent> instructions,
) {
  int? previousEndExclusive;
  for (final entry in instructions.entries) {
    if (entry.key < 0) {
      throw ArgumentError.value(
        entry.key,
        'instructions',
        'Instruction start frames must be non-negative.',
      );
    }
    if (entry.value.length < 1) {
      throw ArgumentError.value(
        entry.value.length,
        'instructions',
        'Instruction lengths must be at least 1.',
      );
    }
    if (previousEndExclusive != null && entry.key < previousEndExclusive) {
      throw ArgumentError.value(
        entry.key,
        'instructions',
        'Instruction spans must not overlap.',
      );
    }
    previousEndExclusive = entry.key + entry.value.length;
  }
}

/// Immutable sorted copy of [instructions], validated.
SplayTreeMap<int, InstructionEvent> immutableInstructionMap(
  Map<int, InstructionEvent> instructions,
) {
  final result = SplayTreeMap<int, InstructionEvent>.of(instructions);
  validateInstructionCoverage(result);
  return result;
}

/// Decodes the layer JSON list form: `[{index, instructionId, length, …}]`.
SplayTreeMap<int, InstructionEvent> instructionMapFromJson(Object? json) {
  final result = SplayTreeMap<int, InstructionEvent>();
  if (json == null) {
    return result;
  }
  for (final item in json as List<dynamic>) {
    final map = item as Map<String, dynamic>;
    result[map['index'] as int] = InstructionEvent.fromJson(map);
  }
  validateInstructionCoverage(result);
  return result;
}

List<Map<String, dynamic>> instructionMapToJson(
  Map<int, InstructionEvent> instructions,
) {
  return [
    for (final entry in instructions.entries)
      {'index': entry.key, ...entry.value.toJson()},
  ];
}
