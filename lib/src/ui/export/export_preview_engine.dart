import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The export window's preview loop (EX3): debounced, latest-wins,
/// LRU-cached downscaled renders. Render closures come from the dialog
/// (composite frame, cel, …) so the engine stays generic and unit-testable
/// with injected renders.
///
/// The dialog is modal — the film cannot change under an open preview —
/// so entries live until eviction or dispose; there is no invalidation
/// channel on purpose.
class ExportPreviewController extends ChangeNotifier {
  ExportPreviewController({
    this.debounce = const Duration(milliseconds: 90),
    this.capacity = 24,
  });

  final Duration debounce;
  final int capacity;

  final LinkedHashMap<String, ui.Image> _cache = LinkedHashMap();
  Timer? _debounceTimer;
  int _sequence = 0;
  String? _currentKey;
  ui.Image? _image;
  String? _caption;
  bool _rendering = false;
  bool _disposed = false;

  // The latest request of the debounce window (latest-wins: every new
  // request overwrites these before the timer fires).
  String? _pendingKey;
  String? _pendingCaption;
  Future<ui.Image?> Function()? _pendingRender;

  /// The latest resolved preview picture; null while nothing resolved yet
  /// (the view shows the plan headline instead).
  ui.Image? get image => _image;

  /// The caption of the resolved picture (e.g. `F58`, `A-3`).
  String? get caption => _caption;

  bool get isRendering => _rendering;

  /// Requests the preview identified by [key]. A cache hit lands
  /// immediately; otherwise [render] runs after the debounce window, and
  /// only the LATEST request of the window renders (scrubbing coalesces).
  /// A null render result clears the picture (empty cel).
  void request({
    required String key,
    required String caption,
    required Future<ui.Image?> Function() render,
  }) {
    if (_disposed) {
      return;
    }
    _currentKey = key;
    final hit = _cache.remove(key);
    if (hit != null) {
      // Re-insert = mark most-recently-used.
      _cache[key] = hit;
      _pendingRender = null;
      _debounceTimer?.cancel();
      _setImage(hit, caption);
      return;
    }
    _pendingKey = key;
    _pendingCaption = caption;
    _pendingRender = render;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(_firePending()));
  }

  Future<void> _firePending() async {
    final key = _pendingKey;
    final caption = _pendingCaption;
    final render = _pendingRender;
    _pendingRender = null;
    if (_disposed || key == null || caption == null || render == null) {
      return;
    }
    final ticket = ++_sequence;
    _rendering = true;
    notifyListeners();
    ui.Image? image;
    try {
      image = await render();
    } on Object {
      image = null;
    }
    _finishRender(ticket, key, caption, image);
  }

  /// Test seam (the dialog forwards it): runs the pending debounced
  /// render NOW and awaits it — widget tests call this inside `runAsync`
  /// so the real-async raster completes.
  Future<void> debugFlushPending() {
    _debounceTimer?.cancel();
    return _firePending();
  }

  void _finishRender(int ticket, String key, String caption, ui.Image? image) {
    if (_disposed) {
      image?.dispose();
      return;
    }
    _rendering = false;
    if (ticket != _sequence || key != _currentKey) {
      // A newer request superseded this render mid-flight.
      image?.dispose();
      notifyListeners();
      return;
    }
    if (image != null) {
      _cache[key] = image;
      _evictOverCapacity();
    }
    _setImage(image, caption);
  }

  void _setImage(ui.Image? image, String caption) {
    _image = image;
    _caption = caption;
    notifyListeners();
  }

  void _evictOverCapacity() {
    while (_cache.length > capacity) {
      final oldestKey = _cache.keys.first;
      if (oldestKey == _currentKey) {
        // Never dispose the picture on screen; rotate it to MRU instead.
        final current = _cache.remove(oldestKey)!;
        _cache[oldestKey] = current;
        if (_cache.length <= capacity) {
          break;
        }
        final nextKey = _cache.keys.first;
        _cache.remove(nextKey)!.dispose();
        continue;
      }
      _cache.remove(oldestKey)!.dispose();
    }
  }

  /// Drops every cached picture (a settings change that redefines what
  /// frames look like — the FX toggle — calls this).
  void clear() {
    _debounceTimer?.cancel();
    _pendingRender = null;
    _sequence += 1;
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _image = null;
    _caption = null;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _pendingRender = null;
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _image = null;
    super.dispose();
  }
}

/// The output size that fits [sourceWidth]×[sourceHeight] inside
/// [maxWidth]×[maxHeight] without upscaling; null = render at full size
/// (already small enough).
({int width, int height})? previewOutputSize({
  required int sourceWidth,
  required int sourceHeight,
  required int maxWidth,
  required int maxHeight,
}) {
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    return null;
  }
  final scale = [
    maxWidth / sourceWidth,
    maxHeight / sourceHeight,
    1.0,
  ].reduce((a, b) => a < b ? a : b);
  if (scale >= 1.0) {
    return null;
  }
  return (
    width: (sourceWidth * scale).round().clamp(1, sourceWidth),
    height: (sourceHeight * scale).round().clamp(1, sourceHeight),
  );
}
