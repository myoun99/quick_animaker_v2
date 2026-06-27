import 'package:flutter/material.dart';

import 'brush_workspace_cache_invalidation_sink.dart';
import 'brush_workspace_fixture.dart';
import 'brush_workspace_view.dart';

/// Temporary debug/manual route-level wrapper for the reusable Brush editor.
///
/// This screen remains available while Brush editing is being prepared for
/// absorption into the main editor canvas area.
class BrushWorkspaceScreen extends StatefulWidget {
  const BrushWorkspaceScreen({super.key});

  @override
  State<BrushWorkspaceScreen> createState() => _BrushWorkspaceScreenState();
}

class _BrushWorkspaceScreenState extends State<BrushWorkspaceScreen> {
  late final _frameKeys = BrushWorkspaceFixture.createFrameKeys();
  late final _coordinator = BrushWorkspaceFixture.createCoordinator(
    frameKeys: _frameKeys,
  );
  final _cacheInvalidationSink = BrushWorkspaceCacheInvalidationSink();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('brush-workspace-screen'),
      appBar: AppBar(title: const Text('Brush Workspace')),
      body: BrushWorkspaceView(
        coordinator: _coordinator,
        availableFrameKeys: _frameKeys,
        cacheInvalidationSink: _cacheInvalidationSink,
      ),
    );
  }
}
