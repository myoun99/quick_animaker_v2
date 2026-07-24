import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../native/qa_tablet_bridge.dart';
import '../../ui/input/app_input_settings.dart';

/// The Wintab pen stream (pen program, PEN-2) — the CSP-style second
/// tablet backend, as a PRESSURE SIDECAR:
///
/// Flutter's pointer events keep driving position and every gesture; this
/// service polls the DRIVER's packet queue (through [QaTabletBridge]) and
/// holds the freshest contact pressure/tilt. The brush canvas consults
/// [freshContactPressure] per pointer sample — so a pen the OS misreports
/// (as touch, or as mouse with Ink unchecked) still paints with the
/// driver's full pressure.
///
/// Lifecycle: [bind] once at app start — the service follows
/// [AppInput.settings] (`tabletService == wintab` starts polling, anything
/// else stops it). Absence of the DLL/driver = permanently idle, silent.
class WintabPenService {
  WintabPenService._();

  static final WintabPenService instance = WintabPenService._();

  /// Poll cadence: the Wintab queue holds ~128 packets and drivers report
  /// 133–200Hz — 8ms drains comfortably ahead of loss.
  static const Duration pollInterval = Duration(milliseconds: 8);

  /// A pressure sample older than this no longer overrides pointer events
  /// (the pen left proximity / the stream hiccuped).
  static const Duration freshWindow = Duration(milliseconds: 150);

  /// Test hook: replaces the bridge's poll (packets in, wall-clocked as
  /// now). Null = the real DLL.
  List<QaTabletPacket> Function()? debugPollOverride;

  /// The freshest driver packet (null until one arrives) — the input
  /// inspector renders this line when live.
  final ValueNotifier<QaTabletPacket?> latest = ValueNotifier<QaTabletPacket?>(
    null,
  );

  QaTabletBridge? _bridge;
  Timer? _timer;
  bool _opened = false;
  DateTime _lastPacketAt = DateTime.fromMillisecondsSinceEpoch(0);
  VoidCallback? _settingsListener;

  /// The clock the freshness window reads. Production uses wall time;
  /// tests inject a fixed clock so a packet stays "fresh" regardless of
  /// how long the test binding takes between injecting it and polling the
  /// pressure — otherwise a busy suite lets the real 150ms window lapse
  /// mid-stroke and the driver pressure silently reverts to the pointer's
  /// (the "dab size 4.0 vs 4.25" flake).
  @visibleForTesting
  static DateTime Function()? debugClockOverride;

  static DateTime _now() => debugClockOverride?.call() ?? DateTime.now();

  bool get running => _timer != null;

  /// Follows the live input settings; safe to call once from main().
  void bind() {
    if (_settingsListener != null) {
      return;
    }
    _settingsListener = () => apply(AppInput.settings.value);
    AppInput.settings.addListener(_settingsListener!);
    apply(AppInput.settings.value);
  }

  void apply(AppInputSettings settings) {
    if (settings.tabletService == TabletService.wintab) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_timer != null) {
      return;
    }
    _bridge ??= QaTabletBridge.instanceOrNull;
    if (debugPollOverride == null && (_bridge == null || !_bridge!.available)) {
      return; // No driver — stay idle (the standard graceful absence).
    }
    _timer = Timer.periodic(pollInterval, (_) => _pump());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_opened) {
      _bridge?.close();
      _opened = false;
    }
    latest.value = null;
  }

  void _pump() {
    final override = debugPollOverride;
    List<QaTabletPacket> packets;
    if (override != null) {
      packets = override();
    } else {
      final bridge = _bridge;
      if (bridge == null) {
        return;
      }
      if (!_opened) {
        // The context needs the app window — retry until the runner
        // window exists (first frames of app start).
        _opened = bridge.open();
        if (!_opened) {
          return;
        }
      }
      packets = bridge.poll();
    }
    if (packets.isEmpty) {
      return;
    }
    _lastPacketAt = _now();
    latest.value = packets.last;
  }

  /// The driver's CONTACT pressure when the stream is live and fresh —
  /// null tells the caller to use the pointer event's own pressure.
  /// Contact = pressure above zero; hovering pens stream 0 and must not
  /// flatten a real 0-pressure … the caller only asks mid-stroke.
  double? freshContactPressure({DateTime? now}) {
    if (_timer == null) {
      return null;
    }
    final packet = latest.value;
    if (packet == null) {
      return null;
    }
    final age = (now ?? _now()).difference(_lastPacketAt);
    if (age > freshWindow) {
      return null;
    }
    return packet.pressure.clamp(0.0, 1.0);
  }

  /// Test hook: lands one packet as if the poll just delivered it (the
  /// widget-test fake clock never fires the real timer).
  @visibleForTesting
  void debugInjectPacket(QaTabletPacket packet) {
    _lastPacketAt = _now();
    latest.value = packet;
  }

  /// Test hygiene: back to idle + forget listeners.
  @visibleForTesting
  void debugReset() {
    stop();
    if (_settingsListener != null) {
      AppInput.settings.removeListener(_settingsListener!);
      _settingsListener = null;
    }
    debugPollOverride = null;
    debugClockOverride = null;
    _bridge = null;
    _lastPacketAt = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
