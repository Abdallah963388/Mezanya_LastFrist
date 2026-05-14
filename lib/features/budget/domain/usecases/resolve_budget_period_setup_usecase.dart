import 'dart:convert';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../entities/budget_setup_entity.dart';

/// Resolves which [BudgetSetupEntity] applies to a given cycle anchor,
/// including monthly snapshots and log fallbacks (legacy screen logic).
class ResolveBudgetPeriodSetupUseCase {
  const ResolveBudgetPeriodSetupUseCase();

  BudgetSetupEntity call({
    required AppStateEntity workspace,
    required DateTime cycleStart,
  }) {
    final budget = workspace.budgetSetup;

    if (_isCurrentCycle(budget, cycleStart)) {
      return workspace.budgetSetup;
    }

    final cycleKey = budget.cycleKeyFor(cycleStart);
    final cycleSnapshot = workspace.monthlyBudgetSnapshots[cycleKey];
    if (cycleSnapshot != null && cycleSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(cycleSnapshot);
    }

    final oldKey =
        '${cycleStart.year}-${cycleStart.month.toString().padLeft(2, '0')}';
    final oldSnapshot = workspace.monthlyBudgetSnapshots[oldKey];
    if (oldSnapshot != null && oldSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(oldSnapshot);
    }

    final end = budget.cycleEndFor(cycleStart);
    for (final log in workspace.logs) {
      if (log.timestamp.isAfter(end)) continue;
      try {
        final map = jsonDecode(log.afterState) as Map<String, dynamic>;
        return AppStateEntity.fromMap(map).budgetSetup;
      } catch (_) {
        continue;
      }
    }
    return workspace.budgetSetup;
  }

  bool _isCurrentCycle(BudgetSetupEntity budget, DateTime cycleStart) {
    final expected = budget.cycleStartFor(DateTime.now());
    return cycleStart.year == expected.year &&
        cycleStart.month == expected.month &&
        cycleStart.day == expected.day;
  }
}
