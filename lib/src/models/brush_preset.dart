import 'brush_preset_id.dart';
import 'brush_settings.dart';

class BrushPreset {
  const BrushPreset({
    required this.id,
    required this.name,
    required this.settings,
  });

  final BrushPresetId id;
  final String name;
  final BrushSettings settings;

  BrushPreset copyWith({
    BrushPresetId? id,
    String? name,
    BrushSettings? settings,
  }) {
    return BrushPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'name': name,
    'settings': settings.toJson(),
  };

  factory BrushPreset.fromJson(Map<String, dynamic> json) {
    return BrushPreset(
      id: BrushPresetId.fromJson(json['id'] as Map<String, dynamic>),
      name: json['name'] as String,
      settings: BrushSettings.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushPreset &&
          other.id == id &&
          other.name == name &&
          other.settings == settings;

  @override
  int get hashCode => Object.hash(id, name, settings);

  @override
  String toString() => 'BrushPreset(id: $id, name: $name, settings: $settings)';
}
