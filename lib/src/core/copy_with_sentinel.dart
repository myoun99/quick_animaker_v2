/// Shared sentinel for `copyWith` methods that must distinguish "argument not
/// provided" from "explicitly set to null" on a nullable field.
///
/// ```dart
/// Foo copyWith({Object? bar = copyWithSentinel}) => Foo(
///   bar: identical(bar, copyWithSentinel) ? this.bar : bar as Bar?,
/// );
/// ```
library;

const Object copyWithSentinel = Object();
