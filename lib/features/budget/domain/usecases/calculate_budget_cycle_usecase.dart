import '../entities/budget_cycle_entity.dart';
import '../entities/budget_setup_entity.dart';

class CalculateBudgetCycleUseCase {
  const CalculateBudgetCycleUseCase();

  BudgetCycleEntity call({
    required BudgetSetupEntity budget,
    required DateTime cycleAnchor,
  }) {
    final expectedCurrent = budget.cycleStartFor(DateTime.now());
    final cycleStart = DateTime(
      cycleAnchor.year,
      cycleAnchor.month,
      budget.startDay.clamp(1, 28),
    );
    final cycleEnd = budget.cycleEndFor(cycleStart);
    final isCurrent = cycleStart.year == expectedCurrent.year &&
        cycleStart.month == expectedCurrent.month &&
        cycleStart.day == expectedCurrent.day;
    final isFuture = cycleStart.isAfter(expectedCurrent);
    final isPast = cycleStart.isBefore(expectedCurrent);
    return BudgetCycleEntity(
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      isCurrent: isCurrent,
      isPast: isPast,
      isFuture: isFuture,
      cycleKey: budget.cycleKeyFor(cycleStart),
    );
  }

  BudgetCycleEntity shiftByMonths({
    required BudgetSetupEntity budget,
    required BudgetCycleEntity current,
    required int monthDelta,
  }) {
    final nextAnchor = DateTime(
      current.cycleStart.year,
      current.cycleStart.month + monthDelta,
      budget.startDay.clamp(1, 28),
    );
    return call(budget: budget, cycleAnchor: nextAnchor);
  }
}
