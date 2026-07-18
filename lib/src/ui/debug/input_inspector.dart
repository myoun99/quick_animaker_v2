import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart' show AppColors;

/// The cross-platform INPUT INSPECTOR (pen program, PEN-1).
///
/// A debug overlay that shows, live, exactly what the platform delivers
/// for every pointer contact: device kind, phase, RAW pressure (with the
/// device's min/max range), tilt/orientation, buttons and pointer id —
/// plus the session's peak pressure.
///
/// Why it exists: pen problems are almost always classification problems
/// ("the pen arrives as touch", "pressure is flat 1.0") that happen in
/// the DRIVER/OS layer, out of the app's reach. One screenshot of this
/// overlay separates "driver misreports" from "app mishandles" — on any
/// platform, for any tablet brand — so it is both our development probe
/// and the remote-diagnosis channel for user reports.
abstract final class InputInspector {
  /// Whether the overlay is shown (Edit ▸ Input Inspector). Static like
  /// the other app-level input state ([AppColors.accentSettings] idiom);
  /// tests flip it and MUST tearDown-reset via [reset].
  static final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  /// Bumped once per recorded event — the card listens to this, nothing
  /// else rebuilds.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Newest-last ring of recent events.
  static final List<InputInspectorSample> samples = <InputInspectorSample>[];

  /// The highest RAW pressure seen since the last [clear] — the quickest
  /// "is pressure alive at all" check.
  static double peakPressure = 0;

  static const int capacity = 120;

  static void record(PointerEvent event, {String? phaseOverride}) {
    final phase = phaseOverride ?? _phaseOf(event);
    if (phase == null) {
      return;
    }
    samples.add(InputInspectorSample.of(event, phase));
    if (samples.length > capacity) {
      samples.removeRange(0, samples.length - capacity);
    }
    // Peak tracks CONTACT pressure only — hovers idle at 0 by contract.
    if ((phase == 'down' || phase == 'move') && event.pressure > peakPressure) {
      peakPressure = event.pressure;
    }
    revision.value += 1;
  }

  static String? _phaseOf(PointerEvent event) => switch (event) {
    PointerDownEvent() => 'down',
    PointerMoveEvent() => 'move',
    PointerUpEvent() => 'up',
    PointerCancelEvent() => 'cancel',
    PointerHoverEvent() => 'hover',
    PointerScrollEvent() => 'scroll',
    PointerPanZoomStartEvent() => 'panzoom',
    PointerPanZoomUpdateEvent() => 'panzoom',
    _ => null,
  };

  /// Clears the ring + peak (the card's ⟲).
  static void clear() {
    samples.clear();
    peakPressure = 0;
    revision.value += 1;
  }

  /// Full reset for tests (visibility included).
  static void reset() {
    clear();
    visible.value = false;
  }
}

/// One recorded event, snapshotted at arrival (events are pooled — never
/// hold the live object).
class InputInspectorSample {
  const InputInspectorSample({
    required this.phase,
    required this.kind,
    required this.pressure,
    required this.pressureMin,
    required this.pressureMax,
    required this.tilt,
    required this.orientation,
    required this.buttons,
    required this.pointer,
    required this.position,
  });

  factory InputInspectorSample.of(PointerEvent event, String phase) =>
      InputInspectorSample(
        phase: phase,
        kind: event.kind,
        pressure: event.pressure,
        pressureMin: event.pressureMin,
        pressureMax: event.pressureMax,
        tilt: event.tilt,
        orientation: event.orientation,
        buttons: event.buttons,
        pointer: event.pointer,
        position: event.position,
      );

  final String phase;
  final PointerDeviceKind kind;
  final double pressure;
  final double pressureMin;
  final double pressureMax;
  final double tilt;
  final double orientation;
  final int buttons;
  final int pointer;
  final Offset position;

  String describe() {
    final buffer = StringBuffer()
      ..write(kind.name.padRight(7))
      ..write(phase.padRight(8))
      ..write('p=${pressure.toStringAsFixed(2)}');
    if (pressureMin != 0 || pressureMax != 1) {
      buffer.write(
        ' [${pressureMin.toStringAsFixed(1)}–${pressureMax.toStringAsFixed(1)}]',
      );
    }
    if (tilt != 0) {
      buffer.write(' tilt=${tilt.toStringAsFixed(2)}');
    }
    if (orientation != 0) {
      buffer.write(' or=${orientation.toStringAsFixed(2)}');
    }
    if (buttons != 0) {
      buffer.write(' btn=$buttons');
    }
    buffer
      ..write(' #$pointer ')
      ..write('(${position.dx.round()},${position.dy.round()})');
    return buffer.toString();
  }
}

/// Wraps the editor body: invisible until [InputInspector.visible] — then
/// a translucent listener records every pointer event passing anywhere
/// through the app and the card renders bottom-right. The listener never
/// competes in any gesture arena (raw observation only), so recording
/// changes NOTHING about input behavior.
class InputInspectorHost extends StatelessWidget {
  const InputInspectorHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: InputInspector.visible,
      builder: (context, visible, _) {
        if (!visible) {
          return child;
        }
        return Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: InputInspector.record,
              onPointerMove: InputInspector.record,
              onPointerUp: InputInspector.record,
              onPointerCancel: InputInspector.record,
              onPointerHover: InputInspector.record,
              onPointerSignal: InputInspector.record,
              onPointerPanZoomStart: InputInspector.record,
              onPointerPanZoomUpdate: InputInspector.record,
              child: child,
            ),
            const Positioned(right: 12, bottom: 12, child: _InspectorCard()),
          ],
        );
      },
    );
  }
}

class _InspectorCard extends StatelessWidget {
  const _InspectorCard();

  static const int _visibleRows = 10;

  Color _kindColor(ColorScheme colorScheme, PointerDeviceKind kind) =>
      switch (kind) {
        PointerDeviceKind.stylus ||
        PointerDeviceKind.invertedStylus => AppColors.accent,
        PointerDeviceKind.touch => AppColors.accent2,
        _ => colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const rowStyle = TextStyle(fontSize: 10, fontFamily: 'monospace');
    return Material(
      key: const ValueKey<String>('input-inspector-card'),
      elevation: 6,
      borderRadius: BorderRadius.circular(6),
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
          child: ValueListenableBuilder<int>(
            valueListenable: InputInspector.revision,
            builder: (context, _, _) {
              final samples = InputInspector.samples;
              final start = samples.length > _visibleRows
                  ? samples.length - _visibleRows
                  : 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'INPUT INSPECTOR',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'peak p='
                        '${InputInspector.peakPressure.toStringAsFixed(2)}',
                        key: const ValueKey<String>('input-inspector-peak'),
                        style: rowStyle.copyWith(color: AppColors.accent),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const ValueKey<String>('input-inspector-clear'),
                        tooltip: 'Clear',
                        visualDensity: VisualDensity.compact,
                        iconSize: 14,
                        onPressed: InputInspector.clear,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        key: const ValueKey<String>('input-inspector-close'),
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                        iconSize: 14,
                        onPressed: () => InputInspector.visible.value = false,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (samples.isEmpty)
                    Text(
                      'waiting for input…',
                      style: rowStyle.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (var i = start; i < samples.length; i += 1)
                      Text(
                        samples[i].describe(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rowStyle.copyWith(
                          color: _kindColor(colorScheme, samples[i].kind),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
