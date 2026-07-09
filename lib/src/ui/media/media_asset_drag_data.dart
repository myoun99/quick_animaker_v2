/// Drag payload for media-browser assets: the browser's list rows are
/// draggable and SE blocks accept drops of exactly this type (a dedicated
/// class so panel-tab drags and any future string payloads never collide).
class MediaAssetDragData {
  const MediaAssetDragData({required this.path, required this.name});

  /// The pool key ([MediaAsset.path]) the drop links to the block's frame.
  final String path;

  /// Display name for the drag feedback chip.
  final String name;
}
