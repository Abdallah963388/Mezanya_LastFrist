import '../../../wallets/domain/entities/wallet_entity.dart';

class WalletMutationResult {
  const WalletMutationResult({
    required this.updatedWallet,
    required this.previousBalance,
    required this.newBalance,
  });

  final WalletEntity updatedWallet;
  final double previousBalance;
  final double newBalance;
}

class WalletMutationService {
  const WalletMutationService._();

  static WalletMutationResult applyExpense({
    required WalletEntity wallet,
    required double amount,
  }) {
    final previousBalance = wallet.balance;
    final newBalance = previousBalance - amount;

    return WalletMutationResult(
      updatedWallet: wallet.copyWith(balance: newBalance),
      previousBalance: previousBalance,
      newBalance: newBalance,
    );
  }

  static WalletMutationResult applyIncome({
    required WalletEntity wallet,
    required double amount,
  }) {
    final previousBalance = wallet.balance;
    final newBalance = previousBalance + amount;

    return WalletMutationResult(
      updatedWallet: wallet.copyWith(balance: newBalance),
      previousBalance: previousBalance,
      newBalance: newBalance,
    );
  }

  static ({WalletEntity fromWallet, WalletEntity toWallet}) applyTransfer({
    required WalletEntity fromWallet,
    required WalletEntity toWallet,
    required double amount,
  }) {
    return (
      fromWallet: fromWallet.copyWith(
        balance: fromWallet.balance - amount,
      ),
      toWallet: toWallet.copyWith(
        balance: toWallet.balance + amount,
      ),
    );
  }
}
