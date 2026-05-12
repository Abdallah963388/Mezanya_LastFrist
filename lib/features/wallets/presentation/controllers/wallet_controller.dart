import 'package:flutter/foundation.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';
import '../../domain/entities/wallet_entity.dart';

class WalletController extends ChangeNotifier {
  WalletController(this._repository);

  final AppRepository _repository;

  AppStateEntity _state = AppStateEntity.initial();

  AppStateEntity get state => _state;

  Future<void> initialize() async {
    _state = await _repository.loadState();
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

    _state = await _repository.addWallet(wallet);

    notifyListeners();
  }

  Future<void> updateWallet({
    required String id,
    String? name,
    double? balance,
    String? icon,
    String? iconColor,
  }) async {
    final wallets = _state.wallets
        .map((wallet) => wallet.id == id
            ? wallet.copyWith(
                name: name,
                balance: balance,
                icon: icon,
                iconColor: iconColor,
              )
            : wallet)
        .toList();

    _state = _state.copyWith(wallets: wallets);

    await _repository.saveState(_state);

    notifyListeners();
  }

  Future<void> deleteWallet(String id) async {
    _state = _state.copyWith(
      wallets: _state.wallets
          .where((wallet) => wallet.id != id)
          .toList(),
    );

    await _repository.saveState(_state);

    notifyListeners();
  }
}
