import 'brush_frame_key.dart';
import 'brush_paint_command.dart';
import 'brush_paint_command_id.dart';
import 'brush_paint_command_state.dart';
import 'dirty_tile_set.dart';

/// Frame-local Brush T2 drawing source payload.
///
/// The source of truth is the lightweight command list plus command ids hidden
/// by global undo. Bitmap/cache payloads stay outside this object and are
/// derived from visible commands when future cache phases need them.
class BrushFrameDrawingState {
  BrushFrameDrawingState({
    required this.key,
    List<BrushPaintCommand> paintCommands = const [],
    Set<BrushPaintCommandId> hiddenCommandIds = const {},
    this.bakedPaintCommandIds = const {},
    this.inactivePreviewDirty = false,
    this.sourceRevision = 0,
    DirtyTileSet? cacheDirtyTiles,
  }) : cacheDirtyTiles = cacheDirtyTiles ?? DirtyTileSet.empty(),
       _paintCommands = List.unmodifiable(paintCommands),
       hiddenCommandIds = Set.unmodifiable(hiddenCommandIds);

  final BrushFrameKey key;
  final List<BrushPaintCommand> _paintCommands;
  final Set<BrushPaintCommandId> hiddenCommandIds;
  final Set<BrushPaintCommandId> bakedPaintCommandIds;
  final bool inactivePreviewDirty;
  final int sourceRevision;
  final DirtyTileSet cacheDirtyTiles;

  List<BrushPaintCommand> get paintCommands => _paintCommands;
  List<BrushPaintCommand> get commands => paintCommands;

  List<BrushPaintCommand> get livePaintCommands =>
      _visibleByState(BrushPaintCommandState.live);

  List<BrushPaintCommand> get hiddenByUndoPaintCommands =>
      _paintCommands
          .where((command) => hiddenCommandIds.contains(command.id))
          .toList()
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

  List<BrushPaintCommand> get deferredBakePaintCommands =>
      _visibleByState(BrushPaintCommandState.deferredBake);

  bool get hasDeferredBakeCommands => deferredBakePaintCommands.isNotEmpty;
  int get deferredBakeCount => deferredBakePaintCommands.length;

  List<BrushPaintCommand> get visibleActivePaintCommands =>
      [...deferredBakePaintCommands, ...livePaintCommands]
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

  List<BrushPaintCommand> get allPaintCommandsInDisplayOrder =>
      visibleActivePaintCommands;

  BrushPaintCommand? commandById(BrushPaintCommandId id) {
    for (final command in _paintCommands) {
      if (command.id == id) return command;
    }
    return null;
  }

  BrushFrameDrawingState copyWith({
    List<BrushPaintCommand>? paintCommands,
    Set<BrushPaintCommandId>? hiddenCommandIds,
    Set<BrushPaintCommandId>? bakedPaintCommandIds,
    bool? inactivePreviewDirty,
    int? sourceRevision,
    DirtyTileSet? cacheDirtyTiles,
  }) {
    return BrushFrameDrawingState(
      key: key,
      paintCommands: paintCommands ?? _paintCommands,
      hiddenCommandIds: hiddenCommandIds ?? this.hiddenCommandIds,
      bakedPaintCommandIds: bakedPaintCommandIds ?? this.bakedPaintCommandIds,
      inactivePreviewDirty: inactivePreviewDirty ?? this.inactivePreviewDirty,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      cacheDirtyTiles: cacheDirtyTiles ?? this.cacheDirtyTiles,
    );
  }

  List<BrushPaintCommand> _visibleByState(BrushPaintCommandState state) =>
      _paintCommands
          .where(
            (command) =>
                command.state == state &&
                !hiddenCommandIds.contains(command.id),
          )
          .toList()
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
}

typedef BrushFrameDrawing = BrushFrameDrawingState;
