import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/automation/auto_jar_funding_service.dart';
import '../../../transactions/domain/automation/debt_payment_service.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/app_state_entity.dart';

class TransactionMutationResult {
  const TransactionMutationResult({
    required this.wallets,
    required this.transactions,
    required this.budgetSetup,
  });

  final List<WalletEntity> wallets;
  final List<TransactionEntity> transactions;
  final BudgetSetupEntity budgetSetup;
}

class TransactionMutationService {
  const TransactionMutationService._();

  static AppStateEntity addTransaction({
    required AppStateEntity current,
    required TransactionEntity transaction,
  }) {
    final result = applyTransaction(
      wallets: current.wallets,
      transactions: current.transactions,
      budgetSetup: current.budgetSetup,
      transaction: transaction,
    );

    return current.copyWith(
      wallets: result.wallets,
      budgetSetup: result.budgetSetup,
      transactions: result.transactions,
    );
  }

  static TransactionMutationResult reverseTransaction({
  required List<WalletEntity> wallets,
  required List<TransactionEntity> transactions,
  required BudgetSetupEntity budgetSetup,
  required TransactionEntity transaction,
}) {
  final remainingTransactions = transactions
      .where((item) => item.id != transaction.id)
      .toList();

  var nextWallets = List<WalletEntity>.from(wallets);

  if (transaction.type == 'transfer' &&
      transaction.fromWalletId != null &&
      transaction.toWalletId != null) {
    nextWallets = nextWallets.map((wallet) {
      if (wallet.id == transaction.fromWalletId) {
        return wallet.copyWith(
          balance: wallet.balance + transaction.amount,
        );
      }

      if (wallet.id == transaction.toWalletId) {
        return wallet.copyWith(
          balance: wallet.balance - transaction.amount,
        );
      }

      return wallet;
    }).toList();
  } else {
    nextWallets = nextWallets.map((wallet) {
      if (wallet.id != transaction.walletId) {
        return wallet;
      }

      final nextBalance = transaction.type == 'income'
          ? wallet.balance - transaction.amount
          : wallet.balance + transaction.amount;

      return wallet.copyWith(balance: nextBalance);
    }).toList();
  }

  return TransactionMutationResult(
    wallets: nextWallets,
    transactions: remainingTransactions,
    budgetSetup: budgetSetup,
  );
}


  static TransactionMutationResult applyTransaction({
    required List<WalletEntity> wallets,
    required List<TransactionEntity> transactions,
    required BudgetSetupEntity budgetSetup,
    required TransactionEntity transaction,
  }) {
    var nextWallets = List<WalletEntity>.from(wallets);
    var linkedWallets =
        List<LinkedWalletEntity>.from(budgetSetup.linkedWallets);
    var nextTransactions = <TransactionEntity>[
      ...transactions,
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
      nextWallets = nextWallets.map((wallet) {
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
      nextWallets = nextWallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }
        return wallet.copyWith(balance: wallet.balance + transaction.amount);
      }).toList();

      final sourceId = transaction.incomeSourceId!;
      final jarResult = AutoJarFundingService.apply(
        linkedWallets: linkedWallets,
        transactions: nextTransactions,
        transaction: transaction,
        sourceId: sourceId,
        amount: transaction.amount,
      );

      linkedWallets = jarResult.linkedWallets;
      nextTransactions = jarResult.transactions;

      // Keep the legacy behavior: debt automation currently receives no
      // remaining income after jar funding in the existing flow.
      final debtResult = DebtPaymentService.apply(
        wallets: nextWallets,
        transactions: nextTransactions,
        debts: budgetSetup.debts,
        transaction: transaction,
        sourceId: sourceId,
        amount: 0,
      );

      nextWallets = debtResult.wallets;
      nextTransactions = debtResult.transactions;
    } else {
      nextWallets = nextWallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }
        final nextBalance = transaction.type == 'income'
            ? wallet.balance + transaction.amount
            : wallet.balance - transaction.amount;
        return wallet.copyWith(balance: nextBalance);
      }).toList();
    }

    return TransactionMutationResult(
      wallets: nextWallets,
      budgetSetup: budgetSetup.copyWith(linkedWallets: linkedWallets),
      transactions: nextTransactions,
    );
  }
}
