import 'string_id.dart';

final class StrokeId extends StringId {
  const StrokeId(super.value);

  factory StrokeId.fromJson(Map<String, dynamic> json) =>
      StrokeId(json['value'] as String);
}
