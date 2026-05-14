import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class LoadWalletsUseCase {
  LoadWalletsUseCase(this._repository);

  final WalletRepository _repository;

  Future<List<WalletEntity>> call() => _repository.loadWallets();
}
