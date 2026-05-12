import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/app_state_entity.dart';

class TransactionMutationService {
  const TransactionMutationService._();

  static AppStateEntity addTransaction({
    required AppStateEntity current,
    required TransactionEntity transaction,
  }) {
    var wallets = List<WalletEntity>.from(current.wallets);
    var linkedWallets =
        List<LinkedWalletEntity>.from(current.budgetSetup.linkedWallets);
    final transactions = <TransactionEntity>[
      ...current.transactions,
      transaction,
    ];

    if (transaction.transferType == 'allocation-to-jar') {
      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id != transaction.toWalletId) {
          return wallet;
        }
        return wallet.copyWith(balance: wallet.balance + transaction.amount);
      }).toList();
    } else if (transaction.transferType == 'jar-to-allocation') {
      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }
        return wallet.copyWith(balance: wallet.balance - transaction.amount);
      }).toList();
    } else if (transaction.transferType == 'jar-allocation' ||
        transaction.transferType == 'jar-funding' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend') {
      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id != transaction.toWalletId &&
            wallet.id != transaction.walletId) {
          return wallet;
        }
        final delta = transaction.transferType == 'jar-allocation' ||
                transaction.transferType == 'jar-funding'
            ? transaction.amount
            : -transaction.amount;
        return wallet.copyWith(balance: wallet.balance + delta);
      }).toList();
    } else if (transaction.type == 'transfer' &&
        transaction.fromWalletId != null &&
        transaction.toWalletId != null) {
      wallets = wallets.map((wallet) {
        if (wallet.id == transaction.fromWalletId) {
          return wallet.copyWith(balance: wallet.balance - transaction.amount);
        }
        if (wallet.id == transaction.toWalletId) {
          return wallet.copyWith(balance: wallet.balance + transaction.amount);
        }
        return wallet;
      }).toList();

      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id == transaction.toWalletId) {
          return wallet.copyWith(balance: wallet.balance + transaction.amount);
        }
        return wallet;
      }).toList();
    } else if (transaction.type == 'income' &&
        transaction.incomeSourceId != null) {
      wallets = wallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }
        return wallet.copyWith(balance: wallet.balance + transaction.amount);
      }).toList();

      final sourceId = transaction.incomeSourceId!;
      var remaining = transaction.amount;

      for (final jar in linkedWallets) {
        final jarPlan = jar.funding
            .where((funding) => funding.incomeSourceId == sourceId)
            .fold<double>(0, (sum, funding) => sum + funding.plannedAmount);
        if (jarPlan <= 0 || remaining <= 0) {
          continue;
        }
        final transferAmount = jarPlan <= remaining ? jarPlan : remaining;
        remaining -= transferAmount;

        linkedWallets = linkedWallets.map((wallet) {
          if (wallet.id != jar.id) {
            return wallet;
          }
          return wallet.copyWith(balance: wallet.balance + transferAmount);
        }).toList();

        transactions.add(
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

      remaining = 0;

      for (final debt in current.budgetSetup.debts
          .where((debt) => debt.fundingSource == sourceId)) {
        if (remaining <= 0) {
          break;
        }
        final debtAmount = debt.amount <= remaining ? debt.amount : remaining;
        remaining -= debtAmount;

        wallets = wallets.map((wallet) {
          if (wallet.id != transaction.walletId) {
            return wallet;
          }
          return wallet.copyWith(balance: wallet.balance - debtAmount);
        }).toList();

        transactions.add(
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
    } else {
      wallets = wallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }
        final nextBalance = transaction.type == 'income'
            ? wallet.balance + transaction.amount
            : wallet.balance - transaction.amount;
        return wallet.copyWith(balance: nextBalance);
      }).toList();
    }

    return current.copyWith(
      wallets: wallets,
      budgetSetup: current.budgetSetup.copyWith(linkedWallets: linkedWallets),
      transactions: transactions,
    );
  }
}
