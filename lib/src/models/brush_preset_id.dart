import 'string_id.dart';

final class BrushPresetId extends StringId {
  const BrushPresetId(super.value);

  factory BrushPresetId.fromJson(Map<String, dynamic> json) =>
      BrushPresetId(json['value'] as String);
}
