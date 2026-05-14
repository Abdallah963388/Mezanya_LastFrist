/// Resolved calendar view for one budget cycle anchor.
class BudgetCycleEntity {
  const BudgetCycleEntity({
    required this.cycleStart,
    required this.cycleEnd,
    required this.isCurrent,
    required this.isPast,
    required this.isFuture,
    required this.cycleKey,
  });

  final DateTime cycleStart;
  final DateTime cycleEnd;
  final bool isCurrent;
  final bool isPast;
  final bool isFuture;
  final String cycleKey;
}
