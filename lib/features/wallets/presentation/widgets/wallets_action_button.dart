import 'package:flutter/material.dart';

class WalletsActionButton extends StatelessWidget {
  const WalletsActionButton({
    super.key,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? accent : const Color(0xFFBDB5A8);
    final bg = enabled
        ? accent.withValues(alpha: 0.10)
        : const Color(0xFFE8E0D6).withValues(alpha: 0.60);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: effectiveColor.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: effectiveColor, size: 20),
        ),
      ),
    );
  }
}
