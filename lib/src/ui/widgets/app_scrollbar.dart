import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How a press on the lane (outside the thumb) behaves.
enum AppScrollbarLanePress {
  /// Press/tap centers the thumb at the pointer, then drags relatively
  /// (timeline rails, panel scrollables).
  jumpToPointer,

  /// The whole lane is a relative drag surface: the thumb moves 1:1 with
  /// the pointer no matter where the press lands (canvas panbars).
  relativeDrag,
}

/// Pure scrollbar geometry shared by every scrollbar in the app.
///
/// When there is nothing to scroll the thumb fills the whole lane — both
/// the canvas panbars and the timeline rails pin that behavior.
class AppScrollbarGeometry {
  AppScrollbarGeometry({
    required double trackExtent,
    required double viewportExtent,
    required double contentExtent,
    required double offset,
    required this.minThumbExtent,
  }) : trackExtent = _finiteNonNegative(trackExtent),
       viewportExtent = _finiteNonNegative(viewportExtent),
       contentExtent = _finiteNonNegative(contentExtent) {
    maxScroll = (this.contentExtent - this.viewportExtent)
        .clamp(0.0, double.infinity)
        .toDouble();
    canScroll = maxScroll > 0 && this.trackExtent > 0;
    if (!canScroll) {
      thumbExtent = this.trackExtent;
      thumbTravel = 0;
      thumbStart = 0;
      this.offset = 0;
      return;
    }
    final proportionalExtent =
        this.viewportExtent / this.contentExtent * this.trackExtent;
    final safeMinimum = minThumbExtent.clamp(0.0, this.trackExtent).toDouble();
    thumbExtent = proportionalExtent
        .clamp(safeMinimum, this.trackExtent)
        .toDouble();
    thumbTravel = (this.trackExtent - thumbExtent)
        .clamp(0.0, double.infinity)
        .toDouble();
    this.offset = offset.clamp(0.0, maxScroll).toDouble();
    thumbStart = thumbTravel == 0 ? 0 : this.offset / maxScroll * thumbTravel;
  }

  final double trackExtent;
  final double viewportExtent;
  final double contentExtent;
  final double minThumbExtent;
  late final double offset;
  late final double maxScroll;
  late final bool canScroll;
  late final double thumbExtent;
  late final double thumbTravel;
  late final double thumbStart;

  double offsetForThumbStart(double thumbStart) {
    if (!canScroll || thumbTravel <= 0) {
      return 0;
    }
    final clamped = thumbStart.clamp(0.0, thumbTravel).toDouble();
    return clamped / thumbTravel * maxScroll;
  }

  bool containsThumb(double axisPosition) =>
      axisPosition >= thumbStart && axisPosition <= thumbStart + thumbExtent;

  static double _finiteNonNegative(double value) {
    if (!value.isFinite || value <= 0) {
      return 0;
    }
    return value;
  }
}

/// The app-wide scrollbar visual: no track, a thin grey thumb that
/// brightens on hover and turns accent while dragged. Parents supply the
/// hit lane (12-14px) — the thumb stays visually thin inside it.
///
/// Fully controlled: position comes from [offset] against
/// [viewportExtent]/[contentExtent]; interactions emit absolute offsets
/// through [onOffsetChanged]. [onChangeEnd] fires once per drag on both
/// end and cancel (the canvas panbar sync contract).
class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    super.key,
    required this.axis,
    required this.offset,
    required this.viewportExtent,
    required this.contentExtent,
    required this.onOffsetChanged,
    this.onChangeEnd,
    this.lanePress = AppScrollbarLanePress.jumpToPointer,
    this.minThumbExtent = 28,
    this.thumbKey,
    this.laneKey,
  });

  final Axis axis;
  final double offset;
  final double viewportExtent;
  final double contentExtent;
  final ValueChanged<double> onOffsetChanged;
  final VoidCallback? onChangeEnd;
  final AppScrollbarLanePress lanePress;
  final double minThumbExtent;
  final Key? thumbKey;
  final Key? laneKey;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar> {
  static const double _idleThickness = 4;
  static const double _activeThickness = 6;
  static const Duration _stateAnimation = Duration(milliseconds: 100);

  bool _hovered = false;
  bool _dragging = false;
  double? _dragThumbStart;
  double? _dragPointerStart;

  AppScrollbarGeometry _geometry(double trackExtent) => AppScrollbarGeometry(
    trackExtent: trackExtent,
    viewportExtent: widget.viewportExtent,
    contentExtent: widget.contentExtent,
    offset: widget.offset,
    minThumbExtent: widget.minThumbExtent,
  );

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackExtent = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final geometry = _geometry(trackExtent);
        final active = _dragging || _hovered;
        final thickness = active ? _activeThickness : _idleThickness;
        final color = _dragging
            ? AppColors.accent
            : _hovered
            ? AppColors.textDim
            : AppColors.hairlineStrong;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.lanePress == AppScrollbarLanePress.jumpToPointer
              ? (details) =>
                    _lanePressed(_axisPosition(details.localPosition), geometry)
              : null,
          onHorizontalDragStart: horizontal
              ? (details) =>
                    _dragStart(_axisPosition(details.localPosition), geometry)
              : null,
          onVerticalDragStart: horizontal
              ? null
              : (details) =>
                    _dragStart(_axisPosition(details.localPosition), geometry),
          onHorizontalDragUpdate: horizontal
              ? (details) =>
                    _dragUpdate(_axisPosition(details.localPosition), geometry)
              : null,
          onVerticalDragUpdate: horizontal
              ? null
              : (details) =>
                    _dragUpdate(_axisPosition(details.localPosition), geometry),
          onHorizontalDragEnd: horizontal ? (_) => _dragEnd() : null,
          onVerticalDragEnd: horizontal ? null : (_) => _dragEnd(),
          onHorizontalDragCancel: horizontal ? _dragEnd : null,
          onVerticalDragCancel: horizontal ? null : _dragEnd,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: SizedBox.expand(key: widget.laneKey),
                ),
                Positioned(
                  left: horizontal ? geometry.thumbStart : 0,
                  right: horizontal ? null : 0,
                  top: horizontal ? 0 : geometry.thumbStart,
                  bottom: horizontal ? 0 : null,
                  width: horizontal ? geometry.thumbExtent : null,
                  height: horizontal ? null : geometry.thumbExtent,
                  child: Center(
                    child: AnimatedContainer(
                      key: widget.thumbKey,
                      duration: _stateAnimation,
                      curve: Curves.easeOut,
                      width: horizontal ? double.infinity : thickness,
                      height: horizontal ? thickness : double.infinity,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(thickness / 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _axisPosition(Offset localPosition) =>
      widget.axis == Axis.horizontal ? localPosition.dx : localPosition.dy;

  void _lanePressed(double position, AppScrollbarGeometry geometry) {
    if (!geometry.canScroll || geometry.containsThumb(position)) {
      return;
    }
    widget.onOffsetChanged(
      geometry.offsetForThumbStart(position - geometry.thumbExtent / 2),
    );
  }

  void _dragStart(double position, AppScrollbarGeometry geometry) {
    if (!geometry.canScroll) {
      return;
    }
    var thumbStart = geometry.thumbStart;
    if (widget.lanePress == AppScrollbarLanePress.jumpToPointer &&
        !geometry.containsThumb(position)) {
      thumbStart = (position - geometry.thumbExtent / 2)
          .clamp(0.0, geometry.thumbTravel)
          .toDouble();
      widget.onOffsetChanged(geometry.offsetForThumbStart(thumbStart));
    }
    _dragThumbStart = thumbStart;
    _dragPointerStart = position;
    setState(() => _dragging = true);
  }

  void _dragUpdate(double position, AppScrollbarGeometry geometry) {
    final dragThumbStart = _dragThumbStart;
    final dragPointerStart = _dragPointerStart;
    if (dragThumbStart == null || dragPointerStart == null) {
      return;
    }
    if (!geometry.canScroll) {
      return;
    }
    final nextThumbStart = (dragThumbStart + (position - dragPointerStart))
        .clamp(0.0, geometry.thumbTravel)
        .toDouble();
    widget.onOffsetChanged(geometry.offsetForThumbStart(nextThumbStart));
  }

  void _dragEnd() {
    final wasDragging = _dragThumbStart != null;
    _dragThumbStart = null;
    _dragPointerStart = null;
    if (_dragging) {
      setState(() => _dragging = false);
    }
    if (wasDragging) {
      widget.onChangeEnd?.call();
    }
  }
}

/// [AppScrollbar] driven by a [ScrollController].
///
/// Extents come from the attached position; before attachment (or while
/// dimensions are unknown) the fallback extents keep the thumb meaningful —
/// the timeline rails pass their layout-derived sizes there.
class AppControllerScrollbar extends StatefulWidget {
  const AppControllerScrollbar({
    super.key,
    required this.controller,
    required this.axis,
    this.lanePress = AppScrollbarLanePress.jumpToPointer,
    this.minThumbExtent = 28,
    this.fallbackViewportExtent,
    this.fallbackContentExtent,
    this.thumbKey,
    this.laneKey,
  });

  final ScrollController controller;
  final Axis axis;
  final AppScrollbarLanePress lanePress;
  final double minThumbExtent;
  final double? fallbackViewportExtent;
  final double? fallbackContentExtent;
  final Key? thumbKey;
  final Key? laneKey;

  @override
  State<AppControllerScrollbar> createState() => _AppControllerScrollbarState();
}

class _AppControllerScrollbarState extends State<AppControllerScrollbar> {
  bool _attachRetryUsed = false;

  bool get _hasDimensions =>
      widget.controller.hasClients &&
      widget.controller.position.hasContentDimensions;

  @override
  Widget build(BuildContext context) {
    // A ScrollController does not notify on attach, so the first build can
    // race the scrollable's layout. Retry once on the next frame; further
    // updates arrive through offset notifications or host rebuilds.
    if (!_hasDimensions && !_attachRetryUsed) {
      _attachRetryUsed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else if (_hasDimensions) {
      _attachRetryUsed = false;
    }
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        var viewportExtent = widget.fallbackViewportExtent ?? 0.0;
        var contentExtent = widget.fallbackContentExtent ?? 0.0;
        var offset = 0.0;
        if (_hasDimensions) {
          final position = widget.controller.position;
          viewportExtent = position.viewportDimension;
          contentExtent = position.viewportDimension + position.maxScrollExtent;
          offset = position.pixels;
        }
        return AppScrollbar(
          axis: widget.axis,
          offset: offset,
          viewportExtent: viewportExtent,
          contentExtent: contentExtent,
          lanePress: widget.lanePress,
          minThumbExtent: widget.minThumbExtent,
          thumbKey: widget.thumbKey,
          laneKey: widget.laneKey,
          onOffsetChanged: _jumpTo,
        );
      },
    );
  }

  void _jumpTo(double offset) {
    if (!_hasDimensions) {
      return;
    }
    widget.controller.jumpTo(
      offset
          .clamp(0.0, widget.controller.position.maxScrollExtent)
          .toDouble(),
    );
  }
}
