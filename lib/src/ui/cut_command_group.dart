import 'package:flutter/material.dart';

import 'cut/cut_note_dialog.dart';
import 'dialogs/canvas_size_dialog.dart';
import 'dialogs/rename_cut_dialog.dart';
import 'editor_session_manager.dart';
import 'widgets/panel_flyout.dart';
import 'widgets/split_icon_button.dart';

/// The cut command group mounted IDENTICALLY on the timeline and storyboard
/// toolbars: a split new-cut button plus the Cut ▾ flyout carrying the full
/// cut command set (the storyboard body's nine-button toolbar, retired).
///
/// Owns its dialog flows (rename/note/canvas size) so both hosts share the
/// wiring; menu item keys reuse the retired buttons' key strings so tests
/// only gain a menu-open tap.
class CutCommandGroup extends StatefulWidget {
  const CutCommandGroup({super.key, required this.session});

  final EditorSessionManager session;

  @override
  State<CutCommandGroup> createState() => _CutCommandGroupState();
}

class _CutCommandGroupState extends State<CutCommandGroup> {
  EditorSessionManager get session => widget.session;

  Future<void> _renameActiveCut() async {
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameCutDialog(initialName: session.activeCut.name),
    );
    if (!mounted || nextName == null || nextName.trim().isEmpty) {
      return;
    }
    session.renameActiveCut(nextName);
  }

  Future<void> _editActiveCutNote() async {
    final initialNote = session.activeCutNote;
    if (initialNote == null) {
      return;
    }
    final nextNote = await showDialog<String>(
      context: context,
      builder: (context) => CutNoteDialog(initialNote: initialNote),
    );
    if (!mounted || nextNote == null) {
      return;
    }
    session.updateActiveCutNote(nextNote);
  }

  Future<void> _resizeActiveCutCanvas() async {
    final request = await showDialog<CanvasResizeRequest>(
      context: context,
      builder: (context) =>
          CanvasSizeDialog(initialSize: session.activeCut.canvasSize),
    );
    if (!mounted || request == null) {
      return;
    }
    session.resizeActiveCutCanvas(request.size, anchor: request.anchor);
  }

  List<PanelFlyoutEntry> _addEntries() {
    return [
      const PanelFlyoutHeader('Add cut'),
      PanelFlyoutItem(
        keyValue: 'add-cut-new',
        label: 'New cut',
        icon: Icons.add,
        onSelected: session.createCut,
      ),
      PanelFlyoutItem(
        keyValue: 'add-cut-duplicate',
        label: 'Duplicate active cut',
        icon: Icons.content_copy,
        onSelected: session.duplicateActiveCut,
      ),
    ];
  }

  List<PanelFlyoutEntry> _menuEntries() {
    return [
      PanelFlyoutItem(
        keyValue: 'rename-cut-button',
        label: 'Rename cut…',
        icon: Icons.edit_outlined,
        onSelected: _renameActiveCut,
      ),
      PanelFlyoutItem(
        keyValue: 'edit-cut-note-button',
        label: 'Edit cut note…',
        icon: Icons.note_alt_outlined,
        onSelected: _editActiveCutNote,
      ),
      PanelFlyoutItem(
        keyValue: 'resize-cut-canvas-button',
        label: 'Canvas size…',
        icon: Icons.aspect_ratio,
        onSelected: _resizeActiveCutCanvas,
      ),
      const PanelFlyoutDivider(),
      PanelFlyoutItem(
        keyValue: 'duplicate-cut-button',
        label: 'Duplicate cut',
        icon: Icons.content_copy,
        onSelected: session.duplicateActiveCut,
      ),
      PanelFlyoutItem(
        keyValue: 'set-cut-thumbnail-button',
        label: session.isActiveCutThumbnailPinnedHere
            ? 'Unpin thumbnail frame'
            : 'Pin thumbnail frame',
        icon: session.isActiveCutThumbnailPinnedHere
            ? Icons.image
            : Icons.image_outlined,
        checked: session.isActiveCutThumbnailPinnedHere ? true : null,
        onSelected: session.toggleActiveCutThumbnailFrame,
      ),
      const PanelFlyoutDivider(),
      PanelFlyoutItem(
        keyValue: 'move-cut-left-button',
        label: 'Move cut left',
        icon: Icons.chevron_left,
        enabled: session.canMoveActiveCutLeft,
        onSelected: session.moveActiveCutLeft,
      ),
      PanelFlyoutItem(
        keyValue: 'move-cut-right-button',
        label: 'Move cut right',
        icon: Icons.chevron_right,
        enabled: session.canMoveActiveCutRight,
        onSelected: session.moveActiveCutRight,
      ),
      const PanelFlyoutDivider(),
      PanelFlyoutItem(
        keyValue: 'delete-cut-button',
        label: 'Delete cut',
        icon: Icons.delete_outline,
        danger: true,
        onSelected: session.deleteActiveCut,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SplitIconButton(
          buttonKey: 'new-cut-button',
          menuKey: 'new-cut-menu',
          icon: Icons.add_photo_alternate_outlined,
          tooltip: 'New cut',
          onPressed: session.createCut,
          entriesBuilder: _addEntries,
        ),
        const SizedBox(width: 4),
        PanelFlyoutButton(
          key: const ValueKey<String>('cut-menu-button'),
          label: 'Cut',
          tooltip: 'Cut commands',
          entriesBuilder: _menuEntries,
        ),
      ],
    );
  }
}
