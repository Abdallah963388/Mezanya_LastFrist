import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/app_state_entity.dart';

class AppStateMutationService {
  const AppStateMutationService._();

  static AppStateEntity addWallet({
    required AppStateEntity current,
    required WalletEntity wallet,
  }) {
    return current.copyWith(
      wallets: <WalletEntity>[
        ...current.wallets,
        wallet,
      ],
    );
  }

  static AppStateEntity updateBudgetSetup({
    required AppStateEntity current,
    required BudgetSetupEntity budgetSetup,
  }) {
    return current.copyWith(
      budgetSetup: budgetSetup,
    );
  }

  static AppStateEntity addTransaction({
    required AppStateEntity current,
    required TransactionEntity transaction,
  }) {
    var wallets = List<WalletEntity>.from(current.wallets);

    final transactions = <TransactionEntity>[
      ...current.transactions,
      transaction,
    ];

    if (transaction.type == 'income') {
      wallets = wallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }

        return wallet.copyWith(
          balance: wallet.balance + transaction.amount,
        );
      }).toList();
    }

    if (transaction.type == 'expense') {
      wallets = wallets.map((wallet) {
        if (wallet.id != transaction.walletId) {
          return wallet;
        }

        return wallet.copyWith(
          balance: wallet.balance - transaction.amount,
        );
      }).toList();
    }

    if (transaction.type == 'transfer') {
      wallets = wallets.map((wallet) {
        if (wallet.id == transaction.fromWalletId) {
          return wallet.copyWith(
            balance: wallet.balance - transaction.amount,
          );
        }

        if (wallet.id == transaction.toWalletId) {
          return wallet.copyWith(
            balance: wallet.balance + transaction.amount,
          );
        }

        return wallet;
      }).toList();
    }

    return current.copyWith(
      wallets: wallets,
      transactions: transactions,
    );
  }
}
