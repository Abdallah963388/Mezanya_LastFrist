import 'package:flutter/foundation.dart';

import '../../../app_state/domain/services/wallet_mutation_service.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/usecases/load_wallets_usecase.dart';
import '../../domain/usecases/persist_wallets_usecase.dart';

class WalletController extends ChangeNotifier {
  WalletController(
    WalletRepository repository, {
    LoadWalletsUseCase? loadWalletsUseCase,
    PersistWalletsUseCase? persistWalletsUseCase,
  })  : _loadWalletsUseCase =
            loadWalletsUseCase ?? LoadWalletsUseCase(repository),
        _persistWalletsUseCase =
            persistWalletsUseCase ?? PersistWalletsUseCase(repository);

  final LoadWalletsUseCase _loadWalletsUseCase;
  final PersistWalletsUseCase _persistWalletsUseCase;

  List<WalletEntity> _wallets = [];

  List<WalletEntity> get wallets => _wallets;

  int get walletCount => _wallets.length;

  bool get hasWallets => _wallets.isNotEmpty;

  double get totalBalance =>
      _wallets.fold(0, (sum, wallet) => sum + wallet.balance);

  List<WalletEntity> get positiveBalanceWallets =>
      _wallets.where((wallet) => wallet.balance > 0).toList();

  WalletEntity? walletById(String id) {
    try {
      return _wallets.firstWhere((wallet) => wallet.id == id);
    } catch (_) {
      return null;
    }
  }

  bool containsWallet(String id) {
    return _wallets.any((wallet) => wallet.id == id);
  }

  Future<void> initialize() async {
    _wallets = await _loadWalletsUseCase();
    notifyListeners();
  }

  Future<void> refresh() async {
    _wallets = await _loadWalletsUseCase();
    notifyListeners();
  }

  Future<void> addWallet({
    required String name,
    required double openingBalance,
    String? icon,
    String? iconColor,
  }) async {
    final wallet = WalletEntity(
      id: 'wallet-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      balance: openingBalance,
      icon: icon,
      iconColor: iconColor,
    );

    _wallets = WalletMutationService.appendWallet(
      wallets: _wallets,
      wallet: wallet,
    );

    await _persistWalletsUseCase(_wallets);
    notifyListeners();
  }

  Future<void> updateWallet({
    required String id,
    String? name,
    double? balance,
    String? icon,
    String? iconColor,
  }) async {
    final wallet = _wallets.firstWhere((item) => item.id == id).copyWith(
          name: name,
          balance: balance,
          icon: icon,
          iconColor: iconColor,
        );

    _wallets = WalletMutationService.updateWallet(
      wallets: _wallets,
      wallet: wallet,
    );

    await _persistWalletsUseCase(_wallets);
    notifyListeners();
  }

  Future<void> deleteWallet(String id) async {
    _wallets = WalletMutationService.deleteWallet(
      wallets: _wallets,
      id: id,
    );

    await _persistWalletsUseCase(_wallets);
    notifyListeners();
  }

  Future<void> reorderWallets(List<WalletEntity> wallets) async {
    _wallets = wallets;
    await _persistWalletsUseCase(_wallets);
    notifyListeners();
  }
}
