import 'package:flutter/foundation.dart';

/// Which panel tabs live in which dock group, in what order, and which one
/// is active per group. This is pure layout state — the panel definitions
/// (label/icon/content) stay with the workspace that owns the panels.
///
/// Groups may be empty ([activeTabIn] is null then); the dock UI renders an
/// empty group as a collapsed drop rail so tabs can still be dragged back.
class EditorPanelLayoutModel extends ChangeNotifier {
  EditorPanelLayoutModel({
    required Map<String, List<String>> groups,
    Map<String, String> activeTabs = const <String, String>{},
  }) : _groups = {
         for (final entry in groups.entries) entry.key: List.of(entry.value),
       },
       _activeTabs = {
         for (final entry in groups.entries)
           if (entry.value.isNotEmpty)
             entry.key: entry.value.contains(activeTabs[entry.key])
                 ? activeTabs[entry.key]!
                 : entry.value.first,
       };

  final Map<String, List<String>> _groups;
  final Map<String, String> _activeTabs;

  Iterable<String> get groupIds => _groups.keys;

  List<String> tabsIn(String groupId) =>
      List.unmodifiable(_groups[groupId] ?? const <String>[]);

  /// The active tab of a group; null for empty groups and unknown ids.
  String? activeTabIn(String groupId) => _activeTabs[groupId];

  /// The group currently holding a tab; null for unknown tab ids.
  String? groupOf(String tabId) {
    for (final entry in _groups.entries) {
      if (entry.value.contains(tabId)) {
        return entry.key;
      }
    }
    return null;
  }

  void selectTab(String groupId, String tabId) {
    final tabs = _groups[groupId];
    if (tabs == null || !tabs.contains(tabId)) {
      return;
    }
    if (_activeTabs[groupId] == tabId) {
      return;
    }
    _activeTabs[groupId] = tabId;
    notifyListeners();
  }

  /// Whether a tab may be dropped into [toGroupId]: any known tab may move
  /// to any known group (panels dock anywhere; an emptied group collapses).
  bool canMoveTab({required String tabId, required String toGroupId}) {
    return groupOf(tabId) != null && _groups.containsKey(toGroupId);
  }

  /// Moves a tab to [toIndex] in [toGroupId] (insertion index counted in the
  /// target group BEFORE the tab is removed from its current position).
  /// A moved tab becomes the target group's active tab; the source group's
  /// active tab falls back to the nearest remaining neighbour.
  void moveTab({
    required String tabId,
    required String toGroupId,
    required int toIndex,
  }) {
    if (!canMoveTab(tabId: tabId, toGroupId: toGroupId)) {
      return;
    }
    final fromGroupId = groupOf(tabId)!;
    final source = _groups[fromGroupId]!;
    final oldIndex = source.indexOf(tabId);

    if (fromGroupId == toGroupId) {
      var insertIndex = toIndex.clamp(0, source.length);
      if (insertIndex > oldIndex) {
        insertIndex -= 1;
      }
      if (insertIndex == oldIndex) {
        return;
      }
      source
        ..removeAt(oldIndex)
        ..insert(insertIndex, tabId);
      notifyListeners();
      return;
    }

    source.removeAt(oldIndex);
    if (_activeTabs[fromGroupId] == tabId) {
      if (source.isEmpty) {
        _activeTabs.remove(fromGroupId);
      } else {
        _activeTabs[fromGroupId] = source[oldIndex.clamp(0, source.length - 1)];
      }
    }
    final target = _groups[toGroupId]!;
    target.insert(toIndex.clamp(0, target.length), tabId);
    _activeTabs[toGroupId] = tabId;
    notifyListeners();
  }
}
