import '../entities/budget_money_totals_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class CalculateBudgetMoneyTotalsUseCase {
  const CalculateBudgetMoneyTotalsUseCase();

  BudgetMoneyTotalsEntity call(List<TransactionEntity> cycleTransactions) {
    final incomeTx =
        cycleTransactions.where((t) => t.type == 'income').toList();
    final expenseTx =
        cycleTransactions.where((t) => t.type == 'expense').toList();
    final totalIncomeActual =
        incomeTx.fold<double>(0, (s, t) => s + t.amount);
    final totalExpenseActual =
        expenseTx.fold<double>(0, (s, t) => s + t.amount);
    final remainingIncome = totalIncomeActual - totalExpenseActual;
    return BudgetMoneyTotalsEntity(
      totalIncomeActual: totalIncomeActual,
      totalExpenseActual: totalExpenseActual,
      remainingIncome: remainingIncome,
    );
  }
}
