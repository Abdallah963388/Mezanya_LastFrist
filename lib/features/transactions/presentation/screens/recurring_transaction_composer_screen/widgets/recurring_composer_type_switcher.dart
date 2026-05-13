import 'package:flutter/material.dart';

class RecurringComposerTypeSwitcher extends StatelessWidget {
  const RecurringComposerTypeSwitcher({
    super.key,
    required this.isIncome,
    required this.onSelectExpense,
    required this.onSelectIncome,
  });

  final bool isIncome;
  final VoidCallback onSelectExpense;
  final VoidCallback onSelectIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitcherItem(
              selected: !isIncome,
              label: 'Ù…ØµØ±ÙˆÙ',
              icon: Icons.arrow_outward_rounded,
              onTap: onSelectExpense,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SwitcherItem(
              selected: isIncome,
              label: 'Ø¯Ø®Ù„',
              icon: Icons.arrow_downward_rounded,
              onTap: onSelectIncome,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitcherItem extends StatelessWidget {
  const _SwitcherItem({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
