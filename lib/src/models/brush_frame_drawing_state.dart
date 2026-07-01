import 'brush_frame_key.dart';
import 'brush_paint_command.dart';
import 'brush_paint_command_id.dart';
import 'brush_paint_command_state.dart';
import 'dirty_tile_set.dart';

class BrushFrameDrawingState {
  BrushFrameDrawingState({
    required this.key,
    List<BrushPaintCommand> paintCommands = const [],
    this.bakedPaintCommandIds = const {},
    this.inactivePreviewDirty = false,
    DirtyTileSet? cacheDirtyTiles,
  }) : cacheDirtyTiles = cacheDirtyTiles ?? DirtyTileSet.empty(),
       _paintCommands = paintCommands;

  final BrushFrameKey key;
  final List<BrushPaintCommand> _paintCommands;
  final Set<BrushPaintCommandId> bakedPaintCommandIds;
  final bool inactivePreviewDirty;
  final DirtyTileSet cacheDirtyTiles;

  List<BrushPaintCommand> get paintCommands =>
      List.unmodifiable(_paintCommands);

  List<BrushPaintCommand> get livePaintCommands =>
      _byState(BrushPaintCommandState.live);
  List<BrushPaintCommand> get hiddenByUndoPaintCommands =>
      _byState(BrushPaintCommandState.hiddenByUndo);
  List<BrushPaintCommand> get deferredBakePaintCommands =>
      _byState(BrushPaintCommandState.deferredBake);

  bool get hasDeferredBakeCommands => deferredBakePaintCommands.isNotEmpty;
  int get deferredBakeCount => deferredBakePaintCommands.length;

  List<BrushPaintCommand> get visibleActivePaintCommands =>
      [...deferredBakePaintCommands, ...livePaintCommands]
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

  List<BrushPaintCommand> get allPaintCommandsInDisplayOrder =>
      [...deferredBakePaintCommands, ...livePaintCommands]
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

  BrushPaintCommand? commandById(BrushPaintCommandId id) {
    for (final command in _paintCommands) {
      if (command.id == id) return command;
    }
    return null;
  }

  BrushFrameDrawingState copyWith({
    List<BrushPaintCommand>? paintCommands,
    Set<BrushPaintCommandId>? bakedPaintCommandIds,
    bool? inactivePreviewDirty,
    DirtyTileSet? cacheDirtyTiles,
  }) {
    return BrushFrameDrawingState(
      key: key,
      paintCommands: paintCommands ?? _paintCommands,
      bakedPaintCommandIds: bakedPaintCommandIds ?? this.bakedPaintCommandIds,
      inactivePreviewDirty: inactivePreviewDirty ?? this.inactivePreviewDirty,
      cacheDirtyTiles: cacheDirtyTiles ?? this.cacheDirtyTiles,
    );
  }

  List<BrushPaintCommand> _byState(BrushPaintCommandState state) =>
      _paintCommands.where((command) => command.state == state).toList()
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
}
