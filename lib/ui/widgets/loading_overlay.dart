import 'package:flutter/material.dart';

class LoadingOverlay {
  static bool _visible = false;

  static Future<void> show(
    BuildContext context, {
    String? message,
    bool barrierDismissible = false,
  }) async {
    if (_visible) return;
    _visible = true;

    await showGeneralDialog(
      context: context,
      barrierLabel: 'Loading',
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return PopScope(
          canPop: barrierDismissible,
          child: SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 180),
                tween: Tween(begin: 0.95, end: 1),
                curve: Curves.easeOut,
                builder: (c, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yuklanmoqda…',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (message != null && message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  message,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _visible = false; // dialog finished
  }

  static void hide(BuildContext context) {
    if (!_visible) return;
    _visible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }
}
