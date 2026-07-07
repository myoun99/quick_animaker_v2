import 'package:audioplayers/audioplayers.dart' as ap;

import 'audio_playback_sync.dart';

/// Production [AudioClipPlayer] backed by the `audioplayers` plugin (the
/// app's first native plugin — real playback needs a device run, never
/// FLUTTER_TEST). One underlying player per clip; lowLatency mode is for
/// short soundboard assets, SE clips use the default mediaPlayer mode.
class AudioplayersClipPlayer implements AudioClipPlayer {
  final ap.AudioPlayer _player = ap.AudioPlayer();

  @override
  Future<void> play(String filePath, {required Duration position}) {
    return _player.play(ap.DeviceFileSource(filePath), position: position);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
