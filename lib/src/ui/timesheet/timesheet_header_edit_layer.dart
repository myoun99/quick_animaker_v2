import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/canvas_viewport.dart';
import '../../models/timesheet_info.dart';
import '../theme/app_theme.dart';
import 'timesheet_document_painter.dart';

/// Tap-to-edit for the sheet's typed header text: the TimesheetInfo-backed
/// header boxes (TITLE / # / SCENE / NAME) and the Direction memo band
/// (the per-cut note) take a tap and swap in a TextField positioned right
/// over the box under the panel viewport transform — editing in place on
/// the paper.
///
/// The layer sits UNDER the ink layer in the sheet stack, so the sheet-ink
/// toggle is the mode switch: ink allowed → the pen draws (taps included,
/// like a pen on paper); ink blocked → taps edit text. Derived boxes
/// (CUT / TIME / SHEET) stay read-only.
class TimesheetHeaderEditLayer extends StatefulWidget {
  const TimesheetHeaderEditLayer({
    super.key,
    required this.layout,
    required this.viewport,
    required this.onHeaderFieldCommitted,
    required this.onMemoCommitted,
  });

  final TimesheetDocumentLayout layout;

  /// The live panel viewport (the same transform the document painter
  /// applies).
  final CanvasViewport viewport;

  /// Commits an edited header box (editable fields only). The layer skips
  /// the callback when the text did not change.
  final void Function(TimesheetHeaderField field, String text)
  onHeaderFieldCommitted;

  /// Commits the edited Direction memo (the cut note).
  final ValueChanged<String> onMemoCommitted;

  /// The header boxes whose text lives on [TimesheetInfo] — the ones a tap
  /// edits.
  static const Set<TimesheetHeaderField> editableFields = {
    TimesheetHeaderField.title,
    TimesheetHeaderField.episode,
    TimesheetHeaderField.scene,
    TimesheetHeaderField.name,
  };

  @override
  State<TimesheetHeaderEditLayer> createState() =>
      _TimesheetHeaderEditLayerState();
}

/// What is being edited: a header box or (field == null) the memo band.
typedef _EditTarget = ({TimesheetHeaderField? field, Rect documentRect});

class _TimesheetHeaderEditLayerState extends State<TimesheetHeaderEditLayer> {
  _EditTarget? _target;
  TextEditingController? _controller;
  FocusNode? _focusNode;
  String _initialText = '';
  bool _cancelled = false;

  @override
  void dispose() {
    _disposeEditor();
    super.dispose();
  }

  void _disposeEditor() {
    _controller?.dispose();
    _controller = null;
    _focusNode?.dispose();
    _focusNode = null;
  }

  Rect _screenRect(Rect documentRect) {
    final viewport = widget.viewport;
    return Rect.fromLTWH(
      viewport.panX + viewport.zoom * documentRect.left,
      viewport.panY + viewport.zoom * documentRect.top,
      viewport.zoom * documentRect.width,
      viewport.zoom * documentRect.height,
    );
  }

  String _valueFor(TimesheetHeaderField? field) {
    final document = widget.layout.document;
    if (field == null) {
      return document.memoText;
    }
    return switch (field) {
      TimesheetHeaderField.title => document.title,
      TimesheetHeaderField.episode => document.episode,
      TimesheetHeaderField.scene => document.scene,
      TimesheetHeaderField.name => document.artist,
      _ => '',
    };
  }

  void _beginEdit(TimesheetHeaderField? field, Rect documentRect) {
    _disposeEditor();
    _initialText = _valueFor(field);
    _cancelled = false;
    _controller = TextEditingController(text: _initialText);
    _focusNode = FocusNode();
    _focusNode!.addListener(() {
      if (!(_focusNode?.hasFocus ?? false)) {
        _commit();
      }
    });
    setState(() {
      _target = (field: field, documentRect: documentRect);
    });
  }

  void _commit() {
    final target = _target;
    final controller = _controller;
    if (!mounted || target == null || controller == null) {
      return;
    }
    final text = controller.text.trim();
    final changed = !_cancelled && text != _initialText.trim();
    setState(() {
      _target = null;
    });
    if (!changed) {
      return;
    }
    if (target.field == null) {
      widget.onMemoCommitted(text);
    } else {
      widget.onHeaderFieldCommitted(target.field!, text);
    }
  }

  void _cancel() {
    _cancelled = true;
    setState(() {
      _target = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final document = layout.document;
    final target = _target;
    // The header repeats on every paper page; the continuous strip has one.
    final pageCount = layout.continuous ? 1 : document.pages.length;

    return Stack(
      children: [
        if (target == null) ...[
          for (var page = 0; page < pageCount; page += 1) ...[
            for (final box in layout.headerFieldBoxes(page))
              if (TimesheetHeaderEditLayer.editableFields.contains(box.field))
                _tapZone(
                  key: ValueKey<String>(
                    'timesheet-header-edit-${box.field.name}-p$page',
                  ),
                  documentRect: box.rect,
                  onTap: () => _beginEdit(box.field, box.rect),
                ),
            _tapZone(
              key: ValueKey<String>('timesheet-memo-edit-p$page'),
              documentRect: layout.memoBandRect(page),
              onTap: () => _beginEdit(null, layout.memoBandRect(page)),
            ),
          ],
        ] else ...[
          // Tap-away barrier: clicking anywhere else commits the edit.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _focusNode?.unfocus(),
            ),
          ),
          _buildEditor(target),
        ],
      ],
    );
  }

  Widget _tapZone({
    required Key key,
    required Rect documentRect,
    required VoidCallback onTap,
  }) {
    final rect = _screenRect(documentRect);
    return Positioned(
      key: key,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
    );
  }

  Widget _buildEditor(_EditTarget target) {
    final zoom = widget.viewport.zoom;
    final rect = _screenRect(target.documentRect);
    final memo = target.field == null;
    // WYSIWYG-ish: the editor text tracks the printed size under zoom.
    final fontSize = (memo ? 11.0 : 14.0) * zoom;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _cancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.accent, width: 1.5),
          ),
          alignment: memo ? Alignment.topLeft : Alignment.bottomLeft,
          child: TextField(
            key: const ValueKey<String>('timesheet-header-edit-field'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            maxLines: memo ? null : 1,
            expands: memo,
            onSubmitted: memo ? null : (_) => _commit(),
            style: TextStyle(
              color: const Color(0xFF33322F),
              fontSize: fontSize,
              fontWeight: memo ? FontWeight.w400 : FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8 * zoom,
                vertical: 6 * zoom,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
