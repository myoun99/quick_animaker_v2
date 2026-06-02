class LayerId {
  const LayerId(this.value);

  final String value;

  Map<String, dynamic> toJson() => {'value': value};

  factory LayerId.fromJson(Map<String, dynamic> json) {
    return LayerId(json['value'] as String);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LayerId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
