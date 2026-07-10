import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/project.dart';
import '../services/project_repository.dart';
import 'editor_session_manager.dart';
import 'editor_workspace.dart';
import 'export/export_dialog.dart';
import 'menu/editor_menu_bar.dart';
import 'panels/workspace_panels_menu.dart';

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
  }

  @override
  void dispose() {
    _session.dispose();
    _panelsMenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
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
                        onPressed: _session.canUndo ? _session.undo : null,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        key: const ValueKey<String>('redo-button'),
                        tooltip: 'Redo',
                        onPressed: _session.canRedo ? _session.redo : null,
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
                        builder: (context) => ExportDialog(session: _session),
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
            child: EditorWorkspace(session: _session, panelsMenu: _panelsMenu),
          ),
        ],
      ),
    );
  }
}
