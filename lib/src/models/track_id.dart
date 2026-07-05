import 'string_id.dart';

final class TrackId extends StringId {
  const TrackId(super.value);

  factory TrackId.fromJson(Map<String, dynamic> json) =>
      TrackId(json['value'] as String);
}
