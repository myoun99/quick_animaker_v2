import 'brush_preset_id.dart';
import 'brush_settings.dart';

class BrushPreset {
  const BrushPreset({
    required this.id,
    required this.name,
    required this.settings,
    this.group,
  });

  final BrushPresetId id;
  final String name;
  final BrushSettings settings;

  /// Library group the preset belongs to (e.g. the import source file's
  /// base name, mirroring Clip Studio sub-tool groups). `null` means
  /// ungrouped; the UI shows those under a default group.
  final String? group;

  BrushPreset copyWith({
    BrushPresetId? id,
    String? name,
    BrushSettings? settings,
    String? group,
  }) {
    return BrushPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      group: group ?? this.group,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'settings': settings.toJson(),
    if (group != null) 'group': group,
  };

  factory BrushPreset.fromJson(Map<String, dynamic> json) {
    return BrushPreset(
      id: BrushPresetId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      settings: BrushSettings.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
      group: json['group'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushPreset &&
          other.id == id &&
          other.name == name &&
          other.settings == settings &&
          other.group == group;

  @override
  int get hashCode => Object.hash(id, name, settings, group);

  @override
  String toString() =>
      'BrushPreset(id: $id, name: $name, group: $group, settings: $settings)';
}
