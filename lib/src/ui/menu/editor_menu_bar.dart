import 'dart:async';

import 'package:flutter/material.dart';

import '../dialogs/canvas_size_dialog.dart';
import '../dialogs/delete_layer_dialog.dart';
import '../dialogs/rename_cut_dialog.dart';
import '../dialogs/rename_layer_dialog.dart';
import '../editor_session_manager.dart';
import '../export/export_dialog.dart';
import '../panels/workspace_panels_menu.dart';
import '../playback/canvas_playback_controller.dart';
import '../storyboard_playhead_mapping.dart';

/// The editor's top menu bar (the CSP/Photoshop File-Edit-… language),
/// organizing every session command in one discoverable place. Items call
/// the SAME session APIs the panels wire — the menu adds no new command
/// paths, only entrances.
///
/// Forward slots: File > Open/Save/Save As stay disabled until project
/// persistence lands (P3), Edit > Keyboard Shortcuts… until the shortcut
/// registry lands (P1b) — the registry will also feed
/// [MenuItemButton.shortcut] labels through [_item].
class EditorMenuBar extends StatelessWidget {
  const EditorMenuBar({
    super.key,
    required this.session,
    required this.panelsMenu,
  });

  final EditorSessionManager session;
  final WorkspacePanelsMenuController panelsMenu;

  /// One menu entry. The single funnel every item goes through so the P1
  /// shortcut registry can later inject `shortcut:` labels without
  /// restructuring the menus.
  MenuItemButton _item({
    required String id,
    required String label,
    VoidCallback? onPressed,
    MenuSerializableShortcut? shortcut,
  }) {
    return MenuItemButton(
      key: ValueKey<String>('menu-$id'),
      onPressed: onPressed,
      shortcut: shortcut,
      child: Text(label),
    );
  }

  // --- File -----------------------------------------------------------------

  List<Widget> _fileItems(BuildContext context) => [
    // Project persistence lands with the save/open roadmap phase; the
    // slots sit here (disabled) so the File menu's shape is stable.
    _item(id: 'file-open', label: 'Open…'),
    _item(id: 'file-save', label: 'Save'),
    _item(id: 'file-save-as', label: 'Save As…'),
    const Divider(height: 8),
    _item(
      id: 'file-export',
      label: 'Export…',
      onPressed: () {
        unawaited(
          showDialog<void>(
            context: context,
            builder: (context) => ExportDialog(session: session),
          ),
        );
      },
    ),
  ];

  // --- Edit -----------------------------------------------------------------

  List<Widget> _editItems(BuildContext context) => [
    _item(
      id: 'edit-undo',
      label: 'Undo',
      onPressed: session.canUndo ? session.undo : null,
    ),
    _item(
      id: 'edit-redo',
      label: 'Redo',
      onPressed: session.canRedo ? session.redo : null,
    ),
    const Divider(height: 8),
    _item(
      id: 'edit-copy-frame',
      label: 'Copy Frame',
      onPressed: session.canCopyFrameAtCurrentFrame
          ? session.copyFrameAtCurrentFrame
          : null,
    ),
    _item(
      id: 'edit-paste-linked-frame',
      label: 'Paste Linked Frame',
      onPressed: session.canPasteLinkedFrameAtCurrentFrame
          ? session.pasteLinkedFrameAtCurrentFrame
          : null,
    ),
    _item(
      id: 'edit-new-drawing',
      label: 'New Drawing at Frame',
      onPressed: session.canCreateDrawingAtCurrentFrame
          ? session.createDrawingAtCurrentFrame
          : null,
    ),
    _item(
      id: 'edit-delete-cell',
      label: 'Delete Cell',
      onPressed: session.canDeleteCellAtCurrentFrame
          ? session.deleteCellAtCurrentFrame
          : null,
    ),
    _item(
      id: 'edit-cut-exposure',
      label: 'Cut Exposure',
      onPressed: session.canCutExposureAtCurrentFrame
          ? session.cutExposureAtCurrentFrame
          : null,
    ),
    _item(
      id: 'edit-toggle-mark',
      label: 'Toggle Mark',
      onPressed: session.canToggleMarkAtCurrentFrame
          ? session.toggleMarkAtCurrentFrame
          : null,
    ),
    const Divider(height: 8),
    // Enabled once the customizable shortcut registry lands (P1b).
    _item(id: 'edit-keyboard-shortcuts', label: 'Keyboard Shortcuts…'),
  ];

  // --- Cut ------------------------------------------------------------------

  Future<void> _renameActiveCut(BuildContext context) async {
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameCutDialog(initialName: session.activeCut.name),
    );
    if (!context.mounted || nextName == null || nextName.trim().isEmpty) {
      return;
    }
    session.renameActiveCut(nextName);
  }

  Future<void> _resizeActiveCutCanvas(BuildContext context) async {
    final request = await showDialog<CanvasResizeRequest>(
      context: context,
      builder: (context) =>
          CanvasSizeDialog(initialSize: session.activeCut.canvasSize),
    );
    if (!context.mounted || request == null) {
      return;
    }
    session.resizeActiveCutCanvas(request.size, anchor: request.anchor);
  }

  List<Widget> _cutItems(BuildContext context) => [
    _item(id: 'cut-new', label: 'New Cut', onPressed: session.createCut),
    _item(
      id: 'cut-duplicate',
      label: 'Duplicate Cut',
      onPressed: session.duplicateActiveCut,
    ),
    _item(
      id: 'cut-rename',
      label: 'Rename Cut…',
      onPressed: () => unawaited(_renameActiveCut(context)),
    ),
    _item(
      id: 'cut-canvas-size',
      label: 'Canvas Size…',
      onPressed: () => unawaited(_resizeActiveCutCanvas(context)),
    ),
    const Divider(height: 8),
    _item(
      id: 'cut-move-left',
      label: 'Move Cut Left',
      onPressed: session.canMoveActiveCutLeft
          ? session.moveActiveCutLeft
          : null,
    ),
    _item(
      id: 'cut-move-right',
      label: 'Move Cut Right',
      onPressed: session.canMoveActiveCutRight
          ? session.moveActiveCutRight
          : null,
    ),
    const Divider(height: 8),
    _item(
      id: 'cut-delete',
      label: 'Delete Cut',
      onPressed: session.deleteActiveCut,
    ),
  ];

  // --- Layer ----------------------------------------------------------------

  Future<void> _renameActiveLayer(BuildContext context) async {
    final activeLayer = session.activeLayer;
    if (activeLayer == null) {
      return;
    }
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => RenameLayerDialog(initialName: activeLayer.name),
    );
    if (!context.mounted || nextName == null) {
      return;
    }
    session.renameActiveLayer(nextName);
  }

  Future<void> _deleteActiveLayer(BuildContext context) async {
    final activeLayer = session.activeLayer;
    if (activeLayer == null || !session.canDeleteActiveLayer) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteLayerDialog(layerName: activeLayer.name),
    );
    if (!context.mounted || shouldDelete != true) {
      return;
    }
    session.deleteActiveLayer();
  }

  List<Widget> _layerItems(BuildContext context) => [
    _item(id: 'layer-add', label: 'Add Layer', onPressed: session.addLayer),
    _item(
      id: 'layer-duplicate',
      label: 'Duplicate Layer',
      onPressed: session.duplicateActiveLayer,
    ),
    _item(
      id: 'layer-rename',
      label: 'Rename Layer…',
      onPressed: () => unawaited(_renameActiveLayer(context)),
    ),
    const Divider(height: 8),
    _item(
      id: 'layer-copy',
      label: 'Copy Layer',
      onPressed: session.copyActiveLayer,
    ),
    _item(
      id: 'layer-paste',
      label: 'Paste Layer',
      onPressed: session.hasLayerClipboard
          ? session.pasteLayerFromClipboard
          : null,
    ),
    const Divider(height: 8),
    _item(
      id: 'layer-delete',
      label: 'Delete Layer…',
      onPressed: session.canDeleteActiveLayer
          ? () => unawaited(_deleteActiveLayer(context))
          : null,
    ),
  ];

  // --- Playback ---------------------------------------------------------------

  void _togglePlayPause() {
    final playback = session.playback;
    if (playback.isActive && playback.isPlaying) {
      playback.pause();
    } else if (playback.isActive) {
      playback.resume();
    } else {
      playback.play(
        scope: PlaybackScope.activeCut,
        startGlobalFrame: session.currentFrameIndex,
      );
    }
  }

  List<Widget> _playbackItems(BuildContext context) => [
    _item(
      id: 'playback-play-pause',
      label: session.playback.isActive && session.playback.isPlaying
          ? 'Pause'
          : 'Play',
      onPressed: _togglePlayPause,
    ),
    _item(
      id: 'playback-stop',
      label: 'Stop',
      onPressed: session.playback.isActive ? session.playback.stop : null,
    ),
    _item(
      id: 'playback-play-all',
      label: 'Play All Cuts',
      onPressed: () {
        session.playback.play(
          scope: PlaybackScope.allCuts,
          startGlobalFrame: storyboardPlayheadFrame(session) ?? 0,
        );
      },
    ),
    const Divider(height: 8),
    KeyedSubtree(
      key: const ValueKey<String>('menu-playback-loop'),
      child: CheckboxMenuButton(
        value: session.playback.loopMode == PlaybackLoopMode.loop,
        onChanged: (checked) {
          session.playback.loopMode = checked == true
              ? PlaybackLoopMode.loop
              : PlaybackLoopMode.once;
        },
        child: const Text('Loop'),
      ),
    ),
  ];

  // --- Window ---------------------------------------------------------------

  List<Widget> _windowItems(BuildContext context) => [
    for (final entry in panelsMenu.entries)
      // KeyedSubtree, not a key on the button: CheckboxMenuButton forwards
      // its key to the inner MenuItemButton, which would make the key
      // match two widgets.
      KeyedSubtree(
        key: ValueKey<String>('panels-menu-item-${entry.tabId}'),
        child: CheckboxMenuButton(
          value: entry.visible,
          onChanged: (_) => panelsMenu.toggle(entry.tabId),
          child: Text(entry.label),
        ),
      ),
    const Divider(height: 8),
    _item(
      id: 'window-reset-layout',
      label: 'Reset Workspace Layout',
      onPressed: panelsMenu.canResetLayout ? panelsMenu.resetLayout : null,
    ),
  ];

  // --- Help -----------------------------------------------------------------

  List<Widget> _helpItems(BuildContext context) => [
    _item(
      id: 'help-about',
      label: 'About QuickAnimaker',
      onPressed: () =>
          showAboutDialog(context: context, applicationName: 'QuickAnimaker'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Compact top-level buttons: the strip is slim and seven menus plus
    // the quick actions must fit ordinary window widths.
    const topLevelStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      minimumSize: WidgetStatePropertyAll(Size(0, 36)),
      visualDensity: VisualDensity.compact,
    );
    return MenuBar(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      children: [
        SubmenuButton(
          key: const ValueKey<String>('menu-file'),
          style: topLevelStyle,
          menuChildren: _fileItems(context),
          child: const Text('File'),
        ),
        SubmenuButton(
          key: const ValueKey<String>('menu-edit'),
          style: topLevelStyle,
          menuChildren: _editItems(context),
          child: const Text('Edit'),
        ),
        SubmenuButton(
          key: const ValueKey<String>('menu-cut'),
          style: topLevelStyle,
          menuChildren: _cutItems(context),
          child: const Text('Cut'),
        ),
        SubmenuButton(
          key: const ValueKey<String>('menu-layer'),
          style: topLevelStyle,
          menuChildren: _layerItems(context),
          child: const Text('Layer'),
        ),
        SubmenuButton(
          key: const ValueKey<String>('menu-playback'),
          style: topLevelStyle,
          menuChildren: _playbackItems(context),
          child: const Text('Playback'),
        ),
        // The Panels menu of old (same item keys): every panel with its
        // visibility — closed (X-ed) panels reopen from here, PS
        // Window-menu style.
        SubmenuButton(
          key: const ValueKey<String>('panels-menu-button'),
          style: topLevelStyle,
          menuChildren: _windowItems(context),
          child: const Text('Window'),
        ),
        SubmenuButton(
          key: const ValueKey<String>('menu-help'),
          style: topLevelStyle,
          menuChildren: _helpItems(context),
          child: const Text('Help'),
        ),
      ],
    );
  }
}
