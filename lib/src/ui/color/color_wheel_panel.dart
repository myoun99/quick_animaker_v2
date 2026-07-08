import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CSP/Photoshop-style color wheel: a hue ring around a saturation/value
/// square. Dragging the ring spins the hue (the square re-tints live);
/// dragging the square picks saturation (→right) and value (↑up). The
/// panel keeps its own [HSVColor] so hue survives passing through zero
/// saturation or value, where RGB round-trips would forget it.
class ColorWheelPanel extends StatefulWidget {
  const ColorWheelPanel({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  /// The active brush color (ARGB int, the brush tool state's format).
  final int color;
  final ValueChanged<int> onColorChanged;

  @override
  State<ColorWheelPanel> createState() => _ColorWheelPanelState();
}

class _ColorWheelPanelState extends State<ColorWheelPanel> {
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.color));
  int? _lastEmitted;

  @override
  void didUpdateWidget(covariant ColorWheelPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-derive HSV only for EXTERNAL color changes (preset swatches, brush
    // switches); our own emissions round-trip through the parent and must
    // not clobber the held hue.
    if (widget.color != oldWidget.color && widget.color != _lastEmitted) {
      _hsv = HSVColor.fromColor(Color(widget.color));
    }
  }

  void _setHsv(HSVColor hsv) {
    setState(() => _hsv = hsv);
    final argb = hsv.toColor().toARGB32();
    _lastEmitted = argb;
    widget.onColorChanged(argb);
  }

  String get _hexLabel {
    final rgb = _hsv.toColor().toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.topCenter,
              child: AspectRatio(
                aspectRatio: 1,
                child: ColorWheel(
                  key: const ValueKey<String>('color-wheel'),
                  hsv: _hsv,
                  onChanged: _setHsv,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                key: const ValueKey<String>('color-wheel-current-swatch'),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _hsv.toColor(),
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _hexLabel,
                key: const ValueKey<String>('color-wheel-hex-label'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Which part of the wheel a pointer engages; locked at pointer-down so a
/// drag never jumps between the ring and the square mid-gesture.
enum ColorWheelRegion { hueRing, svSquare, none }

/// Pure hit/mapping geometry, shared by the painter, the gestures and the
/// tests.
class ColorWheelGeometry {
  ColorWheelGeometry(Size size)
    : center = size.center(Offset.zero),
      outerRadius = size.shortestSide / 2;

  final Offset center;
  final double outerRadius;

  double get ringWidth => outerRadius * 0.18;
  double get innerRadius => outerRadius - ringWidth;

  /// The SV square inscribed in the inner circle (with a small breathing
  /// gap to the ring).
  Rect get squareRect {
    final half = innerRadius / math.sqrt2 * 0.94;
    return Rect.fromCenter(center: center, width: half * 2, height: half * 2);
  }

  ColorWheelRegion regionAt(Offset position) {
    if (squareRect.contains(position)) {
      return ColorWheelRegion.svSquare;
    }
    final distance = (position - center).distance;
    if (distance >= innerRadius - 4 && distance <= outerRadius + 8) {
      return ColorWheelRegion.hueRing;
    }
    return ColorWheelRegion.none;
  }

  /// Hue in degrees at [position]: 0° at 3 o'clock, increasing clockwise —
  /// the same convention the sweep-gradient ring paints.
  double hueAt(Offset position) {
    final delta = position - center;
    final degrees = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    return (degrees + 360) % 360;
  }

  /// Saturation (→right) and value (↑up) at [position], clamped into the
  /// square.
  (double saturation, double value) svAt(Offset position) {
    final rect = squareRect;
    final saturation = ((position.dx - rect.left) / rect.width).clamp(0.0, 1.0);
    final value =
        1.0 - ((position.dy - rect.top) / rect.height).clamp(0.0, 1.0);
    return (saturation, value);
  }
}

class ColorWheel extends StatefulWidget {
  const ColorWheel({super.key, required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  State<ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<ColorWheel> {
  ColorWheelRegion _activeRegion = ColorWheelRegion.none;

  void _apply(Offset position, Size size) {
    final geometry = ColorWheelGeometry(size);
    switch (_activeRegion) {
      case ColorWheelRegion.hueRing:
        widget.onChanged(widget.hsv.withHue(geometry.hueAt(position)));
      case ColorWheelRegion.svSquare:
        final (saturation, value) = geometry.svAt(position);
        widget.onChanged(
          widget.hsv.withSaturation(saturation).withValue(value),
        );
      case ColorWheelRegion.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            _activeRegion = ColorWheelGeometry(
              size,
            ).regionAt(details.localPosition);
            _apply(details.localPosition, size);
          },
          onPanUpdate: (details) => _apply(details.localPosition, size),
          onPanEnd: (_) => _activeRegion = ColorWheelRegion.none,
          onPanCancel: () => _activeRegion = ColorWheelRegion.none,
          child: CustomPaint(painter: _ColorWheelPainter(hsv: widget.hsv)),
        );
      },
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  _ColorWheelPainter({required this.hsv});

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = ColorWheelGeometry(size);
    final center = geometry.center;

    // Hue ring: a sweep gradient stroke. SweepGradient runs clockwise from
    // the +x axis in screen space — the same angle convention hueAt reads.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = geometry.ringWidth
      ..shader =
          SweepGradient(
            colors: [
              for (var hue = 0; hue <= 360; hue += 30)
                HSVColor.fromAHSV(1, (hue % 360).toDouble(), 1, 1).toColor(),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: geometry.outerRadius),
          );
    final ringRadius = geometry.innerRadius + geometry.ringWidth / 2;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // SV square: white→hue horizontally, then transparent→black downward.
    final rect = geometry.squareRect;
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    // Indicators: hue dot on the ring, SV dot in the square — white/black
    // double stroke so they read on any color underneath.
    final hueAngle = hsv.hue * math.pi / 180;
    final hueDot =
        center + Offset(math.cos(hueAngle), math.sin(hueAngle)) * ringRadius;
    _paintIndicator(canvas, hueDot, geometry.ringWidth * 0.34);

    final svDot = Offset(
      rect.left + hsv.saturation * rect.width,
      rect.top + (1 - hsv.value) * rect.height,
    );
    _paintIndicator(canvas, svDot, 5);
  }

  void _paintIndicator(Canvas canvas, Offset at, double radius) {
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawCircle(
      at,
      radius + 1.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) =>
      oldDelegate.hsv != hsv;
}
