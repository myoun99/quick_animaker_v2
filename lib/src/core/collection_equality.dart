/// Lightweight, dependency-free collection equality helpers for the pure-Dart
/// model layer.
///
/// These replace the many per-file `_listEquals` / `_mapEquals` copies that used
/// to be duplicated across model files. They intentionally avoid importing
/// `package:flutter/foundation.dart` so the model layer stays pure Dart and
/// JSON-friendly.
library;

/// Returns `true` when [a] and [b] have the same length and equal elements in
/// order, using each element's own `==`.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Returns `true` when [a] and [b] have the same keys mapped to equal values,
/// using each value's own `==`.
bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
