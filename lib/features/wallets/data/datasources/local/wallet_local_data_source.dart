import '../../../domain/entities/wallet_entity.dart';

abstract class WalletLocalDataSource {
  Future<List<WalletEntity>> loadWallets();

  Future<void> saveWallets(List<WalletEntity> wallets);
}
