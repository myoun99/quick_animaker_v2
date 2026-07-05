import 'package:flutter/material.dart';

import '../editor_session_manager.dart';

/// The layer/frame/cell action toolbar shown beneath the canvas.
///
/// Reads all of its state from [session] and invokes session commands directly.
/// The three actions that must run a dialog first (which needs the hosting
/// widget's [BuildContext]) are delegated back to the host via [onRenameLayer],
/// [onDeleteLayer] and [onRenameFrame].
class TimelineActionToolbar extends StatelessWidget {
  const TimelineActionToolbar({
    super.key,
    required this.session,
    required this.onRenameLayer,
    required this.onDeleteLayer,
    required this.onRenameFrame,
  });

  final EditorSessionManager session;
  final VoidCallback onRenameLayer;
  final VoidCallback onDeleteLayer;
  final VoidCallback onRenameFrame;

  Widget _iconButton({
    required ValueKey<String> key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 20,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _group({
    required ValueKey<String> key,
    required List<Widget> children,
  }) {
    return Row(key: key, mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _groupDivider(BuildContext context) {
    return SizedBox(
      height: 28,
      child: VerticalDivider(
        width: 16,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFrame = session.selectedFrame;
    final selectedEffectiveDuration = session.selectedEffectiveDuration;
    return DecoratedBox(
      key: const ValueKey<String>('timeline-action-toolbar'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    session.currentLayerStatusText,
                    key: const ValueKey<String>('current-layer-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    session.activeLayerKindLabelText,
                    key: const ValueKey<String>('active-layer-kind-label'),
                  ),
                  const SizedBox(width: 8),
                  _iconButton(
                    key: const ValueKey<String>(
                      'toggle-storyboard-layer-button',
                    ),
                    tooltip: 'Toggle Storyboard Layer',
                    icon: Icons.auto_stories_outlined,
                    onPressed: session.canToggleTargetLayerKind
                        ? session.toggleTargetLayerKind
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _iconButton(
                    key: const ValueKey<String>('rename-layer-button'),
                    tooltip: 'Rename Layer',
                    icon: Icons.drive_file_rename_outline,
                    onPressed: session.activeLayer == null
                        ? null
                        : onRenameLayer,
                  ),
                  const SizedBox(width: 8),
                  _iconButton(
                    key: const ValueKey<String>('duplicate-layer-button'),
                    tooltip: 'Duplicate Layer',
                    icon: Icons.copy_outlined,
                    onPressed: session.activeLayer == null
                        ? null
                        : session.duplicateActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _iconButton(
                    key: const ValueKey<String>('copy-layer-button'),
                    tooltip: 'Copy Layer',
                    icon: Icons.content_copy,
                    onPressed: session.activeLayer == null
                        ? null
                        : session.copyActiveLayer,
                  ),
                  const SizedBox(width: 8),
                  _iconButton(
                    key: const ValueKey<String>('paste-layer-button'),
                    tooltip: 'Paste Layer',
                    icon: Icons.content_paste,
                    onPressed: session.hasLayerClipboard
                        ? session.pasteLayerFromClipboard
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.layerClipboardName == null
                        ? 'Layer Clipboard: empty'
                        : 'Layer Clipboard: ${session.layerClipboardName}',
                    key: const ValueKey<String>('layer-clipboard-status'),
                  ),
                  const SizedBox(width: 8),
                  _iconButton(
                    key: const ValueKey<String>('delete-layer-button'),
                    tooltip: 'Delete Layer',
                    icon: Icons.delete_outline,
                    onPressed: session.canDeleteActiveLayer
                        ? onDeleteLayer
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    session.currentFrameStatusText,
                    key: const ValueKey<String>('current-frame-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    session.currentCellStatusText,
                    key: const ValueKey<String>('current-cell-status'),
                  ),
                  const SizedBox(width: 16),
                  Text('Drawing: ${selectedFrame == null ? 'no' : 'yes'}'),
                  const SizedBox(width: 16),
                  Text('Duration: ${selectedEffectiveDuration ?? '-'}'),
                  const SizedBox(width: 16),
                  Text(
                    session.linkedFrameUsesStatusText,
                    key: const ValueKey<String>('linked-frame-uses-status'),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    session.copiedFrameStatusText,
                    key: const ValueKey<String>('copied-frame-status'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DecoratedBox(
                key: const ValueKey<String>('cell-actions-section'),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cell Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _group(
                        key: const ValueKey<String>(
                          'timeline-toolbar-create-group',
                        ),
                        children: [
                          _iconButton(
                            key: const ValueKey<String>('new-frame-button'),
                            tooltip: 'New Frame',
                            icon: Icons.add_box_outlined,
                            onPressed: session.hasActiveNonNegativeCell
                                ? session.createDrawingAtCurrentFrame
                                : null,
                          ),
                          _iconButton(
                            key: const ValueKey<String>(
                              'blank-exposure-button',
                            ),
                            tooltip: 'Blank / X',
                            icon: Icons.close,
                            onPressed: session.hasActiveNonNegativeCell
                                ? session.createBlankAtCurrentFrame
                                : null,
                          ),
                          _iconButton(
                            key: const ValueKey<String>('toggle-mark-button'),
                            tooltip: 'Mark ●',
                            icon: Icons.circle,
                            onPressed: session.hasActiveNonNegativeCell
                                ? session.toggleMarkAtCurrentFrame
                                : null,
                          ),
                        ],
                      ),
                      _groupDivider(context),
                      _group(
                        key: const ValueKey<String>(
                          'timeline-toolbar-copy-group',
                        ),
                        children: [
                          _iconButton(
                            key: const ValueKey<String>('copy-frame-button'),
                            tooltip: 'Copy Frame',
                            icon: Icons.content_copy,
                            onPressed: session.canCopyFrameAtCurrentFrame
                                ? session.copyFrameAtCurrentFrame
                                : null,
                          ),
                          _iconButton(
                            key: const ValueKey<String>(
                              'paste-linked-frame-button',
                            ),
                            tooltip: 'Paste Linked Frame',
                            icon: Icons.link,
                            onPressed: session.canPasteLinkedFrameAtCurrentFrame
                                ? session.pasteLinkedFrameAtCurrentFrame
                                : null,
                          ),
                        ],
                      ),
                      _groupDivider(context),
                      _group(
                        key: const ValueKey<String>(
                          'timeline-toolbar-edit-group',
                        ),
                        children: [
                          _iconButton(
                            key: const ValueKey<String>('rename-frame-button'),
                            tooltip: 'Rename Frame',
                            icon: Icons.edit_outlined,
                            onPressed: session.canRenameFrameAtCurrentFrame
                                ? onRenameFrame
                                : null,
                          ),
                          _iconButton(
                            key: const ValueKey<String>('delete-cell-button'),
                            tooltip: 'Delete Cell',
                            icon: Icons.delete_outline,
                            onPressed: session.canDeleteCellAtCurrentFrame
                                ? session.deleteCellAtCurrentFrame
                                : null,
                          ),
                        ],
                      ),
                      _groupDivider(context),
                      _group(
                        key: const ValueKey<String>(
                          'timeline-toolbar-exposure-group',
                        ),
                        children: [
                          _iconButton(
                            key: const ValueKey<String>(
                              'decrease-exposure-button',
                            ),
                            tooltip: 'Decrease Exposure',
                            icon: Icons.remove,
                            onPressed: session.canDecreaseSelectedExposure
                                ? session.decreaseSelectedExposure
                                : null,
                          ),
                          _iconButton(
                            key: const ValueKey<String>(
                              'increase-exposure-button',
                            ),
                            tooltip: 'Increase Exposure',
                            icon: Icons.add,
                            onPressed: session.canIncreaseSelectedExposure
                                ? session.increaseSelectedExposure
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.compactCellActionText,
              key: const ValueKey<String>('cell-action-hint'),
            ),
          ],
        ),
      ),
    );
  }
}
