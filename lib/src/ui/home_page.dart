import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/project.dart';
import '../services/persistence/project_autosave_service.dart';
import '../services/project_repository.dart';
import 'brush/brush_tool_state.dart';
import 'brush/paint_tool_state_notifier.dart';
import 'shortcuts/touch_shortcuts.dart';
import 'brush/canvas_selection_commands.dart';
import 'brush/canvas_view_commands.dart';
import 'editor_session_manager.dart';
import 'editor_workspace.dart';
import 'export/export_dialog.dart';
import 'menu/editor_menu_bar.dart';
import 'panels/workspace_panels_menu.dart';
import 'playback/canvas_playback_controller.dart';
import 'shortcuts/editor_action_registry.dart';
import 'shortcuts/editor_shortcut_bindings.dart';
import 'shortcuts/shortcut_settings_store.dart';

/// The editor shell: a slim top menu strip (menu bar + quick actions —
/// the AppBar retired so the editor keeps the vertical space) plus the
/// dockable-panel workspace. Every panel's WIRING lives in its own host
/// file (timeline_tab_host.dart, storyboard_tab_host.dart,
/// editor_canvas_area.dart) so parallel work on different panels stays in
/// different files; the workspace only owns the dock layout and shared
/// panel view state.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialProject, this.onRepositoryCreated});

  final Project? initialProject;
  final void Function(ProjectRepository repository)? onRepositoryCreated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final EditorSessionManager _session;
  final WorkspacePanelsMenuController _panelsMenu =
      WorkspacePanelsMenuController();

  /// The active canvas tool, hoisted here so the tool shortcuts (B/E) and
  /// the workspace's tool/brush panels drive one notifier. Paint tools
  /// keep per-tool settings memory (R11-④: the brush and the eraser each
  /// remember their own preset/settings).
  final ValueNotifier<BrushToolState> _brushTool = PaintToolStateNotifier(
    BrushToolState.defaults,
  );

  /// The canvas rotate/flip channel (P8): the R/Shift+R/H shortcuts call
  /// in here; the mounted canvas panel binds the viewport handlers.
  final CanvasViewCommands _canvasViewCommands = CanvasViewCommands();

  /// The selection channel (P9): Ctrl+D and the arrow nudges call in
  /// here; without a live selection the arrows keep flipping frames.
  final CanvasSelectionCommands _canvasSelectionCommands =
      CanvasSelectionCommands();

  /// The customizable shortcut bindings (P1): registry defaults + the
  /// user's persisted overrides. Persistence is disabled under
  /// FLUTTER_TEST like the workspace layout.
  late final EditorShortcutBindings _shortcuts = EditorShortcutBindings(
    store: Platform.environment.containsKey('FLUTTER_TEST')
        ? null
        : ShortcutSettingsStore(),
  );

  /// Autosave (P3): periodic dirty-session snapshots into the sidecar.
  /// Never runs under FLUTTER_TEST (tests drive the service directly).
  ProjectAutosaveService? _autosave;

  // NO whole-page session setState: rebuilding the app bar and every dock
  // and panel on every session notify was the editing jank's biggest
  // multiplier. Each panel host subscribes to the session itself; the app
  // bar's undo/redo buttons carry their own ListenableBuilder below.
  @override
  void initState() {
    super.initState();
    final project = widget.initialProject ?? createDefaultProject();
    _session = EditorSessionManager(initialProject: project);
    widget.onRepositoryCreated?.call(_session.repository);
    unawaited(_shortcuts.restore());
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _autosave = ProjectAutosaveService(
        isDirty: () => _session.hasUnsavedChanges,
        writeSnapshot: _session.writeAutosaveSnapshot,
        autosavePath: () => _session.autosaveSidecarPath,
      )..start();
    }
  }

  @override
  void dispose() {
    _autosave?.dispose();
    _session.dispose();
    _panelsMenu.dispose();
    _brushTool.dispose();
    _shortcuts.dispose();
    super.dispose();
  }

  /// Dispatches one registry action — the single funnel every shortcut
  /// lands in (menu items call the same session APIs directly).
  void _invokeAction(String actionId) {
    switch (actionId) {
      case EditorActionIds.framePrevious:
        // A live selection claims the arrow keys as nudges (PS
        // arbitration); the comma/period bindings always flip.
        if (_canvasSelectionCommands.hasSelection) {
          _canvasSelectionCommands.nudge(-1, 0);
        } else {
          _session.selectPreviousFrame();
        }
      case EditorActionIds.frameNext:
        if (_canvasSelectionCommands.hasSelection) {
          _canvasSelectionCommands.nudge(1, 0);
        } else {
          _session.selectNextFrame();
        }
      case EditorActionIds.drawingPrevious:
        _session.selectPreviousDrawing();
      case EditorActionIds.drawingNext:
        _session.selectNextDrawing();
      case EditorActionIds.playbackToggle:
        final playback = _session.playback;
        if (playback.isActive && playback.isPlaying) {
          playback.pause();
        } else if (playback.isActive) {
          playback.resume();
        } else {
          playback.play(
            scope: PlaybackScope.activeCut,
            startGlobalFrame: _session.currentFrameIndex,
          );
        }
      case EditorActionIds.undo:
        if (_session.canUndo) {
          _session.undo();
        }
      case EditorActionIds.redo:
        if (_session.canRedo) {
          _session.redo();
        }
      case EditorActionIds.toolBrush:
        _brushTool.value = _brushTool.value.copyWith(tool: CanvasTool.brush);
      case EditorActionIds.toolEraser:
        _brushTool.value = _brushTool.value.copyWith(tool: CanvasTool.eraser);
      case EditorActionIds.toolEyedropper:
        _brushTool.value = _brushTool.value.copyWith(
          tool: CanvasTool.eyedropper,
        );
      case EditorActionIds.toolFill:
        _brushTool.value = _brushTool.value.copyWith(tool: CanvasTool.fill);
      case EditorActionIds.onionSkinToggle:
        _session.toggleOnionSkin();
      case EditorActionIds.canvasRotateCcw:
        _canvasViewCommands.rotateBy(-15);
      case EditorActionIds.canvasRotateCw:
        _canvasViewCommands.rotateBy(15);
      case EditorActionIds.canvasFlipHorizontal:
        _canvasViewCommands.toggleFlipHorizontal();
      case EditorActionIds.toolSelectRect:
        _brushTool.value = _brushTool.value.copyWith(
          tool: CanvasTool.selectRect,
        );
      case EditorActionIds.toolLasso:
        _brushTool.value = _brushTool.value.copyWith(tool: CanvasTool.lasso);
      case EditorActionIds.toolMove:
        _brushTool.value = _brushTool.value.copyWith(tool: CanvasTool.move);
      case EditorActionIds.selectionDeselect:
        _canvasSelectionCommands.deselect();
      case EditorActionIds.selectionNudgeUp:
        _canvasSelectionCommands.nudge(0, -1);
      case EditorActionIds.selectionNudgeDown:
        _canvasSelectionCommands.nudge(0, 1);
      case EditorActionIds.selectionFreeTransform:
        _canvasSelectionCommands.beginTransform();
      case EditorActionIds.selectionTransformCommit:
        _canvasSelectionCommands.commitTransform();
      case EditorActionIds.selectionTransformCancel:
        _canvasSelectionCommands.cancelTransform();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      // The app-level shortcut layer (P1): the manager stands bare-letter
      // shortcuts down while a text field has focus; the bindings notifier
      // rebuilds the map live as the user re-records keys.
      body: ListenableBuilder(
        listenable: _shortcuts,
        builder: (context, _) => Shortcuts.manager(
          manager: EditorShortcutManager(shortcuts: _shortcuts.shortcuts),
          child: Actions(
            actions: {
              EditorActionIntent: CallbackAction<EditorActionIntent>(
                onInvoke: (intent) {
                  _invokeAction(intent.actionId);
                  return null;
                },
              ),
            },
            child: FocusScope(
              autofocus: true,
              // Multi-finger touch shortcuts (R11-⑨) fire through the SAME
              // action funnel as key bindings; the layer only observes raw
              // touches, so drawing and pinch navigation are untouched.
              child: TouchShortcutLayer(
                onGesture: (gesture) {
                  final actionId = _shortcuts.actionIdForTouchGesture(gesture);
                  if (actionId != null) {
                    _invokeAction(actionId);
                  }
                },
                child: Column(
                  children: [
                    // The top strip: title, the menu bar, and the quick actions
                    // (undo/redo/export keep their long-standing keys).
                    Material(
                      color: colorScheme.surfaceContainerHigh,
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Text(
                            'QuickAnimaker',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            // Narrow windows scroll the menu bar instead of
                            // overflowing the strip.
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              // The menu re-reads its enablement per notify: the
                              // history manager is merged in because brush strokes
                              // execute into it straight from the canvas (no session
                              // notify fires for a pen-up), the playback controller
                              // for the Playback menu's state, the panels bridge for
                              // the Window checkboxes.
                              child: ListenableBuilder(
                                listenable: Listenable.merge([
                                  _session,
                                  _session.historyManager,
                                  _session.playback,
                                  _panelsMenu,
                                ]),
                                builder: (context, _) => EditorMenuBar(
                                  session: _session,
                                  panelsMenu: _panelsMenu,
                                  shortcuts: _shortcuts,
                                ),
                              ),
                            ),
                          ),
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              _session,
                              _session.historyManager,
                            ]),
                            builder: (context, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: const ValueKey<String>('undo-button'),
                                  tooltip: 'Undo',
                                  onPressed: _session.canUndo
                                      ? _session.undo
                                      : null,
                                  icon: const Icon(Icons.undo),
                                ),
                                IconButton(
                                  key: const ValueKey<String>('redo-button'),
                                  tooltip: 'Redo',
                                  onPressed: _session.canRedo
                                      ? _session.redo
                                      : null,
                                  icon: const Icon(Icons.redo),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const ValueKey<String>('export-png-button'),
                            tooltip: 'Export',
                            onPressed: () {
                              unawaited(
                                showDialog<void>(
                                  context: context,
                                  builder: (context) =>
                                      ExportDialog(session: _session),
                                ),
                              );
                            },
                            icon: const Icon(Icons.save_alt),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    Expanded(
                      child: EditorWorkspace(
                        session: _session,
                        panelsMenu: _panelsMenu,
                        brushTool: _brushTool,
                        canvasViewCommands: _canvasViewCommands,
                        canvasSelectionCommands: _canvasSelectionCommands,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
