import 'storyboard_panel.dart';

class StoryboardLayer {
  StoryboardLayer({List<StoryboardPanel> panels = const []})
    : panels = List.unmodifiable(panels);

  const StoryboardLayer.empty() : panels = const [];

  final List<StoryboardPanel> panels;

  StoryboardLayer copyWith({List<StoryboardPanel>? panels}) {
    return StoryboardLayer(panels: panels ?? this.panels);
  }

  Map<String, dynamic> toJson() => {
    'panels': panels.map((panel) => panel.toJson()).toList(),
  };

  factory StoryboardLayer.fromJson(Map<String, dynamic> json) {
    return StoryboardLayer(
      panels: (json['panels'] as List<dynamic>? ?? const [])
          .map(
            (panel) => StoryboardPanel.fromJson(panel as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryboardLayer && _listEquals(other.panels, panels);

  @override
  int get hashCode => Object.hashAll(panels);

  @override
  String toString() => 'StoryboardLayer(panels: $panels)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
