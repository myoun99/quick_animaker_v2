import 'storyboard_panel_id.dart';

class StoryboardPanel {
  const StoryboardPanel({
    required this.id,
    this.actionMemo = '',
    this.dialogueMemo = '',
    this.note = '',
  });

  final StoryboardPanelId id;
  final String actionMemo;
  final String dialogueMemo;
  final String note;

  StoryboardPanel copyWith({
    StoryboardPanelId? id,
    String? actionMemo,
    String? dialogueMemo,
    String? note,
  }) {
    return StoryboardPanel(
      id: id ?? this.id,
      actionMemo: actionMemo ?? this.actionMemo,
      dialogueMemo: dialogueMemo ?? this.dialogueMemo,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.toJson(),
    'actionMemo': actionMemo,
    'dialogueMemo': dialogueMemo,
    'note': note,
  };

  factory StoryboardPanel.fromJson(Map<String, dynamic> json) {
    return StoryboardPanel(
      id: StoryboardPanelId.fromJson(json['id'] as Map<String, dynamic>),
      actionMemo: json['actionMemo'] as String? ?? '',
      dialogueMemo: json['dialogueMemo'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryboardPanel &&
          other.id == id &&
          other.actionMemo == actionMemo &&
          other.dialogueMemo == dialogueMemo &&
          other.note == note;

  @override
  int get hashCode => Object.hash(id, actionMemo, dialogueMemo, note);

  @override
  String toString() =>
      'StoryboardPanel(id: $id, actionMemo: $actionMemo, dialogueMemo: $dialogueMemo, note: $note)';
}
