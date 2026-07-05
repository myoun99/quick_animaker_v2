import 'string_id.dart';

final class CutId extends StringId {
  const CutId(super.value);

  factory CutId.fromJson(Map<String, dynamic> json) =>
      CutId(json['value'] as String);
}
