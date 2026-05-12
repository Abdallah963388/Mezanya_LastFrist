import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../entities/transaction_entity.dart';

class AutoJarFundingResult {
  const AutoJarFundingResult({
    required this.linkedWallets,
    required this.transactions,
    required this.remainingAmount,
  });

  final List<LinkedWalletEntity> linkedWallets;
  final List<TransactionEntity> transactions;
  final double remainingAmount;
}

class AutoJarFundingService {
  const AutoJarFundingService._();

  static AutoJarFundingResult apply({
    required List<LinkedWalletEntity> linkedWallets,
    required List<TransactionEntity> transactions,
    required TransactionEntity transaction,
    required String sourceId,
    required double amount,
  }) {
    var nextLinkedWallets = linkedWallets;
    final nextTransactions = List<TransactionEntity>.from(transactions);
    var remaining = amount;

    for (final jar in nextLinkedWallets) {
      final jarPlan = jar.funding
          .where((funding) => funding.incomeSourceId == sourceId)
          .fold<double>(0, (sum, funding) => sum + funding.plannedAmount);
      if (jarPlan <= 0 || remaining <= 0) {
        continue;
      }

      final transferAmount = jarPlan <= remaining ? jarPlan : remaining;
      remaining -= transferAmount;

      nextLinkedWallets = nextLinkedWallets.map((wallet) {
        if (wallet.id != jar.id) {
          return wallet;
        }
        return wallet.copyWith(balance: wallet.balance + transferAmount);
      }).toList();

      nextTransactions.add(
        TransactionEntity(
          id: 'txn-auto-jar-${DateTime.now().microsecondsSinceEpoch}',
          amount: transferAmount,
          type: 'transfer',
          fromWalletId: transaction.walletId,
          toWalletId: jar.id,
          transferType: 'jar-funding',
          notes: 'تحويل تلقائي للحصالة: ${jar.name}',
          createdAt: transaction.createdAt,
          incomeSourceId: sourceId,
        ),
      );
    }

    return AutoJarFundingResult(
      linkedWallets: nextLinkedWallets,
      transactions: nextTransactions,
      remainingAmount: remaining,
    );
  }
}
