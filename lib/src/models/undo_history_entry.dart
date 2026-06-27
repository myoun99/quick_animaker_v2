import 'undo_history_entry_id.dart';
import 'undo_history_entry_kind.dart';
import 'undo_payload_ref.dart';

class UndoHistoryEntry {
  const UndoHistoryEntry({
    required this.id,
    required this.sequenceNumber,
    required this.kind,
    required this.scope,
    required this.payloadRef,
  });

  final UndoHistoryEntryId id;
  final int sequenceNumber;
  final UndoHistoryEntryKind kind;
  final UndoHistoryScope scope;
  final UndoPayloadRef payloadRef;

  bool get isPaintPayload => payloadRef.isPaintCommand;
}
