import '../../domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';

class BudgetRecurringPlanService {
  const BudgetRecurringPlanService._();

  static RecurringTransactionEntity? linkedRecurring(
    Iterable<RecurringTransactionEntity> recurringTransactions,
    DebtEntity debt,
  ) {
    if ((debt.recurringTransactionId ?? '').isNotEmpty) {
      final exact = recurringTransactions.where(
        (item) =>
            item.type == 'expense' &&
            item.budgetScope == 'within-budget' &&
            item.isDebtOrSubscription &&
            item.id == debt.recurringTransactionId,
      );
      if (exact.isNotEmpty) {
        return exact.first;
      }
    }

    final fallback = recurringTransactions.where(
      (item) =>
          item.type == 'expense' &&
          item.budgetScope == 'within-budget' &&
          item.isDebtOrSubscription &&
          item.name == debt.name,
    );
    return fallback.isEmpty ? null : fallback.first;
  }

  static bool isDueInCycle({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    if (debt.isInstallment) {
      return true;
    }
    if (recurring != null) {
      return RecurringScheduleEngine.hasOccurrenceInRange(
        recurring,
        cycleStart,
        cycleEnd,
      );
    }
    return debt.isDueInCycle(cycleStart, cycleEnd);
  }

  static int occurrencesInCycle({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    if (debt.isInstallment) {
      return 1;
    }
    if (recurring != null) {
      return RecurringScheduleEngine.occurrencesInRange(
        recurring,
        cycleStart,
        cycleEnd,
      );
    }
    return debt.occurrencesInCycle(cycleStart, cycleEnd);
  }

  static double amountPerOccurrence({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
  }) {
    final amount = recurring?.amount ?? debt.amount;
    return amount < 0 ? 0 : amount;
  }

  static double amountDueInCycle({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    if (debt.isInstallment) {
      return amountPerOccurrence(debt: debt, recurring: recurring);
    }
    final occurrences = occurrencesInCycle(
      debt: debt,
      recurring: recurring,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
    );
    return amountPerOccurrence(debt: debt, recurring: recurring) * occurrences;
  }

  static double pendingDecisionAmount({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required double cyclePaid,
  }) {
    final perOccurrence = amountPerOccurrence(
      debt: debt,
      recurring: recurring,
    );
    if (debt.isSubscription) {
      return perOccurrence;
    }
    final remaining = perOccurrence - cyclePaid;
    return remaining > 0 ? remaining : 0;
  }
}
