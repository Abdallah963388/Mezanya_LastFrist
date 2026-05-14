import '../entities/budget_cycle_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class LoadBudgetTransactionsForCycleUseCase {
  const LoadBudgetTransactionsForCycleUseCase();

  List<TransactionEntity> call({
    required List<TransactionEntity> allTransactions,
    required BudgetCycleEntity cycle,
  }) {
    final end = cycle.cycleEnd;
    final start = cycle.cycleStart;
    final filtered = allTransactions
        .where(
          (t) =>
              !t.createdAt.isBefore(start) &&
              !t.createdAt.isAfter(end) &&
              !_isJarReserveTx(t),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  bool _isJarReserveTx(TransactionEntity t) {
    return t.transferType == 'jar-allocation' ||
        t.transferType == 'jar-allocation-cancel' ||
        t.transferType == 'jar-allocation-spend' ||
        t.transferType == 'jar-funding' ||
        t.transferType == 'allocation-to-jar';
  }
}
