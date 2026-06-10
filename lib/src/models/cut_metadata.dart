class CutMetadata {
  const CutMetadata({this.note = ''});

  const CutMetadata.empty() : note = '';

  final String note;

  CutMetadata copyWith({String? note}) {
    return CutMetadata(note: note ?? this.note);
  }

  Map<String, dynamic> toJson() => {'note': note};

  factory CutMetadata.fromJson(Map<String, dynamic> json) {
    return CutMetadata(note: json['note'] as String? ?? '');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CutMetadata && other.note == note;

  @override
  int get hashCode => note.hashCode;

  @override
  String toString() => 'CutMetadata(note: $note)';
}
