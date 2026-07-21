/// Floor division for pasteboard-era pixel→tile mapping: Dart's `~/`
/// truncates toward zero, which maps pixel -1 to tile 0 instead of tile
/// -1. Every pixel→tile conversion that can see pasteboard (negative)
/// coordinates must use this.
int floorDiv(int value, int divisor) {
  final quotient = value ~/ divisor;
  if (value % divisor != 0 && (value < 0) != (divisor < 0)) {
    return quotient - 1;
  }
  return quotient;
}

/// Ceiling division (positive divisors), the closed companion of
/// [floorDiv] for computing exclusive tile ranges.
int ceilDiv(int value, int divisor) => floorDiv(value + divisor - 1, divisor);
