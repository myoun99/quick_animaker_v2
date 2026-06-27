import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_id.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/models/undo_history_entry.dart';
import 'package:quick_animaker_v2/src/models/undo_history_entry_id.dart';
import 'package:quick_animaker_v2/src/models/undo_history_entry_kind.dart';
import 'package:quick_animaker_v2/src/models/undo_payload_ref.dart';
import 'package:quick_animaker_v2/src/models/unified_undo_history.dart';

void main() {
  final frameKey = BrushFrameKey(
    projectId: ProjectId('project'),
    trackId: TrackId('track'),
    cutId: CutId('cut'),
    layerId: LayerId('layer'),
    frameId: FrameId('frame'),
  );

  UndoHistoryEntry entry(int sequence, UndoHistoryEntryKind kind, UndoHistoryScope scope) {
    return UndoHistoryEntry(
      id: UndoHistoryEntryId('entry-$sequence'),
      sequenceNumber: sequence,
      kind: kind,
      scope: scope,
      payloadRef: scope == UndoHistoryScope.brushFrame
          ? UndoPayloadRef.paintCommand(
              frameKey: frameKey,
              paintCommandId: BrushPaintCommandId('paint-$sequence'),
            )
          : UndoPayloadRef(
              storeName: '${scope.name}Store',
              payloadId: 'payload-$sequence',
              targetPath: scope.name,
            ),
    );
  }

  test('mixed entries undo in exact global reverse order', () {
    var history = UnifiedUndoHistory(userUndoLimit: 10);
    final entries = [
      entry(1, UndoHistoryEntryKind.paintStroke, UndoHistoryScope.brushFrame),
      entry(2, UndoHistoryEntryKind.renameLayer, UndoHistoryScope.layer),
      entry(3, UndoHistoryEntryKind.paintStroke, UndoHistoryScope.brushFrame),
      entry(4, UndoHistoryEntryKind.changeCutDuration, UndoHistoryScope.timeline),
    ];
    for (final item in entries) {
      history = history.pushNewEntry(item).history;
    }

    final undone = <int>[];
    for (var i = 0; i < entries.length; i += 1) {
      final result = history.takeUndo();
      undone.add(result.entry!.sequenceNumber);
      history = result.history;
    }

    expect(undone, [4, 3, 2, 1]);
  });

  test('redo restores same order after undo', () {
    var history = UnifiedUndoHistory(userUndoLimit: 10);
    for (final item in [entry(1, UndoHistoryEntryKind.paintStroke, UndoHistoryScope.brushFrame), entry(2, UndoHistoryEntryKind.createLayer, UndoHistoryScope.layer)]) {
      history = history.pushNewEntry(item).history;
    }
    history = history.takeUndo().history;
    history = history.takeUndo().history;

    final firstRedo = history.takeRedo();
    final secondRedo = firstRedo.history.takeRedo();

    expect([firstRedo.entry!.sequenceNumber, secondRedo.entry!.sequenceNumber], [1, 2]);
  });

  test('pushNewEntry clears redoStack', () {
    var history = UnifiedUndoHistory(userUndoLimit: 10);
    history = history.pushNewEntry(entry(1, UndoHistoryEntryKind.paintStroke, UndoHistoryScope.brushFrame)).history;
    history = history.pushNewEntry(entry(2, UndoHistoryEntryKind.paintStroke, UndoHistoryScope.brushFrame)).history;
    history = history.takeUndo().history;

    final result = history.pushNewEntry(entry(3, UndoHistoryEntryKind.createCut, UndoHistoryScope.cut));

    expect(result.history.redoStack, isEmpty);
  });

  test('userUndoLimit trims oldest entries and returns them', () {
    var history = UnifiedUndoHistory(userUndoLimit: 3);
    var trimmed = <UndoHistoryEntry>[];
    for (var i = 1; i <= 5; i += 1) {
      final result = history.pushNewEntry(entry(i, UndoHistoryEntryKind.paintStroke, UndoHistoryScope.brushFrame));
      history = result.history;
      trimmed.addAll(result.trimmedEntries);
    }

    expect(trimmed.map((item) => item.sequenceNumber), [1, 2]);
    expect(history.undoStack.map((item) => item.sequenceNumber), [3, 4, 5]);
  });
}
