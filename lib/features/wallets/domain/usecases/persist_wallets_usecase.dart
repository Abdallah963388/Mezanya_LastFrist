import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class PersistWalletsUseCase {
  PersistWalletsUseCase(this._repository);

  final WalletRepository _repository;

  Future<void> call(List<WalletEntity> wallets) =>
      _repository.saveWallets(wallets);
}
