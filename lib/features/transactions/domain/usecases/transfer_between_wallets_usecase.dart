import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../services/wallet_mutation_service.dart';

class TransferBetweenWalletsResult {
  const TransferBetweenWalletsResult({
    required this.fromWallet,
    required this.toWallet,
  });

  final WalletEntity fromWallet;
  final WalletEntity toWallet;
}

class TransferBetweenWalletsUseCase {
  const TransferBetweenWalletsUseCase();

  Result<TransferBetweenWalletsResult> execute({
    required WalletEntity fromWallet,
    required WalletEntity toWallet,
    required double amount,
  }) {
    if (amount <= 0) {
      return Result.failure(
        WalletFailure('Transfer amount must be greater than zero'),
      );
    }

    if (fromWallet.id == toWallet.id) {
      return Result.failure(
        WalletFailure('Cannot transfer to the same wallet'),
      );
    }

    if (fromWallet.balance < amount) {
      return Result.failure(
        WalletFailure('Insufficient wallet balance'),
      );
    }

    final transfer = WalletMutationService.applyTransfer(
      fromWallet: fromWallet,
      toWallet: toWallet,
      amount: amount,
    );

    return Result.success(
      TransferBetweenWalletsResult(
        fromWallet: transfer.fromWallet,
        toWallet: transfer.toWallet,
      ),
    );
  }
}
