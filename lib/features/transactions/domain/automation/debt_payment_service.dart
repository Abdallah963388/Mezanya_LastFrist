import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/transaction_entity.dart';

class DebtPaymentResult {
  const DebtPaymentResult({
    required this.wallets,
    required this.transactions,
    required this.remainingAmount,
  });

  final List<WalletEntity> wallets;
  final List<TransactionEntity> transactions;
  final double remainingAmount;
}

class DebtPaymentService {
  const DebtPaymentService._();

  static DebtPaymentResult apply({
    required List<WalletEntity> wallets,
    required List<TransactionEntity> transactions,
    required List<DebtEntity> debts,
    required TransactionEntity transaction,
    required String sourceId,
    required double amount,
  }) {
    var nextWallets = wallets;
    final nextTransactions = List<TransactionEntity>.from(transactions);
    var remaining = amount;

    for (final debt in debts.where((debt) => debt.fundingSource == sourceId)) {
      if (remaining <= 0) {
        break;
      }

      final debtAmount = debt.amount <= remaining ? debt.amount : remaining;
      remaining -= debtAmount;

      nextWallets = nextWallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }
        return wallet.copyWith(balance: wallet.balance - debtAmount);
      }).toList();

      nextTransactions.add(
        TransactionEntity(
          id: 'txn-auto-debt-${DateTime.now().microsecondsSinceEpoch}',
          amount: debtAmount,
          type: 'expense',
          walletId: transaction.walletId,
          budgetScope: 'outside-budget',
          notes: 'سداد تلقائي للدين: ${debt.name}',
          createdAt: transaction.createdAt,
          incomeSourceId: sourceId,
        ),
      );
    }

    return DebtPaymentResult(
      wallets: nextWallets,
      transactions: nextTransactions,
      remainingAmount: remaining,
    );
  }
}
