import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_layout.dart';

EditorPanelLayoutModel _model() => EditorPanelLayoutModel(
  groups: {
    'left': ['tools', 'brushes', 'camera'],
    'bottom': ['timeline', 'storyboard'],
  },
  activeTabs: {'left': 'brushes', 'bottom': 'timeline'},
);

void main() {
  group('EditorPanelLayoutModel', () {
    test('exposes groups, orders and active tabs', () {
      final model = _model();
      expect(model.tabsIn('left'), ['tools', 'brushes', 'camera']);
      expect(model.tabsIn('bottom'), ['timeline', 'storyboard']);
      expect(model.activeTabIn('left'), 'brushes');
      expect(model.activeTabIn('bottom'), 'timeline');
      expect(model.groupOf('camera'), 'left');
      expect(model.groupOf('storyboard'), 'bottom');
      expect(model.groupOf('unknown'), isNull);
    });

    test('falls back to the first tab when no active tab is given', () {
      final model = EditorPanelLayoutModel(
        groups: {
          'left': ['a', 'b'],
        },
      );
      expect(model.activeTabIn('left'), 'a');
    });

    test('selectTab switches the active tab and notifies', () {
      final model = _model();
      var notified = 0;
      model.addListener(() => notified += 1);

      model.selectTab('left', 'camera');

      expect(model.activeTabIn('left'), 'camera');
      expect(notified, 1);
    });

    test('selectTab ignores unknown tabs and re-selection', () {
      final model = _model();
      var notified = 0;
      model.addListener(() => notified += 1);

      model.selectTab('left', 'storyboard');
      model.selectTab('left', 'brushes');

      expect(model.activeTabIn('left'), 'brushes');
      expect(notified, 0);
    });

    test('same-group move reorders with insertion-index semantics', () {
      final model = _model();

      // Insert 'tools' before 'camera' (index counted pre-removal).
      model.moveTab(tabId: 'tools', toGroupId: 'left', toIndex: 2);

      expect(model.tabsIn('left'), ['brushes', 'tools', 'camera']);
    });

    test('same-group move to end appends', () {
      final model = _model();

      model.moveTab(tabId: 'tools', toGroupId: 'left', toIndex: 3);

      expect(model.tabsIn('left'), ['brushes', 'camera', 'tools']);
    });

    test('same-group move onto its own slot is a silent no-op', () {
      final model = _model();
      var notified = 0;
      model.addListener(() => notified += 1);

      model.moveTab(tabId: 'brushes', toGroupId: 'left', toIndex: 1);
      model.moveTab(tabId: 'brushes', toGroupId: 'left', toIndex: 2);

      expect(model.tabsIn('left'), ['tools', 'brushes', 'camera']);
      expect(notified, 0);
    });

    test('cross-group move activates the moved tab in the target', () {
      final model = _model();

      model.moveTab(tabId: 'camera', toGroupId: 'bottom', toIndex: 1);

      expect(model.tabsIn('left'), ['tools', 'brushes']);
      expect(model.tabsIn('bottom'), ['timeline', 'camera', 'storyboard']);
      expect(model.activeTabIn('bottom'), 'camera');
      expect(model.groupOf('camera'), 'bottom');
    });

    test('moving the active tab out falls back to a neighbour', () {
      final model = _model();
      expect(model.activeTabIn('left'), 'brushes');

      model.moveTab(tabId: 'brushes', toGroupId: 'bottom', toIndex: 0);

      // The element that took the moved tab's index becomes active.
      expect(model.activeTabIn('left'), 'camera');
      expect(model.tabsIn('bottom'), ['brushes', 'timeline', 'storyboard']);
    });

    test('moving the LAST tab of a group empties it', () {
      final model = EditorPanelLayoutModel(
        groups: {
          'left': ['camera'],
          'bottom': ['timeline', 'storyboard'],
        },
      );

      expect(model.canMoveTab(tabId: 'camera', toGroupId: 'bottom'), isTrue);
      model.moveTab(tabId: 'camera', toGroupId: 'bottom', toIndex: 0);

      expect(model.tabsIn('left'), isEmpty);
      expect(model.activeTabIn('left'), isNull);
      expect(model.tabsIn('bottom'), ['camera', 'timeline', 'storyboard']);
      expect(model.activeTabIn('bottom'), 'camera');
    });

    test('a tab can dock into an initially empty group', () {
      final model = EditorPanelLayoutModel(
        groups: {
          'left': ['camera', 'brushes'],
          'right': <String>[],
        },
      );
      expect(model.activeTabIn('right'), isNull);

      model.moveTab(tabId: 'camera', toGroupId: 'right', toIndex: 0);

      expect(model.tabsIn('right'), ['camera']);
      expect(model.activeTabIn('right'), 'camera');
      expect(model.activeTabIn('left'), 'brushes');
    });

    test('unknown tabs or groups cannot move', () {
      final model = _model();
      expect(model.canMoveTab(tabId: 'nope', toGroupId: 'left'), isFalse);
      expect(model.canMoveTab(tabId: 'tools', toGroupId: 'nope'), isFalse);
    });

    test('out-of-range target indices clamp', () {
      final model = _model();

      model.moveTab(tabId: 'tools', toGroupId: 'bottom', toIndex: 99);
      expect(model.tabsIn('bottom'), ['timeline', 'storyboard', 'tools']);

      model.moveTab(tabId: 'camera', toGroupId: 'bottom', toIndex: -5);
      expect(model.tabsIn('bottom'), [
        'camera',
        'timeline',
        'storyboard',
        'tools',
      ]);
    });
  });
}
