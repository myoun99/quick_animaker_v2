import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one dialog shell every layer kind's "instance edit" flow uses —
/// entrance unification's visual half. Owning the chrome here (accent
/// title band, body scroll, preview slot, action row with stable keys)
/// means a future redesign touches exactly one file.
///
/// Keys: 'instance-edit-dialog' on the surface and
/// 'instance-edit-ok/cancel/delete-button' on the actions, shared across
/// kinds so tests and muscle memory transfer.
class InstanceEditDialogShell extends StatelessWidget {
  const InstanceEditDialogShell({
    super.key,
    required this.title,
    this.titleIcon,
    required this.body,
    this.preview,
    required this.onSubmit,
    this.onDelete,
    this.submitLabel = 'OK',
  });

  final String title;
  final IconData? titleIcon;

  /// Kind-specific field column; scrolls when tall (long SE dialogue), the
  /// preview below keeps its height.
  final Widget body;

  /// Live preview pane ([InstanceEditPreview] usually); null hides the slot.
  final Widget? preview;

  /// Null disables the OK button (e.g. nothing selected yet).
  final VoidCallback? onSubmit;

  /// Non-null shows the Delete action.
  final VoidCallback? onDelete;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      key: const ValueKey<String>('instance-edit-dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 380, maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: body,
                  ),
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Preview',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                preview!,
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onDelete != null)
                    TextButton(
                      key: const ValueKey<String>('instance-edit-delete-button'),
                      onPressed: onDelete,
                      child: const Text('Delete'),
                    ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey<String>('instance-edit-cancel-button'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey<String>('instance-edit-ok-button'),
                    onPressed: onSubmit,
                    child: Text(submitLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
