import 'package:flutter/material.dart';

import '../../models/cut_id.dart';
import '../../services/commands/convert_to_linked_cut_plan.dart';

/// 겸용 변경 dialog: pick a target cut, read the 안내문 (what links, what
/// gets replaced — 원본 승리 — and what appears where), then confirm.
/// Pops the chosen [CutId] to convert with, or null on cancel.
class ConvertToLinkedCutDialog extends StatefulWidget {
  const ConvertToLinkedCutDialog({
    super.key,
    required this.activeCutName,
    required this.candidates,
    required this.previewOf,
  });

  final String activeCutName;
  final List<({CutId id, String name})> candidates;
  final ConvertToLinkedCutPreviewData? Function(CutId targetCutId) previewOf;

  @override
  State<ConvertToLinkedCutDialog> createState() =>
      _ConvertToLinkedCutDialogState();
}

class _ConvertToLinkedCutDialogState extends State<ConvertToLinkedCutDialog> {
  CutId? _targetCutId;

  @override
  void initState() {
    super.initState();
    if (widget.candidates.length == 1) {
      _targetCutId = widget.candidates.single.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetCutId = _targetCutId;
    final preview = targetCutId == null ? null : widget.previewOf(targetCutId);
    return AlertDialog(
      key: const ValueKey<String>('convert-linked-cut-dialog'),
      title: const Text('Convert to Linked Cut'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link "${widget.activeCutName}" (origin) with another cut. '
              'Layers with the SAME NAME become one shared picture.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CutId>(
              key: const ValueKey<String>('convert-linked-cut-target'),
              initialValue: targetCutId,
              decoration: const InputDecoration(
                labelText: 'Link with cut',
                isDense: true,
              ),
              items: [
                for (final candidate in widget.candidates)
                  DropdownMenuItem(
                    value: candidate.id,
                    child: Text(candidate.name),
                  ),
              ],
              onChanged: (value) => setState(() => _targetCutId = value),
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              _PreviewSummary(preview: preview),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('convert-linked-cut-cancel-button'),
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('convert-linked-cut-confirm-button'),
          onPressed: preview != null && preview.linksAnything
              ? () => Navigator.of(context).pop(targetCutId)
              : null,
          child: const Text('Link'),
        ),
      ],
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.preview});

  final ConvertToLinkedCutPreviewData preview;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (preview.linkingLayerNames.isNotEmpty)
        'Links ${preview.linkingLayerNames.join(", ")}.',
      // 원본 승리, announced up front (user-confirmed rule): the origin's
      // picture wins each same-name conflict, exactly once, undoable.
      if (preview.replacedFrameCount > 0)
        '${preview.replacedFrameCount} same-name drawing(s) in '
            '"${preview.targetCutName}" will be replaced by the origin\'s '
            '(원본 승리).',
      if (preview.joiningFrameCount > 0)
        '${preview.joiningFrameCount} drawing(s) join the shared set.',
      if (preview.layerNamesAppearingInTarget.isNotEmpty)
        '"${preview.targetCutName}" gains: '
            '${preview.layerNamesAppearingInTarget.join(", ")}.',
      if (preview.layerNamesAppearingInOrigin.isNotEmpty)
        'This cut gains: '
            '${preview.layerNamesAppearingInOrigin.join(", ")}.',
      if (!preview.linksAnything)
        'Nothing to link — the cuts are already fully linked or share no '
            'drawing layers.',
      if (preview.linksAnything) 'Undo restores both cuts.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              key: ValueKey<String>('convert-linked-cut-line-$line'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
