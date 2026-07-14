import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_frame_key.dart';
import '../brush_frame_editing_coordinator.dart';
import '../cache_invalidation_executor.dart';
import '../command.dart';

/// Adopts a CONFIRMED move session (R16-①, TVP-style) into app history
/// as ONE undoable step (R19 P3b surface-snapshot form).
///
/// The session's ERASE was committed raw the moment the move began (the
/// origin must vanish instantly, but nothing is undoable until the user
/// confirms); the stamp floated un-committed through every drag, nudge
/// and Ctrl+T. The first execute LANDS the stamp at its confirmed
/// position and captures the post surface; [preLiftSurface] — captured
/// by the host before the erase — is the undo target. One Ctrl+Z
/// restores the pre-lift picture byte-exactly, session and cache state
/// notwithstanding (the surfaces are self-contained references).
class BrushLiftMoveHistoryCommand implements Command, RetainedBytesCommand {
  BrushLiftMoveHistoryCommand({
    required this.coordinator,
    required this.frameKey,
    required BitmapSurface preLiftSurface,
    required BrushDab stampDab,
    this.cacheInvalidationSink,
  }) : _preSurface = preLiftSurface,
       _stampDab = stampDab,
       _retainedBytes =
           2 * 4 * (stampDab.stamp?.width ?? 0) * (stampDab.stamp?.height ?? 0);

  final BrushFrameEditingCoordinator coordinator;
  final BrushFrameKey frameKey;
  final CacheInvalidationSink? cacheInvalidationSink;

  final BitmapSurface _preSurface;

  /// Dropped after the landing — the stamp's RGBA payload is megabytes,
  /// and redo restores the post SURFACE instead (same retention
  /// discipline as BrushStrokeHistoryCommand).
  BrushDab? _stampDab;
  BitmapSurface? _postSurface;
  bool _landed = false;
  final int _retainedBytes;

  @override
  int get estimatedRetainedBytes => _retainedBytes;

  @override
  String get description => 'Move selection';

  @override
  void execute() {
    if (_landed) {
      coordinator.restoreSurfaceSnapshot(
        frameKey,
        _postSurface!,
        cacheInvalidationSink: cacheInvalidationSink,
      );
      return;
    }
    // First execute = the confirm itself: land the floating stamp (the
    // base surface is the post-erase state throughout the session).
    coordinator.commitSourceStroke(
      sourceDabs: [_stampDab!],
      cacheInvalidationSink: cacheInvalidationSink,
    );
    _postSurface = coordinator.currentSurfaceOf(frameKey);
    _stampDab = null;
    _landed = true;
  }

  @override
  void undo() {
    coordinator.restoreSurfaceSnapshot(
      frameKey,
      _preSurface,
      cacheInvalidationSink: cacheInvalidationSink,
    );
  }
}
