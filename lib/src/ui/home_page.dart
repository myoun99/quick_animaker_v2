import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/project.dart';
import '../services/project_repository.dart';
import 'editor_session_manager.dart';
import 'editor_workspace.dart';
import 'export/export_dialog.dart';
import 'panels/workspace_panels_menu.dart';

/// The editor shell: app bar plus the dockable-panel workspace. Every
/// panel's WIRING lives in its own host file (timeline_tab_host.dart,
/// storyboard_tab_host.dart, editor_canvas_area.dart) so parallel work on
/// different panels stays in different files; the workspace only owns the
/// dock layout and shared panel view state.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickAnimaker'),
        actions: [
          // The Panels menu: every panel with its visibility — closed
          // (X-ed) panels reopen from here, PS Window-menu style.
          ListenableBuilder(
            listenable: _panelsMenu,
            builder: (context, _) => PopupMenuButton<String>(
              key: const ValueKey<String>('panels-menu-button'),
              tooltip: 'Panels',
              icon: const Icon(Icons.space_dashboard_outlined),
              onSelected: _panelsMenu.toggle,
              itemBuilder: (context) => [
                for (final entry in _panelsMenu.entries)
                  CheckedPopupMenuItem<String>(
                    key: ValueKey<String>('panels-menu-item-${entry.tabId}'),
                    value: entry.tabId,
                    checked: entry.visible,
                    child: Text(entry.label),
                  ),
              ],
            ),
          ),
          // The history manager is merged in because brush strokes execute
          // into it straight from the canvas — no session notify ever fires
          // for a pen-up, and the buttons must still enable.
          ListenableBuilder(
            listenable: Listenable.merge([_session, _session.historyManager]),
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
      body: EditorWorkspace(session: _session, panelsMenu: _panelsMenu),
    );
  }
}
