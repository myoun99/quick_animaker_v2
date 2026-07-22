import 'package:flutter/material.dart';

import '../../services/runtime_path_report.dart';
import '../theme/app_theme.dart';

/// Preferences ▸ System: the live runtime-path report — which
/// implementation each switchable subsystem is ACTUALLY running (native
/// engine vs Dart fallback, OS codecs vs ffmpeg, Wintab vs plain
/// pointer events).
///
/// User rule (07-22): every runtime-selected path that changes behavior
/// on a real device is listed here, with searchable technology names, so
/// both the developer and end users can see the silent choices and look
/// them up. Fallback rows tint amber — a packaging problem becomes a
/// visible state instead of a mystery slowdown.
class SystemStatusSection extends StatelessWidget {
  const SystemStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = collectRuntimePathReport();
    return Column(
      key: const ValueKey<String>('system-status-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Which implementation each subsystem is running right now. '
          'Fallback paths keep the app working but usually run slower — '
          'the names are searchable if you want the details.',
          style: TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
        const SizedBox(height: 10),
        for (final entry in entries) ...[
          _EntryRow(entry: entry),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final RuntimePathEntry entry;

  @override
  Widget build(BuildContext context) {
    // Selection grammar: state reads through COLOR only (no check
    // marks) — primary = accent, fallback = amber.
    final stateColor = entry.isPrimary
        ? AppColors.accent
        : const Color(0xFFE0A030);
    return Container(
      key: ValueKey<String>('system-status-${entry.subsystem}'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.subsystem,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // The active-path chip sits on its own line — the names are
          // long on purpose (searchable), so they wrap instead of clip.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: stateColor),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                entry.active,
                style: TextStyle(fontSize: 11, color: stateColor),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.detail,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}
