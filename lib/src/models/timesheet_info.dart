/// The paper form's header boxes, in printing order — the episode number
/// (話数 / Ep.no) leads like the real reference sheets (R7-⑥), then Title,
/// Cut, Duration, Name and Page; SCENE is the user-requested addition
/// slotted after the title. Any box can be hidden per project via
/// [TimesheetInfo.hiddenFields].
enum TimesheetHeaderField { episode, title, scene, cut, time, name, sheet }

/// The sheet-header text the paper timesheet reads: production title
/// (falls back to the project name when empty), episode label (話数),
/// scene label and the artist name (作業者), plus which header boxes the
/// form prints. Project-level — every cut's sheet shares it.
class TimesheetInfo {
  const TimesheetInfo({
    this.title = '',
    this.episode = '',
    this.scene = '',
    this.artist = '',
    this.hiddenFields = const {},
    this.exposureBarThreshold,
    this.seEmptyFill = true,
  });

  static const TimesheetInfo empty = TimesheetInfo();

  /// The industry-standard hold length the exposure bar option suggests.
  static const int defaultExposureBarThreshold = 3;

  final String title;
  final String episode;
  final String scene;
  final String artist;

  /// Header boxes the form does NOT print; everything else stays visible.
  final Set<TimesheetHeaderField> hiddenFields;

  /// The ACTION columns' hold bar ('1 ─ ─ ─' down held rows): null = never
  /// drawn (the default — most sheets leave holds blank); N = drawn only
  /// for exposures held N+ commas, starting from the (N+1)th comma.
  final int? exposureBarThreshold;

  /// Light-gray fill over SE columns' empty stretches (the "no SE here"
  /// wash) — default on, toggleable per project.
  final bool seEmptyFill;

  /// The header boxes the form prints, in printing order.
  List<TimesheetHeaderField> get visibleFields => [
    for (final field in TimesheetHeaderField.values)
      if (!hiddenFields.contains(field)) field,
  ];

  TimesheetInfo copyWith({
    String? title,
    String? episode,
    String? scene,
    String? artist,
    Set<TimesheetHeaderField>? hiddenFields,
    int? Function()? exposureBarThreshold,
    bool? seEmptyFill,
  }) {
    return TimesheetInfo(
      title: title ?? this.title,
      episode: episode ?? this.episode,
      scene: scene ?? this.scene,
      artist: artist ?? this.artist,
      hiddenFields: hiddenFields ?? this.hiddenFields,
      exposureBarThreshold: exposureBarThreshold == null
          ? this.exposureBarThreshold
          : exposureBarThreshold(),
      seEmptyFill: seEmptyFill ?? this.seEmptyFill,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'episode': episode,
    'scene': scene,
    'artist': artist,
    'hiddenFields': [for (final field in hiddenFields) field.name],
    if (exposureBarThreshold != null)
      'exposureBarThreshold': exposureBarThreshold,
    if (!seEmptyFill) 'seEmptyFill': false,
  };

  factory TimesheetInfo.fromJson(Map<String, dynamic> json) {
    return TimesheetInfo(
      title: json['title'] as String? ?? '',
      episode: json['episode'] as String? ?? '',
      scene: json['scene'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      hiddenFields: {
        // Unknown names (from newer files) drop silently.
        for (final name in json['hiddenFields'] as List<dynamic>? ?? const [])
          for (final field in TimesheetHeaderField.values)
            if (field.name == name) field,
      },
      exposureBarThreshold: json['exposureBarThreshold'] as int?,
      seEmptyFill: json['seEmptyFill'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimesheetInfo &&
          other.title == title &&
          other.episode == episode &&
          other.scene == scene &&
          other.artist == artist &&
          other.exposureBarThreshold == exposureBarThreshold &&
          other.seEmptyFill == seEmptyFill &&
          other.hiddenFields.length == hiddenFields.length &&
          other.hiddenFields.containsAll(hiddenFields);

  @override
  int get hashCode => Object.hash(
    title,
    episode,
    scene,
    artist,
    exposureBarThreshold,
    seEmptyFill,
    Object.hashAllUnordered(hiddenFields),
  );

  @override
  String toString() =>
      'TimesheetInfo(title: $title, episode: $episode, scene: $scene, '
      'artist: $artist, hiddenFields: $hiddenFields, '
      'exposureBarThreshold: $exposureBarThreshold, '
      'seEmptyFill: $seEmptyFill)';
}
