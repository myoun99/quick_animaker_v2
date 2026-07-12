// The BRUSH LAB (R13): the real app plus an in-app auto-stroker and a
// frame-timing logger — the on-device instrument behind "no lag, ever".
//
//   flutter run -d windows -t lib/dev/brush_lab_main.dart
//
// It boots the production HomePage and replays a real WORKFLOW: cels on six
// frames, onion skin on, strokes alternating brush/eraser while hopping
// between the frames — all through the REAL pointer pipeline
// (WidgetsBinding.handlePointerEvent) aimed at the CANVAS panel (never the
// timesheet's ink plane). Engine FrameTimings are bucketed into
// build/raster percentiles, janky-frame counts and process RSS — the curve
// that test-environment benchmarks cannot see. Nothing here runs in
// production; the entrypoint exists so any future brush regression is one
// command away from a measured verdict.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../src/ui/brush/brush_tool_state.dart';
import '../src/ui/canvas/interactive_brush_edit_canvas_view.dart';
import '../src/ui/editor_workspace.dart';
import '../src/ui/home_page.dart';
import '../src/ui/theme/app_theme.dart';

void main() {
  runApp(const _BrushLabApp());
}

class _BrushLabApp extends StatelessWidget {
  const _BrushLabApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickAnimaker Brush Lab',
      theme: buildAppTheme(),
      home: const _BrushLabDriver(child: HomePage()),
    );
  }
}

class _BrushLabDriver extends StatefulWidget {
  const _BrushLabDriver({required this.child});

  final Widget child;

  @override
  State<_BrushLabDriver> createState() => _BrushLabDriverState();
}

/// One A/B phase of the lab run: which workflow ingredients are active.
class _LabPhase {
  const _LabPhase(this.label, {
    required this.hopFrames,
    required this.onion,
    required this.alternateTools,
    this.hopDissect = 0,
    this.bigBrush = false,
  });

  final String label;
  final bool hopFrames;
  final bool onion;
  final bool alternateTools;

  /// 1 = move the editing frame CURSOR only; 2 = additionally bump
  /// frameSeekCommitted WITHOUT changing the frame (the seek fan-out
  /// rebuild alone, same cel).
  final int hopDissect;

  /// R13-3: the user's reported worst case — a LARGE brush while flipping.
  /// Big strokes dirty many tiles, so every commit invalidates wide and the
  /// prerender warmer has maximal work to collide with.
  final bool bigBrush;
}

class _BrushLabDriverState extends State<_BrushLabDriver> {
  static const int strokesPerBucket = 30;
  static const int bucketsPerPhase = 3;
  static const int movesPerStroke = 24;
  static const int frameCount = 6;

  /// Attribution ladder: each phase adds ONE ingredient, so the jank delta
  /// between consecutive phases names its cost. The hop-dissection phases
  /// fire the seek's PARTS separately (all public notifiers) to name which
  /// consumer owns the flip hitch.
  static const List<_LabPhase> phases = [
    _LabPhase('strokes-only', hopFrames: false, onion: false, alternateTools: false),
    _LabPhase('hop-cursor-only', hopFrames: false, onion: false, alternateTools: false, hopDissect: 1),
    _LabPhase('hop-seek-same-frame', hopFrames: false, onion: false, alternateTools: false, hopDissect: 2),
    _LabPhase('hop-full', hopFrames: true, onion: false, alternateTools: false),
    _LabPhase('+onion', hopFrames: true, onion: true, alternateTools: false),
    _LabPhase('+tools(full)', hopFrames: true, onion: true, alternateTools: true),
    _LabPhase('+bigbrush-flipdraw', hopFrames: true, onion: true, alternateTools: false, bigBrush: true),
  ];

  final List<int> _buildMicros = <int>[];
  final List<int> _rasterMicros = <int>[];
  late final TimingsCallback _timingsCallback;
  int _pointerId = 100;

  @override
  void initState() {
    super.initState();
    _timingsCallback = (List<FrameTiming> timings) {
      for (final timing in timings) {
        _buildMicros.add(timing.buildDuration.inMicroseconds);
        _rasterMicros.add(timing.rasterDuration.inMicroseconds);
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
    unawaited(_run());
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    super.dispose();
  }

  Future<void> _run() async {
    // Let the workspace restore/settle before driving it.
    await Future<void>.delayed(const Duration(seconds: 3));
    final workspaceElement = _findByType<EditorWorkspace>();
    if (workspaceElement == null) {
      _log('ABORT: EditorWorkspace not found');
      return;
    }
    final workspace = workspaceElement.widget as EditorWorkspace;
    final session = workspace.session;
    final brushTool = workspace.brushTool;
    _log('lab starting (phase-ladder mode)');

    // Author a cel on each workflow frame.
    for (var frame = 0; frame < frameCount; frame += 1) {
      session.selectFrameIndex(frame);
      await _settleFrames(2);
      if (session.activeBrushEditorSelection == null) {
        session.createDrawingAtCurrentFrame();
        await _settleFrames(4);
      }
    }
    if (_canvasView() == null) {
      _log('ABORT: canvas-panel interactive view not found');
      return;
    }

    var strokeIndex = 0;
    for (final phase in phases) {
      session.onionSkinSettings.value = session.onionSkinSettings.value
          .copyWith(enabled: phase.onion);
      if (brushTool != null) {
        brushTool.value = brushTool.value.copyWith(
          tool: CanvasTool.brush,
          size: phase.bigBrush
              ? BrushToolState.maxSize
              : BrushToolState.defaultSize,
        );
      }
      session.selectFrameIndex(0);
      await _settleFrames(4);

      for (var bucket = 0; bucket < bucketsPerPhase; bucket += 1) {
        _buildMicros.clear();
        _rasterMicros.clear();
        final watch = Stopwatch()..start();
        for (var s = 0; s < strokesPerBucket; s += 1) {
          strokeIndex += 1;

          if (phase.hopFrames) {
            // Hop frames like real animation work (exercises the session
            // LRU too: 6 frames > the 4-session budget).
            session.selectFrameIndex(strokeIndex % frameCount);
            await _settleFrames(2);
          } else if (phase.hopDissect == 1) {
            session.editingFrameCursor.value = strokeIndex % frameCount;
            await _settleFrames(1);
            session.editingFrameCursor.value = 0;
            await _settleFrames(1);
          } else if (phase.hopDissect == 2) {
            session.editingFrameCursor.value = 0;
            session.frameSeekCommitted.value += 1;
            await _settleFrames(2);
          }

          if (phase.alternateTools && brushTool != null) {
            final tool = strokeIndex.isEven
                ? CanvasTool.brush
                : CanvasTool.eraser;
            if (brushTool.value.tool != tool) {
              brushTool.value = brushTool.value.copyWith(tool: tool);
              await _settleFrames(1);
            }
          }

          final canvas = _canvasView();
          if (canvas == null) {
            _log('ABORT: canvas lost mid-run');
            return;
          }
          final rect = _rectOf(canvas).deflate(30);
          final start = Offset(
            rect.left + (strokeIndex * 17.0) % (rect.width - 120),
            rect.top + (strokeIndex * 11.0) % (rect.height - 80),
          );
          await _stroke(start);
        }
        watch.stop();
        _logBucket(phase.label, bucket, watch.elapsedMilliseconds);
      }
    }
    _log('lab DONE');
  }

  /// The CANVAS panel's interactive view — scoped under the main canvas
  /// brush host so the timesheet's ink plane can never be mistaken for it.
  Element? _canvasView() {
    final host = _findByKey(const ValueKey<String>('main-canvas-brush-host'));
    if (host == null) {
      return null;
    }
    Element? result;
    void visit(Element element) {
      if (result != null) {
        return;
      }
      if (element.widget is InteractiveBrushEditCanvasView) {
        result = element;
        return;
      }
      element.visitChildren(visit);
    }

    host.visitChildren(visit);
    return result;
  }

  Future<void> _stroke(Offset start) async {
    final pointer = _pointerId++;
    _event(
      PointerDownEvent(
        pointer: pointer,
        kind: PointerDeviceKind.stylus,
        position: start,
        pressure: 0.8,
      ),
    );
    var position = start;
    for (var move = 0; move < movesPerStroke; move += 1) {
      await _nextFrame();
      // Two samples per frame, like real pen input outpacing vsync.
      for (var sample = 0; sample < 2; sample += 1) {
        final previous = position;
        position += const Offset(3.5, 2.0);
        _event(
          PointerMoveEvent(
            pointer: pointer,
            kind: PointerDeviceKind.stylus,
            position: position,
            delta: position - previous,
            pressure: 0.8,
          ),
        );
      }
    }
    _event(
      PointerUpEvent(
        pointer: pointer,
        kind: PointerDeviceKind.stylus,
        position: position,
      ),
    );
    // Let the pen-up fan-out (commit, decode burst, settle) land inside
    // the bucket's timings.
    await _settleFrames(6);
  }

  void _event(PointerEvent event) {
    WidgetsBinding.instance.handlePointerEvent(event);
  }

  Future<void> _settleFrames(int count) async {
    for (var i = 0; i < count; i += 1) {
      await _nextFrame();
    }
  }

  Future<void> _nextFrame() {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
    return completer.future;
  }

  void _logBucket(String phase, int bucket, int elapsedMs) {
    final build = List<int>.of(_buildMicros)..sort();
    final raster = List<int>.of(_rasterMicros)..sort();
    String pct(List<int> sorted, double p) {
      if (sorted.isEmpty) {
        return '-';
      }
      final index = ((sorted.length - 1) * p).round();
      return (sorted[index] / 1000.0).toStringAsFixed(1);
    }

    final jank = raster.where((r) => r > 16000).length +
        build.where((b) => b > 16000).length;
    _log(
      '$phase bucket ${(bucket + 1) * strokesPerBucket} strokes | '
      'frames ${build.length} in ${elapsedMs}ms | '
      'build p50 ${pct(build, 0.5)} p95 ${pct(build, 0.95)} '
      'worst ${pct(build, 1.0)}ms | '
      'raster p50 ${pct(raster, 0.5)} p95 ${pct(raster, 0.95)} '
      'worst ${pct(raster, 1.0)}ms | '
      'jank>16ms $jank | '
      'rss ${(ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(0)}MB',
    );
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[brush-lab] $message');
  }

  Element? _findByKey(Key key) {
    Element? result;
    void visit(Element element) {
      if (result != null) {
        return;
      }
      if (element.widget.key == key) {
        result = element;
        return;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return result;
  }

  Element? _findByType<T extends Widget>() {
    Element? result;
    void visit(Element element) {
      if (result != null) {
        return;
      }
      if (element.widget is T) {
        result = element;
        return;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return result;
  }

  Rect _rectOf(Element element) {
    final box = element.renderObject! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
