import '../core/collection_equality.dart';
import 'brush_dab.dart';

class BrushDabSequence {
  BrushDabSequence([Iterable<BrushDab> dabs = const []])
    : _dabs = List<BrushDab>.unmodifiable(dabs);

  final List<BrushDab> _dabs;

  List<BrushDab> get dabs => List<BrushDab>.unmodifiable(_dabs);

  int get length => _dabs.length;

  bool get isEmpty => _dabs.isEmpty;

  bool get isNotEmpty => _dabs.isNotEmpty;

  BrushDab? get firstOrNull => _dabs.isEmpty ? null : _dabs.first;

  BrushDab? get lastOrNull => _dabs.isEmpty ? null : _dabs.last;

  BrushDabSequence add(BrushDab dab) => BrushDabSequence([..._dabs, dab]);

  BrushDabSequence addAll(Iterable<BrushDab> dabs) =>
      BrushDabSequence([..._dabs, ...dabs]);

  Map<String, dynamic> toJson() => {
    'dabs': _dabs.map((dab) => dab.toJson()).toList(),
  };

  factory BrushDabSequence.fromJson(Map<String, dynamic> json) {
    return BrushDabSequence(
      (json['dabs'] as List? ?? const []).map(
        (dabJson) => BrushDab.fromJson(dabJson as Map<String, dynamic>),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushDabSequence && listEquals(other._dabs, _dabs);

  @override
  int get hashCode => Object.hashAll(_dabs);

  @override
  String toString() => 'BrushDabSequence(length: $length, dabs: $_dabs)';
}
