/// The paper form's header boxes, in printing order. TITLE and the episode
/// number (話数, printed '#' like the A-1 form) are separate boxes; SCENE is
/// the user-requested addition. Any box can be hidden per project via
/// [TimesheetInfo.hiddenFields].
enum TimesheetHeaderField { title, episode, scene, cut, time, name, sheet }

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
  });

  static const TimesheetInfo empty = TimesheetInfo();

  final String title;
  final String episode;
  final String scene;
  final String artist;

  /// Header boxes the form does NOT print; everything else stays visible.
  final Set<TimesheetHeaderField> hiddenFields;

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
  }) {
    return TimesheetInfo(
      title: title ?? this.title,
      episode: episode ?? this.episode,
      scene: scene ?? this.scene,
      artist: artist ?? this.artist,
      hiddenFields: hiddenFields ?? this.hiddenFields,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'episode': episode,
    'scene': scene,
    'artist': artist,
    'hiddenFields': [for (final field in hiddenFields) field.name],
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
          other.hiddenFields.length == hiddenFields.length &&
          other.hiddenFields.containsAll(hiddenFields);

  @override
  int get hashCode => Object.hash(
    title,
    episode,
    scene,
    artist,
    Object.hashAllUnordered(hiddenFields),
  );

  @override
  String toString() =>
      'TimesheetInfo(title: $title, episode: $episode, scene: $scene, '
      'artist: $artist, hiddenFields: $hiddenFields)';
}
