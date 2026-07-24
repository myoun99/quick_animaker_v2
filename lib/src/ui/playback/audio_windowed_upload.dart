import '../../native/qa_audio_device.dart';
import '../audio/audio_conform_store.dart';
import 'audio_playback_schedule.dart';

/// Uploads [mix]'s windowed schedule to [device] around [centerSample] through
/// the shared [windowedMixUpload], returning the resulting `hasStreaming` flag
/// — or `null` when nothing was uploaded (no device, an incomplete upload, or
/// the device rejected the schedule), so the caller leaves any old schedule
/// playing.
///
/// The transport and the scrubber both go through here so streamed playback
/// and streamed scrubbing drive the device on identical geometry; each keeps
/// only its own bookkeeping (its `hasStreaming` / window-center fields) around
/// this one call.
bool? uploadWindowedSchedule({
  required QaAudioDevice? device,
  required AudioMixSchedule mix,
  required AudioConformStore conformStore,
  required int deviceRate,
  required int centerSample,
  int backSeconds = 2,
  int aheadSeconds = 30,
}) {
  if (device == null) {
    return null;
  }
  final upload = windowedMixUpload(
    mix: mix,
    conformStore: conformStore,
    deviceRate: deviceRate,
    centerSample: centerSample,
    backSeconds: backSeconds,
    aheadSeconds: aheadSeconds,
  );
  if (upload == null) {
    return null;
  }
  if (!device.setSchedule(clips: upload.clips, sources: upload.sources)) {
    return null;
  }
  return upload.hasStreaming;
}
