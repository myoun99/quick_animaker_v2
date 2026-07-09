import 'package:flutter/material.dart';

import '../../models/layer_kind.dart';
import '../editor_session_manager.dart';
import 'timeline_section_policy.dart';

/// The layer/frame/cell action toolbar shown above the timeline grid.
///
/// Icon-only with tooltips: layer actions on the left, cell actions on the
/// right, separated by hairline dividers. Reads all of its state from
/// [session] and invokes session commands directly. Actions that must run
/// a dialog first (which needs the hosting widget's [BuildContext]) are
/// delegated back to the host — entrance unification puts BOTH instance
/// buttons there: [onCreateInstance] (Add — frame/key/SE/instruction by
/// kind) and [onEditInstance] (the shared instance-edit dialog).
class TimelineActionToolbar extends StatelessWidget {
  const TimelineActionToolbar({
    super.key,
    required this.session,
    required this.onRenameLayer,
    required this.onDeleteLayer,
    required this.onEditInstance,
    required this.onCreateInstance,
    this.onImportAudio,
    this.hiddenSections = const {},
    this.onToggleSection,
  });

  final EditorSessionManager session;
  final VoidCallback onRenameLayer;
  final VoidCallback onDeleteLayer;

  /// Opens the unified instance-edit dialog for the active layer at the
  /// playhead (kind-dispatched by the host).
  final VoidCallback onEditInstance;

  /// Kind-dispatched creation: new frame / camera key / SE entry /
  /// instruction event.
  final VoidCallback onCreateInstance;

  /// Opens the audio file picker for the active SE layer (host-provided —
  /// it needs the platform dialog); null hides nothing, just disables.
  final VoidCallback? onImportAudio;

  /// Sections hidden from the grids; the section toggle buttons read and
  /// flip this (collapse is gone — hide/show replaced it).
  final Set<TimelineSection> hiddenSections;
  final ValueChanged<TimelineSection>? onToggleSection;

  /// Whether the Add button applies to the active layer's cell: drawing
  /// kinds keep their old any-cell gate, SE needs an EMPTY cell (covered
  /// cells edit instead), camera/instruction key/upsert anywhere.
  bool get _canCreateInstance {
    final layer = session.activeLayer;
    if (layer == null || !session.hasActiveNonNegativeCell) {
      return false;
    }
    return switch (layer.kind) {
      LayerKind.se => session.canCreateDrawingAtCurrentFrame,
      _ => true,
    };
  }

  /// Whether Edit Instance has something to open: drawing kinds need a
  /// named-frame cell (the rename gate), SE either an entry to edit or an
  /// empty cell to create into, camera/instruction any cell.
  bool get _canEditInstance {
    final layer = session.activeLayer;
    if (layer == null) {
      return false;
    }
    return switch (layer.kind) {
      LayerKind.camera ||
      LayerKind.instruction => session.hasActiveNonNegativeCell,
      LayerKind.se =>
        session.selectedFrame != null || session.canCreateDrawingAtCurrentFrame,
      _ => session.canRenameFrameAtCurrentFrame,
    };
  }

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
      iconSize: 18,
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _group({
    required ValueKey<String> key,
    required List<Widget> children,
  }) {
    return Row(key: key, mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Section show/hide toggle (replaces the retired collapse chevrons):
  /// accent-tinted while the section is hidden.
  Widget _sectionToggleButton(
    BuildContext context, {
    required TimelineSection section,
    required String buttonKey,
    required String label,
    required IconData icon,
  }) {
    assert(timelineSectionHideable(section));
    final hidden = hiddenSections.contains(section);
    final onToggleSection = this.onToggleSection;
    return IconButton(
      key: ValueKey<String>(buttonKey),
      tooltip: hidden ? 'Show $label' : 'Hide $label',
      onPressed: onToggleSection == null
          ? null
          : () => onToggleSection(section),
      icon: Icon(icon),
      isSelected: hidden,
      selectedIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      iconSize: 18,
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _groupDivider(BuildContext context) {
    return SizedBox(
      height: 22,
      child: VerticalDivider(
        width: 14,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('timeline-action-toolbar'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _group(
                key: const ValueKey<String>('timeline-toolbar-layer-group'),
                children: [
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
                  _iconButton(
                    key: const ValueKey<String>('toggle-art-layer-button'),
                    tooltip: 'Toggle Art Layer',
                    icon: Icons.landscape_outlined,
                    onPressed: session.canToggleTargetLayerArt
                        ? session.toggleTargetLayerArt
                        : null,
                  ),
                  _sectionToggleButton(
                    context,
                    section: TimelineSection.se,
                    buttonKey: 'toggle-se-section-button',
                    label: 'SE Rows',
                    icon: Icons.music_off_outlined,
                  ),
                  _sectionToggleButton(
                    context,
                    section: TimelineSection.camera,
                    buttonKey: 'toggle-camera-section-button',
                    label: 'Camera Rows',
                    icon: Icons.videocam_off_outlined,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('import-audio-button'),
                    tooltip: 'Import Audio',
                    icon: Icons.audio_file_outlined,
                    onPressed:
                        session.canImportAudioToActiveLayer &&
                            onImportAudio != null
                        ? onImportAudio
                        : null,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('rename-layer-button'),
                    tooltip: 'Rename Layer',
                    icon: Icons.drive_file_rename_outline,
                    onPressed: session.activeLayer == null
                        ? null
                        : onRenameLayer,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('duplicate-layer-button'),
                    tooltip: 'Duplicate Layer',
                    icon: Icons.copy_outlined,
                    onPressed: session.activeLayer == null
                        ? null
                        : session.duplicateActiveLayer,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('copy-layer-button'),
                    tooltip: 'Copy Layer',
                    icon: Icons.content_copy,
                    onPressed: session.activeLayer == null
                        ? null
                        : session.copyActiveLayer,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('paste-layer-button'),
                    tooltip: session.layerClipboardName == null
                        ? 'Paste Layer'
                        : 'Paste Layer (${session.layerClipboardName})',
                    icon: Icons.content_paste,
                    onPressed: session.hasLayerClipboard
                        ? session.pasteLayerFromClipboard
                        : null,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('delete-layer-button'),
                    tooltip: 'Delete Layer',
                    icon: Icons.delete_outline,
                    onPressed: session.canDeleteActiveLayer
                        ? onDeleteLayer
                        : null,
                  ),
                ],
              ),
              _groupDivider(context),
              _group(
                key: const ValueKey<String>('timeline-toolbar-create-group'),
                children: [
                  _iconButton(
                    key: const ValueKey<String>('new-frame-button'),
                    tooltip: 'Add',
                    icon: Icons.add_box_outlined,
                    onPressed: _canCreateInstance ? onCreateInstance : null,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('blank-exposure-button'),
                    tooltip: 'Blank / X',
                    icon: Icons.close,
                    onPressed: session.canCutExposureAtCurrentFrame
                        ? session.cutExposureAtCurrentFrame
                        : null,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('toggle-mark-button'),
                    tooltip: 'Mark ●',
                    icon: Icons.circle,
                    onPressed: session.canToggleMarkAtCurrentFrame
                        ? session.toggleMarkAtCurrentFrame
                        : null,
                  ),
                ],
              ),
              _groupDivider(context),
              _group(
                key: const ValueKey<String>('timeline-toolbar-copy-group'),
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
                    key: const ValueKey<String>('paste-linked-frame-button'),
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
                key: const ValueKey<String>('timeline-toolbar-edit-group'),
                children: [
                  _iconButton(
                    key: const ValueKey<String>('rename-frame-button'),
                    tooltip: 'Edit Instance',
                    icon: Icons.edit_outlined,
                    onPressed: _canEditInstance ? onEditInstance : null,
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
                key: const ValueKey<String>('timeline-toolbar-exposure-group'),
                children: [
                  _iconButton(
                    key: const ValueKey<String>('decrease-exposure-button'),
                    tooltip: 'Decrease Exposure',
                    icon: Icons.remove,
                    onPressed: session.canDecreaseSelectedExposure
                        ? session.decreaseSelectedExposure
                        : null,
                  ),
                  _iconButton(
                    key: const ValueKey<String>('increase-exposure-button'),
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
    );
  }
}
