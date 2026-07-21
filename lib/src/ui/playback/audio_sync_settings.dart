/// Audio/video sync settings (audio program 2D).
///
/// The program guarantees that sound and picture never DRIFT — the clock
/// is the samples handed to the device, so cumulative error is structurally
/// zero. What it cannot remove is the constant ABSOLUTE latency of the two
/// pipelines: the screen has its own, the audio device reports part of its
/// own, and anything past a wireless hop or an AV receiver reports nothing
/// at all.
///
/// So the correction is in two layers, which is exactly what professional
/// tools do:
///
/// 1. the device's REPORTED latency, applied automatically;
/// 2. this — the residual, as a number the user sets once for their rig.
///
/// Pretending layer 2 is unnecessary would be the dishonest move. Bluetooth
/// headphones can sit 150–300 ms behind and tell nobody.
library;

/// How the offset is expressed to the user.
///
/// Milliseconds are the unit hardware is specified in; frames are the unit
/// an animator thinks in. Storing the unit alongside the value means the
/// number they typed is the number they see, rather than one that has been
/// round-tripped through a conversion.
enum AvOffsetUnit { milliseconds, frames }

/// A user's A/V offset.
///
/// Positive = the picture is shown LATER (used when sound arrives late,
/// the common case with wireless output). Negative pulls it earlier.
class AudioSyncSettings {
  const AudioSyncSettings({
    this.offset = 0,
    this.unit = AvOffsetUnit.milliseconds,
    this.outputDeviceName,
    this.inputDeviceName,
  });

  static const AudioSyncSettings defaults = AudioSyncSettings();

  /// Clamped to a range wide enough for any real rig (±500 ms, or ±12
  /// frames at 24fps) and no wider — a value past that is a typo, not a
  /// setup, and silently accepting it would look like a sync bug.
  static const int maxMilliseconds = 500;
  static const int maxFrames = 60;

  final int offset;
  final AvOffsetUnit unit;

  /// The chosen output/input device, by NAME (AUDIO-PRO R4); null = the
  /// system default. Names, not indexes: indexes shuffle when hardware
  /// replugs, and a missing name falls back to the default at open time
  /// rather than opening the wrong speaker.
  final String? outputDeviceName;
  final String? inputDeviceName;

  static const Object _unset = Object();

  AudioSyncSettings copyWith({
    int? offset,
    AvOffsetUnit? unit,
    Object? outputDeviceName = _unset,
    Object? inputDeviceName = _unset,
  }) => AudioSyncSettings(
    offset: offset ?? this.offset,
    unit: unit ?? this.unit,
    outputDeviceName: identical(outputDeviceName, _unset)
        ? this.outputDeviceName
        : outputDeviceName as String?,
    inputDeviceName: identical(inputDeviceName, _unset)
        ? this.inputDeviceName
        : inputDeviceName as String?,
  );

  /// The offset in samples at [sampleRate], which is what the clock adds.
  ///
  /// Integer arithmetic, like every other conversion in this program: the
  /// frame path multiplies before dividing so a 23.976 project does not
  /// lose the fraction.
  int offsetSamples({
    required int sampleRate,
    required int frameRateNumerator,
    required int frameRateDenominator,
  }) {
    if (sampleRate <= 0) {
      return 0;
    }
    switch (unit) {
      case AvOffsetUnit.milliseconds:
        return offset * sampleRate ~/ 1000;
      case AvOffsetUnit.frames:
        if (frameRateNumerator <= 0 || frameRateDenominator <= 0) {
          return 0;
        }
        return offset * sampleRate * frameRateDenominator ~/ frameRateNumerator;
    }
  }

  /// The offset in milliseconds, for display beside a frame-based value.
  int offsetMilliseconds({
    required int frameRateNumerator,
    required int frameRateDenominator,
  }) {
    switch (unit) {
      case AvOffsetUnit.milliseconds:
        return offset;
      case AvOffsetUnit.frames:
        if (frameRateNumerator <= 0 || frameRateDenominator <= 0) {
          return 0;
        }
        return offset * 1000 * frameRateDenominator ~/ frameRateNumerator;
    }
  }

  static int clampOffset(int value, AvOffsetUnit unit) {
    final limit = unit == AvOffsetUnit.milliseconds
        ? maxMilliseconds
        : maxFrames;
    if (value > limit) {
      return limit;
    }
    if (value < -limit) {
      return -limit;
    }
    return value;
  }

  Map<String, dynamic> toJson() => {
    'avOffset': offset,
    'avOffsetUnit': unit.name,
    if (outputDeviceName != null) 'outputDevice': outputDeviceName,
    if (inputDeviceName != null) 'inputDevice': inputDeviceName,
  };

  factory AudioSyncSettings.fromJson(Map<String, dynamic> json) {
    final unit = AvOffsetUnit.values.firstWhere(
      (candidate) => candidate.name == json['avOffsetUnit'],
      orElse: () => AvOffsetUnit.milliseconds,
    );
    return AudioSyncSettings(
      offset: clampOffset((json['avOffset'] as num?)?.toInt() ?? 0, unit),
      unit: unit,
      outputDeviceName: json['outputDevice'] as String?,
      inputDeviceName: json['inputDevice'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSyncSettings &&
          other.offset == offset &&
          other.unit == unit &&
          other.outputDeviceName == outputDeviceName &&
          other.inputDeviceName == inputDeviceName;

  @override
  int get hashCode =>
      Object.hash(offset, unit, outputDeviceName, inputDeviceName);

  @override
  String toString() =>
      'AudioSyncSettings(offset: $offset, unit: ${unit.name}, '
      'outputDevice: $outputDeviceName, inputDevice: $inputDeviceName)';
}

/// What the sync inspector shows (audio program 2D).
///
/// The inspector exists because "the sound is late" is not something to
/// argue about — it is something to read off. Every number here comes from
/// the device or from arithmetic already pinned by tests, so a report from
/// a real machine is evidence rather than an impression.
///
/// The residual is the honest part: it is what remains AFTER the automatic
/// correction, and it is the number the user's offset is meant to zero.
class AudioSyncReport {
  const AudioSyncReport({
    required this.deviceOpen,
    this.deviceSampleRate = 0,
    this.deviceChannels = 0,
    this.reportedLatencySamples = 0,
    this.userOffsetSamples = 0,
    this.positionSamples = 0,
    this.frameRateNumerator = 0,
    this.frameRateDenominator = 1,
  });

  final bool deviceOpen;
  final int deviceSampleRate;
  final int deviceChannels;

  /// What the device says its output buffer costs.
  final int reportedLatencySamples;

  /// The user's residual correction, already in samples.
  final int userOffsetSamples;

  /// Samples handed to the device — the clock itself.
  final int positionSamples;

  final int frameRateNumerator;
  final int frameRateDenominator;

  int _toMillis(int samples) =>
      deviceSampleRate <= 0 ? 0 : samples * 1000 ~/ deviceSampleRate;

  int get reportedLatencyMillis => _toMillis(reportedLatencySamples);
  int get userOffsetMillis => _toMillis(userOffsetSamples);

  /// The total shift applied to the picture, in samples and in
  /// milliseconds — automatic correction plus the user's residual.
  int get appliedOffsetSamples => -reportedLatencySamples + userOffsetSamples;
  int get appliedOffsetMillis => _toMillis(appliedOffsetSamples);

  /// The same shift as a fraction of a frame, which is the unit that
  /// decides whether anyone can SEE it. Under one frame is invisible;
  /// that is the bar the automatic correction has to clear on its own.
  double get appliedOffsetFrames {
    if (deviceSampleRate <= 0 ||
        frameRateNumerator <= 0 ||
        frameRateDenominator <= 0) {
      return 0;
    }
    final samplesPerFrame =
        deviceSampleRate * frameRateDenominator / frameRateNumerator;
    return samplesPerFrame == 0 ? 0 : appliedOffsetSamples / samplesPerFrame;
  }

  /// One line for a log or a bug report — the whole point of the
  /// inspector is that this can be pasted somewhere.
  String get summary {
    if (!deviceOpen) {
      return 'audio device: not open (playback falls back to the platform '
          'player)';
    }
    final frames = appliedOffsetFrames.toStringAsFixed(2);
    return 'audio device: ${deviceSampleRate}Hz ${deviceChannels}ch · '
        'reported latency ${reportedLatencyMillis}ms · '
        'user offset ${userOffsetMillis}ms · '
        'picture shifted ${appliedOffsetMillis}ms ($frames frames)';
  }
}
