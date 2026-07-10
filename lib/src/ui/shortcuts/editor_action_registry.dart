import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The single shortcut intent: every editor action dispatches through ONE
/// intent type carrying its [actionId], so the app mounts exactly one
/// Actions handler and the Shortcuts map stays data-driven from the
/// registry (P1: fully customizable from day one).
class EditorActionIntent extends Intent {
  const EditorActionIntent(this.actionId);

  final String actionId;
}

/// One registered editor action: the id keys the override store, the
/// label/category feed the Keyboard Shortcuts dialog, the default
/// activators seed the Shortcuts map, and menu items borrow the primary
/// activator as their shortcut label. THIS list is the single authority
/// all three consumers read.
class EditorActionDefinition {
  const EditorActionDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.defaultActivators,
  });

  final String id;
  final String label;
  final String category;
  final List<SingleActivator> defaultActivators;
}

/// Registry ids (referenced from dispatch and menu labels).
abstract final class EditorActionIds {
  static const framePrevious = 'frame-previous';
  static const frameNext = 'frame-next';
  static const drawingPrevious = 'drawing-previous';
  static const drawingNext = 'drawing-next';
  static const playbackToggle = 'playback-toggle';
  static const undo = 'edit-undo';
  static const redo = 'edit-redo';
  static const toolBrush = 'tool-brush';
  static const toolEraser = 'tool-eraser';
}

/// The default action set. Frame flipping on `,`/`.` (with arrow aliases)
/// and drawing jumps on Ctrl+`,`/`.` are the animation-desk core; tools
/// and transport follow PS/CSP convention.
final List<EditorActionDefinition> editorActionDefinitions = [
  const EditorActionDefinition(
    id: EditorActionIds.framePrevious,
    label: 'Previous Frame',
    category: 'Navigation',
    defaultActivators: [
      SingleActivator(LogicalKeyboardKey.comma),
      SingleActivator(LogicalKeyboardKey.arrowLeft),
    ],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.frameNext,
    label: 'Next Frame',
    category: 'Navigation',
    defaultActivators: [
      SingleActivator(LogicalKeyboardKey.period),
      SingleActivator(LogicalKeyboardKey.arrowRight),
    ],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.drawingPrevious,
    label: 'Previous Drawing',
    category: 'Navigation',
    defaultActivators: [
      SingleActivator(LogicalKeyboardKey.comma, control: true),
    ],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.drawingNext,
    label: 'Next Drawing',
    category: 'Navigation',
    defaultActivators: [
      SingleActivator(LogicalKeyboardKey.period, control: true),
    ],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.playbackToggle,
    label: 'Play / Pause',
    category: 'Playback',
    defaultActivators: [SingleActivator(LogicalKeyboardKey.space)],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.undo,
    label: 'Undo',
    category: 'Edit',
    defaultActivators: [
      SingleActivator(LogicalKeyboardKey.keyZ, control: true),
    ],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.redo,
    label: 'Redo',
    category: 'Edit',
    defaultActivators: [
      SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
      SingleActivator(LogicalKeyboardKey.keyY, control: true),
    ],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.toolBrush,
    label: 'Brush Tool',
    category: 'Tools',
    defaultActivators: [SingleActivator(LogicalKeyboardKey.keyB)],
  ),
  const EditorActionDefinition(
    id: EditorActionIds.toolEraser,
    label: 'Eraser Tool',
    category: 'Tools',
    defaultActivators: [SingleActivator(LogicalKeyboardKey.keyE)],
  ),
];
