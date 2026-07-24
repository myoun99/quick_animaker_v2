import 'package:flutter/foundation.dart';

/// Workspace surface colors the USER picks (R28 #9) — app state, not
/// project data.
///
/// The canvas paper belongs to the PROJECT (it is part of the artwork and
/// goes out in exports, so it rides `Project.background`). The
/// PASTEBOARD, the area around the stage, is a working environment: it
/// never renders anywhere but the editor, so it lives here and stays put
/// across projects. That split is the user's decision (07-23).
class AppWorkspaceColors {
  const AppWorkspaceColors({this.pasteboardArgb = defaultPasteboardArgb});

  /// The backdrop the stage floats on. The historical editor grey.
  static const int defaultPasteboardArgb = 0xFF2B2F33;

  final int pasteboardArgb;

  AppWorkspaceColors copyWith({int? pasteboardArgb}) =>
      AppWorkspaceColors(pasteboardArgb: pasteboardArgb ?? this.pasteboardArgb);

  Map<String, dynamic> toJson() => {'pasteboardArgb': pasteboardArgb};

  factory AppWorkspaceColors.fromJson(Map<String, dynamic> json) =>
      AppWorkspaceColors(
        pasteboardArgb:
            json['pasteboardArgb'] as int? ?? defaultPasteboardArgb,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppWorkspaceColors && other.pasteboardArgb == pasteboardArgb;

  @override
  int get hashCode => pasteboardArgb.hashCode;

  /// The LIVE app-wide value (the accents' idiom): the editor reads it
  /// directly and the session restores/persists it.
  static final ValueNotifier<AppWorkspaceColors> settings =
      ValueNotifier<AppWorkspaceColors>(const AppWorkspaceColors());
}
