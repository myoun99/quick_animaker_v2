import 'dart:math' as math;

import 'package:flutter/material.dart';

/// UI-R17 #5: the COMMON "reveal what's already open" affordance —
/// asking to open a panel that is already on screen FLASHES it in place
/// instead of doing nothing, so the user learns where it lives. One
/// controller per workspace; every panel host renders the blink when its
/// own tab fires. Every future "open panel" entry point routes through
/// the workspace's revealPanel, which uses this.
class PanelFlashRequest {
  const PanelFlashRequest({required this.tabId, required this.seq});

  final String tabId;

  /// Monotonic per request, so flashing the same tab twice re-triggers.
  final int seq;
}

class PanelFlashController {
  final ValueNotifier<PanelFlashRequest?> requests =
      ValueNotifier<PanelFlashRequest?>(null);

  void flash(String tabId) {
    requests.value = PanelFlashRequest(
      tabId: tabId,
      seq: (requests.value?.seq ?? 0) + 1,
    );
  }

  void dispose() => requests.dispose();
}

/// The blink itself: three accent pulses fading out over ~a second,
/// overlaid on the panel body (pointer-transparent).
class PanelFlashOverlay extends StatelessWidget {
  const PanelFlashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1050),
      builder: (context, t, _) {
        // Three raised-cosine pulses, decaying toward the end.
        final pulse = 0.5 - 0.5 * math.cos(t * 3 * 2 * math.pi);
        final alpha = pulse * (1 - t);
        if (alpha <= 0.01) {
          return const SizedBox.shrink();
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10 * alpha),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.9 * alpha),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
