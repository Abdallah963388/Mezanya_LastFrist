import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/transaction_entity.dart';

class FinancialSnapshot {
  const FinancialSnapshot({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.walletCount,
    required this.transactionCount,
  });

  final double totalBalance;
  final double totalIncome;
  final double totalExpenses;
  final int walletCount;
  final int transactionCount;
}

class ProcessFinancialSnapshotUseCase {
  const ProcessFinancialSnapshotUseCase();

  Result<FinancialSnapshot> execute({
    required List<WalletEntity> wallets,
    required List<TransactionEntity> transactions,
  }) {
    if (wallets.isEmpty) {
      return Result.failure(
        WalletFailure('Cannot generate financial snapshot without wallets'),
      );
    }

    final totalBalance = wallets.fold<double>(
      0,
      (sum, wallet) => sum + wallet.balance,
    );

    double totalIncome = 0;
    double totalExpenses = 0;

    for (final transaction in transactions) {
      final type = transaction.type.toLowerCase();

      if (type.contains('income')) {
        totalIncome += transaction.amount;
      } else if (type.contains('expense')) {
        totalExpenses += transaction.amount;
      }
    }

    return Result.success(
      FinancialSnapshot(
        totalBalance: totalBalance,
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        walletCount: wallets.length,
        transactionCount: transactions.length,
      ),
    );
  }
}
