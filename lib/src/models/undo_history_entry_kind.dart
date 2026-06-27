enum UndoHistoryEntryKind {
  paintStroke,
  eraseStroke,
  clearFrameDrawing,
  fillFrameDrawing,
  createFrame,
  deleteFrame,
  moveFrame,
  createLayer,
  deleteLayer,
  renameLayer,
  reorderLayer,
  changeCutDuration,
  createCut,
  deleteCut,
}

enum UndoHistoryScope { brushFrame, project, timeline, layer, cut }
