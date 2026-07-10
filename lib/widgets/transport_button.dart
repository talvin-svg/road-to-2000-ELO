import 'package:chess_trainer/theme/app_theme.dart';
import 'package:flutter/material.dart';

// Shared transport control button used by the replay and drill screens.
// Sized with flex so all four buttons fill the available width proportionally.
// The primary variant (next move) uses a gold fill; others are outlined.
class TransportButton extends StatelessWidget {
  const TransportButton({
    required this.icon,
    required this.flex,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final IconData icon;
  final int flex;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    final Color bg =
        primary ? theme.colorScheme.primary : theme.colorScheme.surface;
    final Color fg =
        primary ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Expanded(
      flex: flex,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: primary ? null : Border.all(color: AppTheme.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
