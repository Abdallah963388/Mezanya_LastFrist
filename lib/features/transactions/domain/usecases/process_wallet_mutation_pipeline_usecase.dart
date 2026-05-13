import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../services/wallet_mutation_service.dart';
import 'apply_wallet_mutation_usecase.dart';

class ProcessWalletMutationPipelineResult {
  const ProcessWalletMutationPipelineResult({
    required this.mutationResult,
  });

  final WalletMutationResult mutationResult;
}

class ProcessWalletMutationPipelineUseCase {
  const ProcessWalletMutationPipelineUseCase({
    required this.applyWalletMutationUseCase,
  });

  final ApplyWalletMutationUseCase applyWalletMutationUseCase;

  Result<ProcessWalletMutationPipelineResult> processExpense({
    required WalletEntity wallet,
    required double amount,
  }) {
    final result = applyWalletMutationUseCase.applyExpense(
      wallet: wallet,
      amount: amount,
    );

    if (result.isFailure) {
      return Result.failure(
        result.failure ?? const WalletFailure('Expense wallet mutation failed'),
      );
    }

    return Result.success(
      ProcessWalletMutationPipelineResult(
        mutationResult: result.data!,
      ),
    );
  }

  Result<ProcessWalletMutationPipelineResult> processIncome({
    required WalletEntity wallet,
    required double amount,
  }) {
    final result = applyWalletMutationUseCase.applyIncome(
      wallet: wallet,
      amount: amount,
    );

    if (result.isFailure) {
      return Result.failure(
        result.failure ?? const WalletFailure('Income wallet mutation failed'),
      );
    }

    return Result.success(
      ProcessWalletMutationPipelineResult(
        mutationResult: result.data!,
      ),
    );
  }
}
