class StoryboardFrameMetadata {
  const StoryboardFrameMetadata({
    this.actionMemo = '',
    this.dialogueMemo = '',
    this.note = '',
  });

  const StoryboardFrameMetadata.empty()
    : actionMemo = '',
      dialogueMemo = '',
      note = '';

  final String actionMemo;
  final String dialogueMemo;
  final String note;

  StoryboardFrameMetadata copyWith({
    String? actionMemo,
    String? dialogueMemo,
    String? note,
  }) {
    return StoryboardFrameMetadata(
      actionMemo: actionMemo ?? this.actionMemo,
      dialogueMemo: dialogueMemo ?? this.dialogueMemo,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'actionMemo': actionMemo,
    'dialogueMemo': dialogueMemo,
    'note': note,
  };

  factory StoryboardFrameMetadata.fromJson(Map<String, dynamic> json) {
    return StoryboardFrameMetadata(
      actionMemo: json['actionMemo'] as String? ?? '',
      dialogueMemo: json['dialogueMemo'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryboardFrameMetadata &&
          other.actionMemo == actionMemo &&
          other.dialogueMemo == dialogueMemo &&
          other.note == note;

  @override
  int get hashCode => Object.hash(actionMemo, dialogueMemo, note);

  @override
  String toString() =>
      'StoryboardFrameMetadata(actionMemo: $actionMemo, dialogueMemo: $dialogueMemo, note: $note)';
}
