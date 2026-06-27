class UndoHistoryEntryId {
  const UndoHistoryEntryId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UndoHistoryEntryId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
