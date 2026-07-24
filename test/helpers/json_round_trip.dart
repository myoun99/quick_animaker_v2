import 'package:flutter_test/flutter_test.dart';

/// Asserts [value] survives a JSON round-trip — `fromJson(value.toJson())`
/// equals [value]. The one home for the round-trip contract every model
/// test used to spell out by hand, so how a round-trip is verified changes
/// in a single place, not in twenty files.
///
/// `toJson` is reached dynamically because the models share no common
/// serializable interface; each one nonetheless returns a
/// `Map<String, dynamic>` its `fromJson` accepts.
void expectJsonRoundTrip<T>(T value, T Function(Map<String, dynamic>) fromJson) {
  final json = (value as dynamic).toJson() as Map<String, dynamic>;
  expect(fromJson(json), value);
}
