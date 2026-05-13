import 'package:flutter/material.dart';

class RecurringAddButton extends StatelessWidget {
  const RecurringAddButton({
    super.key,
    required this.tab,
    required this.onPressed,
    required this.expenseAccent,
    required this.incomeAccent,
  });

  final String tab;
  final VoidCallback onPressed;
  final Color expenseAccent;
  final Color incomeAccent;

  @override
  Widget build(BuildContext context) {
    final isExpense = tab == 'expense';
    final color = isExpense ? expenseAccent : incomeAccent;
    final icon = isExpense ? Icons.north_east_rounded : Icons.south_west_rounded;
    final label = isExpense ? 'إضافة مصروف متكرر' : 'إضافة دخل متكرر';

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
