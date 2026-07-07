/// The sheet-header text the paper timesheet reads: production title
/// (falls back to the project name when empty), episode label (話数) and
/// the artist name (作業者). Project-level — every cut's sheet shares it.
class TimesheetInfo {
  const TimesheetInfo({this.title = '', this.episode = '', this.artist = ''});

  static const TimesheetInfo empty = TimesheetInfo();

  final String title;
  final String episode;
  final String artist;

  TimesheetInfo copyWith({String? title, String? episode, String? artist}) {
    return TimesheetInfo(
      title: title ?? this.title,
      episode: episode ?? this.episode,
      artist: artist ?? this.artist,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'episode': episode,
    'artist': artist,
  };

  factory TimesheetInfo.fromJson(Map<String, dynamic> json) {
    return TimesheetInfo(
      title: json['title'] as String? ?? '',
      episode: json['episode'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimesheetInfo &&
          other.title == title &&
          other.episode == episode &&
          other.artist == artist;

  @override
  int get hashCode => Object.hash(title, episode, artist);

  @override
  String toString() =>
      'TimesheetInfo(title: $title, episode: $episode, artist: $artist)';
}
