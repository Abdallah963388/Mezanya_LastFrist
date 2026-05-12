import '../entities/wallet_entity.dart';

abstract class WalletRepository {
  Future<List<WalletEntity>> loadWallets();

  Future<void> saveWallets(
    List<WalletEntity> wallets,
  );
}
