import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_state/domain/services/wallet_mutation_service.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/usecases/load_wallets_usecase.dart';
import '../../domain/usecases/persist_wallets_usecase.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  WalletCubit(
    this._loadWalletsUseCase,
    this._persistWalletsUseCase,
  ) : super(const WalletState());

  final LoadWalletsUseCase _loadWalletsUseCase;
  final PersistWalletsUseCase _persistWalletsUseCase;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final wallets = await _loadWalletsUseCase();
    emit(state.copyWith(wallets: wallets, isLoading: false));
  }

  Future<void> refresh() async {
    final wallets = await _loadWalletsUseCase();
    emit(state.copyWith(wallets: wallets));
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

    final wallets = WalletMutationService.appendWallet(
      wallets: state.wallets,
      wallet: wallet,
    );

    await _persistWalletsUseCase(wallets);
    emit(state.copyWith(wallets: wallets));
  }

  Future<void> updateWallet({
    required String id,
    String? name,
    double? balance,
    String? icon,
    String? iconColor,
  }) async {
    final wallet = state.wallets.firstWhere((item) => item.id == id).copyWith(
          name: name,
          balance: balance,
          icon: icon,
          iconColor: iconColor,
        );

    final wallets = WalletMutationService.updateWallet(
      wallets: state.wallets,
      wallet: wallet,
    );

    await _persistWalletsUseCase(wallets);
    emit(state.copyWith(wallets: wallets));
  }

  Future<void> deleteWallet(String id) async {
    final wallets = WalletMutationService.deleteWallet(
      wallets: state.wallets,
      id: id,
    );

    await _persistWalletsUseCase(wallets);
    emit(state.copyWith(wallets: wallets));
  }

  Future<void> reorderWallets(List<WalletEntity> wallets) async {
    await _persistWalletsUseCase(wallets);
    emit(state.copyWith(wallets: wallets));
  }
}
