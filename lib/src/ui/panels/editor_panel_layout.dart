import 'package:flutter/foundation.dart';

/// One stacked region inside a dock: a tab group with its own strip.
class DockSection {
  DockSection({required List<String> tabs, String? activeTabId})
    : _tabs = List.of(tabs),
      _activeTabId = tabs.contains(activeTabId) ? activeTabId! : tabs.first,
      assert(tabs.isNotEmpty);

  final List<String> _tabs;
  String _activeTabId;

  List<String> get tabs => List.unmodifiable(_tabs);
  String get activeTabId => _activeTabId;
}

/// Where a tab currently lives.
typedef DockTabLocation = ({String dockId, int sectionIndex, int tabIndex});

/// Which panel tabs live in which dock, stacked into SECTIONS (panel below
/// panel — each section is a tab group with its own strip), in what order,
/// and which tab is active per section. This is pure layout state — the
/// panel definitions (label/icon/content) stay with the workspace that owns
/// the panels.
///
/// Docks may be empty (no sections); the dock UI renders an empty dock as a
/// collapsed drop rail so tabs can still be dragged back. Sections are
/// never empty — removing a section's last tab removes the section.
class EditorPanelLayoutModel extends ChangeNotifier {
  EditorPanelLayoutModel({required Map<String, List<DockSection>> docks})
    : _docks = {
        for (final entry in docks.entries) entry.key: List.of(entry.value),
      };

  final Map<String, List<DockSection>> _docks;

  Iterable<String> get dockIds => _docks.keys;

  List<DockSection> sectionsIn(String dockId) =>
      List.unmodifiable(_docks[dockId] ?? const <DockSection>[]);

  /// The dock/section/tab position of a tab; null for unknown ids.
  DockTabLocation? locateTab(String tabId) {
    for (final entry in _docks.entries) {
      for (var s = 0; s < entry.value.length; s += 1) {
        final t = entry.value[s]._tabs.indexOf(tabId);
        if (t >= 0) {
          return (dockId: entry.key, sectionIndex: s, tabIndex: t);
        }
      }
    }
    return null;
  }

  /// The active tab of every section in every dock, for visibility checks.
  Iterable<String> get activeTabs sync* {
    for (final sections in _docks.values) {
      for (final section in sections) {
        yield section._activeTabId;
      }
    }
  }

  void selectTab(String dockId, int sectionIndex, String tabId) {
    final sections = _docks[dockId];
    if (sections == null ||
        sectionIndex < 0 ||
        sectionIndex >= sections.length) {
      return;
    }
    final section = sections[sectionIndex];
    if (!section._tabs.contains(tabId) || section._activeTabId == tabId) {
      return;
    }
    section._activeTabId = tabId;
    notifyListeners();
  }

  /// Whether a tab may be dropped into [toDockId]: any known tab may move
  /// to any known dock (panels dock anywhere; an emptied dock collapses).
  bool canMoveTab({required String tabId, required String toDockId}) {
    return locateTab(tabId) != null && _docks.containsKey(toDockId);
  }

  /// Moves a tab into an EXISTING section at [insertIndex] (insertion index
  /// counted in the target section's tabs BEFORE the tab is removed from
  /// its current position). The moved tab becomes the section's active tab.
  void moveTabToSection({
    required String tabId,
    required String toDockId,
    required int toSectionIndex,
    required int insertIndex,
  }) {
    final from = locateTab(tabId);
    final targetSections = _docks[toDockId];
    if (from == null ||
        targetSections == null ||
        toSectionIndex < 0 ||
        toSectionIndex >= targetSections.length) {
      return;
    }
    final sourceSection = _docks[from.dockId]![from.sectionIndex];
    final targetSection = targetSections[toSectionIndex];

    if (identical(sourceSection, targetSection)) {
      var index = insertIndex.clamp(0, sourceSection._tabs.length);
      if (index > from.tabIndex) {
        index -= 1;
      }
      if (index == from.tabIndex) {
        return;
      }
      sourceSection._tabs
        ..removeAt(from.tabIndex)
        ..insert(index, tabId);
      notifyListeners();
      return;
    }

    // Removing the source tab may drop its whole section, shifting the
    // TARGET section index when both live in the same dock.
    var targetIndex = toSectionIndex;
    final removedSection = _removeTab(from);
    if (removedSection &&
        from.dockId == toDockId &&
        from.sectionIndex < targetIndex) {
      targetIndex -= 1;
    }
    final target = _docks[toDockId]![targetIndex];
    target._tabs.insert(insertIndex.clamp(0, target._tabs.length), tabId);
    target._activeTabId = tabId;
    notifyListeners();
  }

  /// Moves a tab into a NEW section of its own at [atSectionIndex]
  /// (insertion position in the dock's section stack, counted BEFORE the
  /// tab is removed from its current position) — panel below panel.
  void moveTabToNewSection({
    required String tabId,
    required String toDockId,
    required int atSectionIndex,
  }) {
    final from = locateTab(tabId);
    final targetSections = _docks[toDockId];
    if (from == null || targetSections == null) {
      return;
    }
    // Lifting a lone-section tab next to its own slot rebuilds the same
    // stack — skip the phantom mutation.
    if (from.dockId == toDockId &&
        _docks[toDockId]![from.sectionIndex]._tabs.length == 1 &&
        (atSectionIndex == from.sectionIndex ||
            atSectionIndex == from.sectionIndex + 1)) {
      return;
    }

    var targetIndex = atSectionIndex;
    final removedSection = _removeTab(from);
    if (removedSection &&
        from.dockId == toDockId &&
        from.sectionIndex < targetIndex) {
      targetIndex -= 1;
    }
    final sections = _docks[toDockId]!;
    sections.insert(
      targetIndex.clamp(0, sections.length),
      DockSection(tabs: [tabId]),
    );
    notifyListeners();
  }

  /// Removes a tab from its location; empty sections are dropped. Returns
  /// whether the whole section was removed.
  bool _removeTab(DockTabLocation from) {
    final sections = _docks[from.dockId]!;
    final section = sections[from.sectionIndex];
    section._tabs.removeAt(from.tabIndex);
    if (section._tabs.isEmpty) {
      sections.removeAt(from.sectionIndex);
      return true;
    }
    // If the moved tab was the section's active one, fall back to the
    // nearest remaining neighbour.
    if (!section._tabs.contains(section._activeTabId)) {
      section._activeTabId =
          section._tabs[from.tabIndex.clamp(0, section._tabs.length - 1)];
    }
    return false;
  }
}
