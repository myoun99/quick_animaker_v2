import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/folder_id.dart';
import 'package:quick_animaker_v2/src/models/layer_folder.dart';

void main() {
  LayerFolder folder(String id, {String? parent, bool collapsed = false}) =>
      LayerFolder(
        id: FolderId(id),
        name: id,
        parentId: parent == null ? null : FolderId(parent),
        collapsed: collapsed,
      );

  group('LayerFolder', () {
    test('toJson/fromJson round-trips (defaults omitted)', () {
      final plain = folder('a');
      expect(LayerFolder.fromJson(plain.toJson()), plain);
      expect(plain.toJson().containsKey('parentId'), isFalse);
      expect(plain.toJson().containsKey('collapsed'), isFalse);

      final nested = LayerFolder(
        id: const FolderId('b'),
        name: 'B',
        parentId: const FolderId('a'),
        collapsed: true,
        isVisible: false,
        opacity: 0.5,
      );
      expect(LayerFolder.fromJson(nested.toJson()), nested);
    });

    test('copyWith can clear parentId (move to top level)', () {
      final nested = folder('b', parent: 'a');
      expect(nested.copyWith(parentId: null).parentId, isNull);
      expect(nested.copyWith(name: 'B2').parentId, const FolderId('a'));
    });
  });

  group('folder table queries', () {
    final table = [
      folder('root'),
      folder('child', parent: 'root', collapsed: true),
      folder('grandchild', parent: 'child'),
    ];

    test('ancestryOf walks to the top, nearest first', () {
      expect(
        table.ancestryOf(const FolderId('grandchild')).map((f) => f.id.value),
        ['grandchild', 'child', 'root'],
      );
      expect(table.ancestryOf(null), isEmpty);
    });

    test('subtreeCollapsed sees any collapsed ancestor', () {
      expect(table.subtreeCollapsed(const FolderId('grandchild')), isTrue);
      expect(table.subtreeCollapsed(const FolderId('root')), isFalse);
    });

    test('subtreeVisible: a hidden ancestor hides the subtree', () {
      final withHidden = [
        folder('root').copyWith(isVisible: false),
        folder('child', parent: 'root'),
      ];
      expect(withHidden.subtreeVisible(const FolderId('child')), isFalse);
    });
  });

  group('folderStructureProblem', () {
    test('sound structures pass', () {
      final folders = [folder('a'), folder('b', parent: 'a')];
      expect(
        folderStructureProblem(
          folders: folders,
          layerFolderIdsInStackOrder: [
            null,
            const FolderId('a'),
            const FolderId('b'),
            const FolderId('a'),
            null,
          ],
        ),
        isNull,
        reason:
            'members of a (including nested b) form one unbroken run in '
            'the stack',
      );
    });

    test('a non-contiguous folder run is reported', () {
      expect(
        folderStructureProblem(
          folders: [folder('a')],
          layerFolderIdsInStackOrder: [
            const FolderId('a'),
            null,
            const FolderId('a'),
          ],
        ),
        contains('not contiguous'),
      );
    });

    test('a missing folder reference is reported', () {
      expect(
        folderStructureProblem(
          folders: const [],
          layerFolderIdsInStackOrder: [const FolderId('ghost')],
        ),
        contains('missing folder'),
      );
    });

    test('a cyclic parent chain is reported', () {
      final cyclic = [folder('a', parent: 'b'), folder('b', parent: 'a')];
      expect(
        folderStructureProblem(
          folders: cyclic,
          layerFolderIdsInStackOrder: const [],
        ),
        contains('cyclic'),
      );
    });
  });
}
