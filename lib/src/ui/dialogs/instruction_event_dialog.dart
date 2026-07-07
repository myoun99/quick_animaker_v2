import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../timeline/instruction_icon_palette.dart';

/// What the instruction event dialog resolved to: an event to apply, a
/// deletion, or (when the user edited the vocabulary meanwhile) the edited
/// instruction set rides along so the caller commits both.
class InstructionEventDialogResult {
  const InstructionEventDialogResult({
    this.instructionId,
    this.text,
    this.valueA,
    this.valueB,
    this.delete = false,
  });

  final String? instructionId;

  /// Free per-event text (independent of the mark); empty → vocabulary
  /// name fallback.
  final String? text;
  final String? valueA;
  final String? valueB;
  final bool delete;
}

/// Picks an instruction (from the project vocabulary) and its A → B
/// endpoint values for one event. Editing an existing event offers Delete.
class InstructionEventDialog extends StatefulWidget {
  const InstructionEventDialog({
    super.key,
    required this.instructionSet,
    this.initialInstructionId,
    this.initialText,
    this.initialValueA,
    this.initialValueB,
    this.editing = false,
    this.onEditInstructionSet,
  });

  final CameraInstructionSet instructionSet;
  final String? initialInstructionId;
  final String? initialText;
  final String? initialValueA;
  final String? initialValueB;

  /// Whether an existing event is being edited (shows Delete).
  final bool editing;

  /// Opens the vocabulary editor; the host owns the flow so the edited set
  /// commits through the session even when this dialog is cancelled.
  final VoidCallback? onEditInstructionSet;

  @override
  State<InstructionEventDialog> createState() => _InstructionEventDialogState();
}

class _InstructionEventDialogState extends State<InstructionEventDialog> {
  late String? _instructionId =
      widget.initialInstructionId ??
      (widget.instructionSet.defs.isEmpty
          ? null
          : widget.instructionSet.defs.first.id);
  late final TextEditingController _textController = TextEditingController(
    text: widget.initialText ?? '',
  );
  late final TextEditingController _valueAController = TextEditingController(
    text: widget.initialValueA ?? '',
  );
  late final TextEditingController _valueBController = TextEditingController(
    text: widget.initialValueB ?? '',
  );

  @override
  void dispose() {
    _textController.dispose();
    _valueAController.dispose();
    _valueBController.dispose();
    super.dispose();
  }

  void _submit() {
    final instructionId = _instructionId;
    if (instructionId == null) {
      return;
    }
    final text = _textController.text.trim();
    final valueA = _valueAController.text.trim();
    final valueB = _valueBController.text.trim();
    Navigator.of(context).pop(
      InstructionEventDialogResult(
        instructionId: instructionId,
        text: text.isEmpty ? null : text,
        valueA: valueA.isEmpty ? null : valueA,
        valueB: valueB.isEmpty ? null : valueB,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editing ? 'Edit Instruction' : 'Add Instruction'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('instruction-def-dropdown'),
              initialValue: _instructionId,
              decoration: const InputDecoration(labelText: 'Instruction'),
              items: [
                for (final def in widget.instructionSet.defs)
                  DropdownMenuItem<String>(
                    key: ValueKey<String>('instruction-option-${def.id}'),
                    value: def.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(instructionIconFor(def.iconKey), size: 16),
                        const SizedBox(width: 8),
                        Text(def.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _instructionId = value),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('instruction-text-field'),
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Text (blank = instruction name)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('instruction-value-a-field'),
              controller: _valueAController,
              decoration: const InputDecoration(labelText: 'A (start value)'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('instruction-value-b-field'),
              controller: _valueBController,
              decoration: const InputDecoration(labelText: 'B (end value)'),
            ),
            if (widget.onEditInstructionSet != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey<String>('instruction-edit-set-button'),
                  onPressed: widget.onEditInstructionSet,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Edit Instructions…'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.editing)
          TextButton(
            key: const ValueKey<String>('instruction-event-delete-button'),
            onPressed: () => Navigator.of(
              context,
            ).pop(const InstructionEventDialogResult(delete: true)),
            child: const Text('Delete'),
          ),
        TextButton(
          key: const ValueKey<String>('instruction-event-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('instruction-event-ok-button'),
          onPressed: _instructionId == null ? null : _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
