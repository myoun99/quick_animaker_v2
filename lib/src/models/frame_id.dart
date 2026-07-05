import 'string_id.dart';

final class FrameId extends StringId {
  const FrameId(super.value);

  factory FrameId.fromJson(Map<String, dynamic> json) =>
      FrameId(json['value'] as String);
}
