import 'package:flutter/material.dart';

import 'canvas_playback_controller.dart';

/// The playback level meter (AUDIO-PRO R2): two thin bars fed by the
/// device transport's PRE-CLIP bus peaks. Green through the working
/// range, amber approaching full scale, red at/over 1.0 — the moment the
/// output stage starts clipping, which until now only ears could catch.
///
/// Repaints ride the playback frame notifier (the tick cadence playback
/// already broadcasts); an inactive or fallback run meters silence and
/// takes no space in anyone's attention.
class AudioLevelMeter extends StatelessWidget {
  const AudioLevelMeter({
    super.key,
    required this.controller,
    required this.resolvePeaks,
  });

  final CanvasPlaybackController controller;

  /// The transport's [AudioDeviceTransport.meterPeaks] (injected so the
  /// widget stays testable without a device).
  final ({double left, double right}) Function() resolvePeaks;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: controller.globalFrameIndexListenable,
      builder: (context, frame, _) {
        final peaks = frame == null
            ? (left: 0.0, right: 0.0)
            : resolvePeaks();
        return Semantics(
          label: 'audio level meter',
          child: SizedBox(
            key: const ValueKey<String>('audio-level-meter'),
            width: 6,
            height: 24,
            child: CustomPaint(
              painter: _MeterPainter(left: peaks.left, right: peaks.right),
            ),
          ),
        );
      },
    );
  }
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({required this.left, required this.right});

  final double left;
  final double right;

  static Color _colorFor(double peak) {
    if (peak >= 1.0) {
      return const Color(0xFFE53935); // clipping
    }
    if (peak >= 0.7) {
      return const Color(0xFFFFB300); // hot
    }
    return const Color(0xFF43A047);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = (size.width - 1) / 2;
    void bar(double peak, double x) {
      final clamped = peak > 1.0 ? 1.0 : (peak < 0.0 ? 0.0 : peak);
      final height = size.height * clamped;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - height, barWidth, height),
        Paint()..color = _colorFor(peak),
      );
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x33000000),
    );
    bar(left, 0);
    bar(right, barWidth + 1);
  }

  @override
  bool shouldRepaint(_MeterPainter oldDelegate) =>
      oldDelegate.left != left || oldDelegate.right != right;
}
