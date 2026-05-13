import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/local/wallet_local_data_source.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._localDataSource);

  final WalletLocalDataSource _localDataSource;

  @override
  Future<List<WalletEntity>> loadWallets() {
    return _localDataSource.loadWallets();
  }

  @override
  Future<void> saveWallets(List<WalletEntity> wallets) {
    return _localDataSource.saveWallets(wallets);
  }
}
