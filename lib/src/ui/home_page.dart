import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/default_project_helpers.dart';
import '../models/project.dart';
import '../services/project_repository.dart';
import 'editor_canvas_area.dart';
import 'editor_session_manager.dart';
import 'export/export_dialog.dart';
import 'timeline_storyboard_tabs.dart';

/// The editor shell: app bar, canvas area and the bottom panel tabs. Every
/// panel's WIRING lives in its own host file (timeline_tab_host.dart,
/// storyboard_tab_host.dart, editor_canvas_area.dart) so parallel work on
/// different panels stays in different files.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialProject, this.onRepositoryCreated});

  final Project? initialProject;
  final void Function(ProjectRepository repository)? onRepositoryCreated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final EditorSessionManager _session;

  @override
  void initState() {
    super.initState();
    final project = widget.initialProject ?? createDefaultProject();
    _session = EditorSessionManager(initialProject: project)
      ..addListener(_onSessionChanged);
    widget.onRepositoryCreated?.call(_session.repository);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickAnimaker'),
        actions: [
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
      body: Column(
        children: [
          Expanded(child: EditorCanvasArea(session: _session)),
          TimelineStoryboardTabs(session: _session),
        ],
      ),
    );
  }
}
