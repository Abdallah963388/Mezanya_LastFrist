import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';
import 'package:mezanya_app/features/wallets/domain/repositories/wallet_repository.dart';
import 'package:mezanya_app/features/wallets/presentation/controllers/wallet_controller.dart';

class _MemoryWalletRepository implements WalletRepository {
  _MemoryWalletRepository([List<WalletEntity>? wallets])
      : _wallets = wallets ?? <WalletEntity>[];

  List<WalletEntity> _wallets;

  @override
  Future<List<WalletEntity>> loadWallets() async => _wallets;

  @override
  Future<void> saveWallets(List<WalletEntity> wallets) async {
    _wallets = wallets;
  }
}

void main() {
  test('add wallet stores a new wallet in isolated wallet state', () async {
    final controller = WalletController(_MemoryWalletRepository());

    await controller.initialize();
    await controller.addWallet(name: 'Cash', openingBalance: 100);

    expect(controller.wallets, hasLength(1));
    expect(controller.wallets.single.name, 'Cash');
    expect(controller.wallets.single.balance, 100);
  });

  test('update and delete wallet mutate only wallet list', () async {
    final controller = WalletController(
      _MemoryWalletRepository(
        const [WalletEntity(id: 'wallet-1', name: 'Cash', balance: 100)],
      ),
    );

    await controller.initialize();
    await controller.updateWallet(id: 'wallet-1', name: 'Bank', balance: 250);
    await controller.deleteWallet('wallet-1');

    expect(controller.wallets, isEmpty);
  });
}
