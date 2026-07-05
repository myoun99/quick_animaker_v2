import 'string_id.dart';

final class LayerId extends StringId {
  const LayerId(super.value);

  factory LayerId.fromJson(Map<String, dynamic> json) =>
      LayerId(json['value'] as String);
}
