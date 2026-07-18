import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/native/qa_tablet_bridge.dart';
import 'package:quick_animaker_v2/src/services/input/wintab_pen_service.dart';
import 'package:quick_animaker_v2/src/ui/input/app_input_settings.dart';

/// PEN-2: the Wintab pressure sidecar — settings model + the polling
/// service against a fake driver stream.
void main() {
  tearDown(() {
    WintabPenService.instance.debugReset();
    AppInput.settings.value = const AppInputSettings(
      touchTimelineScroll: false,
    );
  });

  test('tabletService json round-trips and defaults to standard', () {
    expect(const AppInputSettings().tabletService, TabletService.standard);
    // Old settings files (no field) stay standard.
    expect(
      AppInputSettings.fromJson(const {
        'touchTimelineScroll': true,
      }).tabletService,
      TabletService.standard,
    );
    const wintab = AppInputSettings(tabletService: TabletService.wintab);
    expect(AppInputSettings.fromJson(wintab.toJson()), wintab);
    expect(
      wintab.copyWith(tabletService: TabletService.standard).tabletService,
      TabletService.standard,
    );
  });

  test('the service follows the settings: wintab starts, standard stops', () {
    final service = WintabPenService.instance;
    service.debugPollOverride = () => const [];
    service.bind();
    expect(service.running, isFalse, reason: 'standard = idle');

    AppInput.settings.value = const AppInputSettings(
      tabletService: TabletService.wintab,
    );
    expect(service.running, isTrue);

    AppInput.settings.value = const AppInputSettings();
    expect(service.running, isFalse);
  });

  test('fresh driver pressure overrides; stale or idle yields null', () async {
    final service = WintabPenService.instance;
    var queue = <QaTabletPacket>[];
    service.debugPollOverride = () {
      final drained = queue;
      queue = [];
      return drained;
    };

    expect(service.freshContactPressure(), isNull, reason: 'not running yet');

    service.start();
    queue = const [
      QaTabletPacket(
        pressure: 0.37,
        tiltAzimuthDegrees: 12,
        altitude: 0.8,
        timeMs: 1000,
        buttons: 1,
      ),
      QaTabletPacket(
        pressure: 0.62,
        tiltAzimuthDegrees: 12,
        altitude: 0.8,
        timeMs: 1008,
        buttons: 1,
      ),
    ];
    // One poll tick delivers; the newest packet wins.
    await Future<void>.delayed(WintabPenService.pollInterval * 3);
    expect(service.latest.value?.pressure, 0.62);
    expect(service.freshContactPressure(), 0.62);

    // Beyond the fresh window the override stands down.
    final stale = DateTime.now().add(
      WintabPenService.freshWindow + const Duration(milliseconds: 1),
    );
    expect(service.freshContactPressure(now: stale), isNull);

    service.stop();
    expect(service.latest.value, isNull);
    expect(service.freshContactPressure(), isNull);
  });
}
