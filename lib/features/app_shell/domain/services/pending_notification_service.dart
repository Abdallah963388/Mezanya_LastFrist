import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../budget/domain/services/budget_recurring_plan_service.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';

class PendingNotificationService {
  const PendingNotificationService._();

  static int count(AppStateEntity state, DateTime now) {
    final month = DateTime(now.year, now.month, 1);
    final budget = state.budgetSetup;
    final cycleStart = budget.cycleStartFor(now);
    final cycleEnd = budget.cycleEndFor(now);

    final monthTransactions = state.transactions.where((transaction) {
      return transaction.createdAt.year == month.year &&
          transaction.createdAt.month == month.month;
    }).toList();
    final cycleTransactions = state.transactions.where((transaction) {
      return !transaction.createdAt.isBefore(cycleStart) &&
          !transaction.createdAt.isAfter(cycleEnd);
    }).toList();
    final incomeTransactions = monthTransactions
        .where((transaction) => transaction.type == 'income')
        .toList();

    var count = 0;

    for (final income in budget.incomeSources) {
      if (income.isVariable ||
          incomeTransactions.any(
            (transaction) => transaction.incomeSourceId == income.id,
          )) {
        continue;
      }

      final recurringTransactions = state.recurringTransactions.where(
        (item) =>
            item.type == 'income' &&
            item.budgetScope == 'within-budget' &&
            item.incomeSourceId == income.id,
      );
      final recurring = recurringTransactions.isEmpty
          ? null
          : recurringTransactions.first;
      final dueDate = DateTime(month.year, month.month, income.date.clamp(1, 28));
      final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
      final today = DateTime(now.year, now.month, now.day);
      final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
      final canRecordEarly = reminderLeadDays > 0 &&
          !today.isBefore(reminderDate) &&
          today.isBefore(dueDate);
      final isDueOrLate = !today.isBefore(dueDate);

      if (canRecordEarly || isDueOrLate) {
        count++;
      }
    }

    for (final debt in budget.debts) {
      final recurring = BudgetRecurringPlanService.linkedRecurring(
        state.recurringTransactions,
        debt,
      );
      if (recurring == null || recurring.executionType != 'confirm') {
        continue;
      }
      final paidAmount = cycleTransactions
          .where((transaction) => transaction.notes?.contains(debt.name) == true)
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
      final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
      final remaining = BudgetRecurringPlanService.pendingDecisionAmount(
        debt: debt,
        recurring: recurring,
        cyclePaid: paidAmount,
      );

      if (remaining > 0 && prompt != null) {
        count++;
      }
    }

    return count;
  }
}
