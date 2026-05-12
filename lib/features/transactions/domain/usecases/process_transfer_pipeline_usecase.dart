import '../../../../core/results/result.dart';
import '../../../app_state/domain/failures/app_failure.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import 'transfer_between_wallets_usecase.dart';

class ProcessTransferPipelineParams {
  const ProcessTransferPipelineParams({
    required this.fromWallet,
    required this.toWallet,
    required this.amount,
  });

  final WalletEntity fromWallet;
  final WalletEntity toWallet;
  final double amount;
}

class ProcessTransferPipelineUseCase {
  const ProcessTransferPipelineUseCase({
    required this.transferBetweenWalletsUseCase,
  });

  final TransferBetweenWalletsUseCase transferBetweenWalletsUseCase;

  Result<TransferBetweenWalletsResult> execute(
    ProcessTransferPipelineParams params,
  ) {
    final transferResult = transferBetweenWalletsUseCase.execute(
      fromWallet: params.fromWallet,
      toWallet: params.toWallet,
      amount: params.amount,
    );

    if (transferResult.isFailure) {
      return Result.failure(
        transferResult.failure ??
            const TransactionFailure('Transfer pipeline failed'),
      );
    }

    return Result.success(transferResult.data!);
  }
}
