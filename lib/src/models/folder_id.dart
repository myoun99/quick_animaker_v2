import 'string_id.dart';

final class FolderId extends StringId {
  const FolderId(super.value);

  factory FolderId.fromJson(Map<String, dynamic> json) =>
      FolderId(json['value'] as String);
}
