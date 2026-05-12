import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';

class WalletBalanceGuardResult {
  const WalletBalanceGuardResult({
    required this.effectiveBalance,
    required this.reservedAmount,
    required this.availableAmount,
    required this.usesReservedFunds,
    required this.goesNegative,
  });

  final double effectiveBalance;
  final double reservedAmount;
  final double availableAmount;
  final bool usesReservedFunds;
  final bool goesNegative;

  bool get requiresConfirmation => usesReservedFunds || goesNegative;
}

class WalletBalanceGuardService {
  const WalletBalanceGuardService._();

  static WalletBalanceGuardResult analyzeExpenseImpact({
    required WalletEntity wallet,
    required BudgetSetupEntity budget,
    required double amount,
    double originalTransactionAmount = 0,
    bool originalTransactionWasExpense = false,
    bool originalTransactionWasIncome = false,
  }) {
    var effectiveBalance = wallet.balance;

    if (originalTransactionWasExpense) {
      effectiveBalance += originalTransactionAmount;
    } else if (originalTransactionWasIncome) {
      effectiveBalance -= originalTransactionAmount;
    }

    final reservedAmount = _reservedAmount(
      walletId: wallet.id,
      budget: budget,
    );

    final availableAmount = effectiveBalance - reservedAmount;
    final usesReservedFunds = amount > availableAmount;
    final goesNegative = (effectiveBalance - amount) < 0;

    return WalletBalanceGuardResult(
      effectiveBalance: effectiveBalance,
      reservedAmount: reservedAmount,
      availableAmount: availableAmount,
      usesReservedFunds: usesReservedFunds,
      goesNegative: goesNegative,
    );
  }

  static double _reservedAmount({
    required String walletId,
    required BudgetSetupEntity budget,
  }) {
    var reserved = 0.0;

    for (final jar in budget.linkedWallets) {
      final sources = jar.walletSources.isNotEmpty
          ? jar.walletSources
          : jar.walletBalances.entries
              .map(
                (entry) => JarWalletSource(
                  walletId: entry.key,
                  amount: entry.value,
                ),
              )
              .toList();

      for (final source in sources) {
        if (source.walletId == walletId) {
          reserved += source.amount;
        }
      }
    }

    return reserved < 0 ? 0 : reserved;
  }
}
