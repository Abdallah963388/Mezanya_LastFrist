import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';

class SynchronizeWalletsResult {
  const SynchronizeWalletsResult({
    required this.wallets,
    required this.totalBalance,
  });

  final List<WalletEntity> wallets;
  final double totalBalance;
}

class SynchronizeWalletsUseCase {
  const SynchronizeWalletsUseCase();

  Result<SynchronizeWalletsResult> execute({
    required List<WalletEntity> wallets,
  }) {
    if (wallets.isEmpty) {
      return Result.failure(
        WalletFailure('Cannot synchronize empty wallet collection'),
      );
    }

    final totalBalance = wallets.fold<double>(
      0,
      (previousValue, wallet) => previousValue + wallet.balance,
    );

    return Result.success(
      SynchronizeWalletsResult(
        wallets: wallets,
        totalBalance: totalBalance,
      ),
    );
  }
}
