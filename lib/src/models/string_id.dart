/// Shared base for the project's typed string identifiers.
///
/// Each concrete id (e.g. `FrameId`, `LayerId`) wraps a single [String] value
/// and stays a distinct type: two ids are equal only when they have the same
/// runtime type *and* the same value, so `FrameId('a') != LayerId('a')`.
///
/// Concrete ids remain tiny:
///
/// ```dart
/// final class FrameId extends StringId {
///   const FrameId(super.value);
///   factory FrameId.fromJson(Map<String, dynamic> json) =>
///       FrameId(json['value'] as String);
/// }
/// ```
abstract class StringId {
  const StringId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StringId &&
          other.runtimeType == runtimeType &&
          other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
