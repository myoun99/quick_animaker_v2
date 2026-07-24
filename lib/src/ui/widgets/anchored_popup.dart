import 'package:flutter/material.dart';

/// The ONE anchored sub-window (R28 #9).
///
/// The brush panel's pressure-curve editor established this shape and the
/// user asked for it to become the shared one: "창 자체는 브러시의 필압설정
/// 하는 열었을때랑 같은거. 그런식으로 서브 창 여는 로직 통일해서 사용. ui
/// 느낌 바꾸면 다른곳에도 적용되게." Everything about how the window
/// behaves — where it lands, how it dismisses, that it appears in one
/// frame — lives here, so restyling it restyles every caller.
///
/// Placement: right-aligned under the anchor, flipped above when there is
/// no room below, and clamped into the overlay either way.
///
/// Dismissal is on pointer DOWN outside, NOT `barrierDismissible` (R27
/// #5): Flutter's modal barrier closes on a completed TAP, so a drag
/// started outside — a slider grab, a canvas stroke — left the popup
/// hanging. "드래그든 뭐든 다른곳 조작하면 사라지도록".
Future<T?> showAnchoredPopup<T>(
  BuildContext anchorContext, {
  required String label,
  required double width,
  required double height,
  required WidgetBuilder builder,
}) {
  final button = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final anchorBottomRight = button.localToGlobal(
    button.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final anchorTopRight = button.localToGlobal(
    Offset(button.size.width, 0),
    ancestor: overlay,
  );
  final left = (anchorBottomRight.dx - width).clamp(
    4.0,
    // A popup wider than the overlay would invert the clamp range.
    (overlay.size.width - width - 4.0).clamp(4.0, double.infinity),
  );
  final below = anchorBottomRight.dy + height <= overlay.size.height - 4;
  final top = below
      ? anchorBottomRight.dy + 2
      : (anchorTopRight.dy - height - 2).clamp(
          4.0,
          (overlay.size.height - height - 4.0).clamp(4.0, double.infinity),
        );
  return showGeneralDialog<T>(
    context: anchorContext,
    barrierLabel: label,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    // Flyout rule (R4 #2): the popup appears in one frame.
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) {
      return Stack(
        children: [
          Positioned.fill(
            key: ValueKey<String>('$label-dismiss-field'),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Builder(builder: builder),
          ),
        ],
      );
    },
  );
}
