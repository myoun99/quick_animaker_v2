import '../models/rgba_color.dart';

double effectiveSourceAlpha({
  required RgbaColor source,
  required double opacity,
  required double flow,
}) {
  _validateUnitIntervalFinite(opacity, 'opacity');
  _validateUnitIntervalFinite(flow, 'flow');

  return (source.a / 255.0) * opacity * flow;
}

RgbaColor rgbaSourceOver({
  required RgbaColor source,
  required RgbaColor destination,
  required double opacity,
  required double flow,
}) {
  _validateUnitIntervalFinite(opacity, 'opacity');
  _validateUnitIntervalFinite(flow, 'flow');

  if (source.a == 0 || opacity == 0.0 || flow == 0.0) {
    return destination;
  }

  final sourceAlpha = (source.a / 255.0) * opacity * flow;
  final destinationAlpha = destination.a / 255.0;
  final outAlpha = sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);

  if (outAlpha == 0.0) {
    return RgbaColor(r: 0, g: 0, b: 0, a: 0);
  }

  final inverseSourceAlpha = 1.0 - sourceAlpha;
  final outR =
      (source.r * sourceAlpha +
          destination.r * destinationAlpha * inverseSourceAlpha) /
      outAlpha;
  final outG =
      (source.g * sourceAlpha +
          destination.g * destinationAlpha * inverseSourceAlpha) /
      outAlpha;
  final outB =
      (source.b * sourceAlpha +
          destination.b * destinationAlpha * inverseSourceAlpha) /
      outAlpha;

  return RgbaColor(
    r: _roundAndClampByte(outR),
    g: _roundAndClampByte(outG),
    b: _roundAndClampByte(outB),
    a: _roundAndClampByte(outAlpha * 255.0),
  );
}

/// Destination-out: removes [destination] alpha by the source's effective
/// alpha (the eraser blend). Straight-alpha convention: RGB stays the
/// destination's; a fully erased pixel zeroes out entirely, matching
/// [rgbaSourceOver]'s zero-alpha handling.
RgbaColor rgbaDestinationOut({
  required RgbaColor source,
  required RgbaColor destination,
  required double opacity,
  required double flow,
}) {
  _validateUnitIntervalFinite(opacity, 'opacity');
  _validateUnitIntervalFinite(flow, 'flow');

  if (source.a == 0 || opacity == 0.0 || flow == 0.0) {
    return destination;
  }

  final sourceAlpha = (source.a / 255.0) * opacity * flow;
  final destinationAlpha = destination.a / 255.0;
  final outAlpha = destinationAlpha * (1.0 - sourceAlpha);

  if (outAlpha == 0.0) {
    return RgbaColor(r: 0, g: 0, b: 0, a: 0);
  }

  return RgbaColor(
    r: destination.r,
    g: destination.g,
    b: destination.b,
    a: _roundAndClampByte(outAlpha * 255.0),
  );
}

void _validateUnitIntervalFinite(double value, String fieldName) {
  if (!value.isFinite || value < 0.0 || value > 1.0) {
    throw ArgumentError.value(
      value,
      fieldName,
      '$fieldName must be finite and between 0.0 and 1.0 inclusive.',
    );
  }
}

int _roundAndClampByte(double value) => value.round().clamp(0, 255);
