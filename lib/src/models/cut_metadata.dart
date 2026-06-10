class CutMetadata {
  const CutMetadata({
    this.actionMemo = '',
    this.dialogueMemo = '',
    this.note = '',
  });

  const CutMetadata.empty()
    : actionMemo = '',
      dialogueMemo = '',
      note = '';

  final String actionMemo;
  final String dialogueMemo;
  final String note;

  CutMetadata copyWith({
    String? actionMemo,
    String? dialogueMemo,
    String? note,
  }) {
    return CutMetadata(
      actionMemo: actionMemo ?? this.actionMemo,
      dialogueMemo: dialogueMemo ?? this.dialogueMemo,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CutMetadata &&
          other.actionMemo == actionMemo &&
          other.dialogueMemo == dialogueMemo &&
          other.note == note;

  @override
  int get hashCode => Object.hash(actionMemo, dialogueMemo, note);

  @override
  String toString() =>
      'CutMetadata(actionMemo: $actionMemo, dialogueMemo: $dialogueMemo, note: $note)';
}
