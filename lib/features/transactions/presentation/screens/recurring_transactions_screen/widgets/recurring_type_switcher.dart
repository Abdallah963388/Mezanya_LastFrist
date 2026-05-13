import 'package:flutter/material.dart';

class RecurringTypeSwitcher extends StatelessWidget {
  const RecurringTypeSwitcher({
    super.key,
    required this.tab,
    required this.currentAccent,
    required this.onChanged,
  });

  final String tab;
  final Color currentAccent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          _SwitchTile(
            value: 'expense',
            label: 'المصروف',
            icon: Icons.north_east_rounded,
            selected: tab == 'expense',
            currentAccent: currentAccent,
            onTap: onChanged,
          ),
          const SizedBox(width: 8),
          _SwitchTile(
            value: 'income',
            label: 'الدخل',
            icon: Icons.south_west_rounded,
            selected: tab == 'income',
            currentAccent: currentAccent,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.currentAccent,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final Color currentAccent;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.surface : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? currentAccent : null),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? currentAccent : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
