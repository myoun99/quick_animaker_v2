import 'dart:io';
import 'dart:typed_data';

/// Windowed access to a conform WAV on disk (AUDIO-PRO R6).
///
/// A resident conform costs 4 bytes per sample per channel — 23 MB per
/// stereo minute, which on a tablet turns one long dialogue track into
/// the app's whole memory budget. Past a length threshold the PCM stays
/// on disk and playback reads a sliding WINDOW of it; this reader is the
/// disk half of that.
///
/// Reads are synchronous and run on the CONTROL side (the schedule
/// refresh), never the audio callback — the realtime thread only ever
/// touches memory the C side already owns. A window read is a seek plus
/// one contiguous read (int16 → float32), a few milliseconds for tens of
/// seconds of audio.
///
/// The chunk walk mirrors [decodeConformWav]: order not assumed, unknown
/// chunks skipped. Only the header is parsed at open; the data chunk is
/// left on disk.
class ConformWavStreamReader {
  ConformWavStreamReader._(
    this._file,
    this.channels,
    this.sampleRate,
    this.length,
    this._dataStart,
  );

  final RandomAccessFile _file;

  final int channels;
  final int sampleRate;

  /// Samples per channel in the data chunk.
  final int length;

  /// Byte offset of the first data sample.
  final int _dataStart;

  static const int _riff = 0x46464952; // 'RIFF'
  static const int _wave = 0x45564157; // 'WAVE'
  static const int _fmt = 0x20746d66; // 'fmt '
  static const int _data = 0x61746164; // 'data'

  /// Opens [path] and parses the header, or returns null when the file is
  /// not a 16-bit PCM WAV this project writes — a caller falling back to
  /// the resident path, never a crash.
  static ConformWavStreamReader? open(String path) {
    RandomAccessFile? file;
    try {
      file = File(path).openSync();
      final fileLength = file.lengthSync();
      if (fileLength < 44) {
        file.closeSync();
        return null;
      }
      final head = file.readSync(12);
      final headView = ByteData.view(
        head.buffer,
        head.offsetInBytes,
        head.length,
      );
      if (head.length < 12 ||
          headView.getUint32(0, Endian.little) != _riff ||
          headView.getUint32(8, Endian.little) != _wave) {
        file.closeSync();
        return null;
      }

      int? channels;
      int? sampleRate;
      int? bitsPerSample;
      int? dataStart;
      int? dataBytes;
      var offset = 12;
      while (offset + 8 <= fileLength) {
        file.setPositionSync(offset);
        final header = file.readSync(8);
        if (header.length < 8) {
          break;
        }
        final view = ByteData.view(
          header.buffer,
          header.offsetInBytes,
          header.length,
        );
        final id = view.getUint32(0, Endian.little);
        final size = view.getUint32(4, Endian.little);
        final body = offset + 8;
        if (body + size > fileLength) {
          break;
        }
        if (id == _fmt && size >= 16) {
          final fmt = file.readSync(16);
          final fmtView = ByteData.view(
            fmt.buffer,
            fmt.offsetInBytes,
            fmt.length,
          );
          channels = fmtView.getUint16(2, Endian.little);
          sampleRate = fmtView.getUint32(4, Endian.little);
          bitsPerSample = fmtView.getUint16(14, Endian.little);
        } else if (id == _data) {
          dataStart = body;
          dataBytes = size;
        }
        offset = body + size + (size.isOdd ? 1 : 0);
      }

      if (channels == null ||
          channels <= 0 ||
          sampleRate == null ||
          sampleRate <= 0 ||
          bitsPerSample != 16 ||
          dataStart == null ||
          dataBytes == null) {
        file.closeSync();
        return null;
      }
      return ConformWavStreamReader._(
        file,
        channels,
        sampleRate,
        dataBytes ~/ (2 * channels),
        dataStart,
      );
    } on Object {
      try {
        file?.closeSync();
      } on Object {
        // Already as closed as it gets.
      }
      return null;
    }
  }

  /// Reads [sampleCount] samples per channel starting at [startSample],
  /// interleaved float32. The window is CLAMPED into the file; asking past
  /// either end yields the samples that exist (possibly empty) — the
  /// schedule's source_start/length describe what came back.
  ///
  /// The int16 → float32 scale is 32768, matching [decodeConformWav]
  /// exactly: the same audio must never land at two levels depending on
  /// whether it streamed or sat resident.
  ({int startSample, Float32List samples}) readWindow(
    int startSample,
    int sampleCount,
  ) {
    var start = startSample;
    if (start < 0) {
      start = 0;
    }
    if (start > length) {
      start = length;
    }
    var count = sampleCount;
    if (count < 0) {
      count = 0;
    }
    if (start + count > length) {
      count = length - start;
    }
    if (count == 0) {
      return (startSample: start, samples: Float32List(0));
    }
    try {
      _file.setPositionSync(_dataStart + start * 2 * channels);
      final bytes = _file.readSync(count * 2 * channels);
      final got = bytes.length ~/ (2 * channels);
      final view = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        got * 2 * channels,
      );
      final samples = Float32List(got * channels);
      for (var index = 0; index < samples.length; index += 1) {
        samples[index] = view.getInt16(index * 2, Endian.little) / 32768.0;
      }
      return (startSample: start, samples: samples);
    } on Object {
      // A failed read (file replaced mid-run, drive gone) degrades to
      // silence for this window; the next refresh tries again.
      return (startSample: start, samples: Float32List(0));
    }
  }

  void close() {
    try {
      _file.closeSync();
    } on Object {
      // Double-close and platform quirks are not worth surfacing.
    }
  }
}
