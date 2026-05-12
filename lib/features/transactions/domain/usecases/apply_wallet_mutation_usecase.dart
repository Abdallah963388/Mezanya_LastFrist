import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../services/wallet_mutation_service.dart';

class ApplyWalletMutationUseCase {
  const ApplyWalletMutationUseCase();

  Result<WalletMutationResult> applyExpense({
    required WalletEntity wallet,
    required double amount,
  }) {
    if (amount <= 0) {
      return Result.failure(
        WalletFailure('Expense amount must be greater than zero'),
      );
    }

    final mutation = WalletMutationService.applyExpense(
      wallet: wallet,
      amount: amount,
    );

    return Result.success(mutation);
  }

  Result<WalletMutationResult> applyIncome({
    required WalletEntity wallet,
    required double amount,
  }) {
    if (amount <= 0) {
      return Result.failure(
        WalletFailure('Income amount must be greater than zero'),
      );
    }

    final mutation = WalletMutationService.applyIncome(
      wallet: wallet,
      amount: amount,
    );

    return Result.success(mutation);
  }
}
