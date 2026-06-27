import 'package:flutter/material.dart';

import 'brush_workspace_cache_invalidation_sink.dart';
import 'brush_workspace_fixture.dart';
import 'brush_workspace_view.dart';

/// Main-canvas-oriented Brush host prepared for future HomePage integration.
///
/// For now it uses the temporary Brush workspace fixture. Future phases should
/// replace the fixture with the real editor timeline/layer/frame selection.
class MainCanvasBrushHost extends StatefulWidget {
  const MainCanvasBrushHost({super.key});

  @override
  State<MainCanvasBrushHost> createState() => _MainCanvasBrushHostState();
}

class _MainCanvasBrushHostState extends State<MainCanvasBrushHost> {
  late final _frameKeys = BrushWorkspaceFixture.createFrameKeys();
  late final _coordinator = BrushWorkspaceFixture.createCoordinator(
    frameKeys: _frameKeys,
  );
  final _cacheInvalidationSink = BrushWorkspaceCacheInvalidationSink();

  @override
  Widget build(BuildContext context) {
    return BrushWorkspaceView(
      key: const ValueKey<String>('main-canvas-brush-host'),
      coordinator: _coordinator,
      availableFrameKeys: _frameKeys,
      cacheInvalidationSink: _cacheInvalidationSink,
    );
  }
}
