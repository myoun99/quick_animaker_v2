import 'dart:collection';

import '../core/collection_equality.dart';

/// AE-style temporal interpolation OUT of a key: how the segment between
/// this key and the next one moves.
enum PropertyKeyInterpolation {
  /// Linear ramp to the next key (AE default).
  linear,

  /// Freeze on this key's value until the next key (AE hold keyframe) —
  /// the staple of stepped 2D animation and the sheet's SLIDE notation.
  hold;

  String toJson() => name;

  static PropertyKeyInterpolation fromJson(Object? json) =>
      values.asNameMap()[json] ?? PropertyKeyInterpolation.linear;
}

/// One keyframe of a single transform property.
class PropertyKey<T> {
  const PropertyKey(
    this.value, {
    this.interpolation = PropertyKeyInterpolation.linear,
  });

  final T value;

  /// Interpolation of the segment LEAVING this key.
  final PropertyKeyInterpolation interpolation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyKey<T> &&
          other.value == value &&
          other.interpolation == interpolation;

  @override
  int get hashCode => Object.hash(value, interpolation);

  @override
  String toString() => 'PropertyKey($value, $interpolation)';
}

/// A single animated property, keyed independently of every other property
/// (the After Effects model: Position can carry three keys while Scale
/// carries none).
///
/// Resolution semantics ([resolveAt]): exact keys win; frames before the
/// first key hold the first value and frames after the last hold the last;
/// between two keys the PREVIOUS key's interpolation decides — linear
/// ramps, hold freezes. An empty track means "no animation" — consumers
/// supply their own default.
class PropertyTrack<T> {
  PropertyTrack({Map<int, PropertyKey<T>>? keys})
    : keys = _immutableKeys(keys ?? const {});

  factory PropertyTrack.empty() => PropertyTrack();

  final SplayTreeMap<int, PropertyKey<T>> keys;

  bool get isEmpty => keys.isEmpty;
  bool get isNotEmpty => keys.isNotEmpty;

  PropertyKey<T>? keyAt(int frameIndex) => keys[frameIndex];

  PropertyTrack<T> withKey(
    int frameIndex,
    T value, {
    PropertyKeyInterpolation interpolation = PropertyKeyInterpolation.linear,
  }) {
    return PropertyTrack(
      keys: {
        ...keys,
        frameIndex: PropertyKey(value, interpolation: interpolation),
      },
    );
  }

  PropertyTrack<T> withoutKey(int frameIndex) {
    final next = Map<int, PropertyKey<T>>.of(keys)..remove(frameIndex);
    return PropertyTrack(keys: next);
  }

  /// Resolves the property value at [frameIndex]; [orElse] supplies the
  /// empty-track default and [lerp] the component interpolation.
  T resolveAt({
    required int frameIndex,
    required T Function() orElse,
    required T Function(T a, T b, double t) lerp,
  }) {
    if (isEmpty) {
      return orElse();
    }

    final exact = keys[frameIndex];
    if (exact != null) {
      return exact.value;
    }

    final previousIndex = keys.lastKeyBefore(frameIndex);
    final nextIndex = keys.firstKeyAfter(frameIndex);
    if (previousIndex == null) {
      return keys[nextIndex!]!.value;
    }
    if (nextIndex == null) {
      return keys[previousIndex]!.value;
    }

    final previous = keys[previousIndex]!;
    if (previous.interpolation == PropertyKeyInterpolation.hold) {
      return previous.value;
    }
    return lerp(
      previous.value,
      keys[nextIndex]!.value,
      (frameIndex - previousIndex) / (nextIndex - previousIndex),
    );
  }

  List<Map<String, dynamic>> toJson(Object? Function(T value) encodeValue) => [
    for (final entry in keys.entries)
      {
        'index': entry.key,
        'value': encodeValue(entry.value.value),
        if (entry.value.interpolation != PropertyKeyInterpolation.linear)
          'interpolation': entry.value.interpolation.toJson(),
      },
  ];

  static PropertyTrack<T> fromJson<T>(
    List<dynamic>? json,
    T Function(Object? value) decodeValue,
  ) {
    final keys = <int, PropertyKey<T>>{};
    for (final item in json ?? const []) {
      final entry = item as Map<String, dynamic>;
      final index = entry['index'] as int;
      if (keys.containsKey(index)) {
        throw FormatException('Duplicate property key index: $index');
      }
      keys[index] = PropertyKey(
        decodeValue(entry['value']),
        interpolation: PropertyKeyInterpolation.fromJson(
          entry['interpolation'],
        ),
      );
    }
    return PropertyTrack(keys: keys);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyTrack<T> && mapEquals(other.keys, keys);

  @override
  int get hashCode => Object.hashAll(
    keys.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );

  @override
  String toString() => 'PropertyTrack(keys: $keys)';
}

SplayTreeMap<int, PropertyKey<T>> _immutableKeys<T>(
  Map<int, PropertyKey<T>> keys,
) {
  final result = SplayTreeMap<int, PropertyKey<T>>();
  for (final entry in keys.entries) {
    if (entry.key < 0) {
      throw ArgumentError.value(
        entry.key,
        'keys',
        'Property key indexes must be non-negative.',
      );
    }
    result[entry.key] = entry.value;
  }
  return result;
}
