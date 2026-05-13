import '../../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../../wallets/domain/entities/wallet_entity.dart';
import '../app_cubit.dart';

extension AppCubitWalletsExtension on AppCubit {
  Future<void> addWallet({
    required String name,
    required double openingBalance,
    String? icon,
    String? iconColor,
  }) async {
    final wallet = WalletEntity(
      id: generateId('wallet'),
      name: name,
      balance: openingBalance,
      icon: icon,
      iconColor: iconColor,
    );
    await applyAndLog(
      action: 'add',
      entityType: 'wallet',
      entityId: wallet.id,
      details: '??? ????? ????? ?????: $name',
      apply: () => repository.addWallet(wallet),
    );
  }

  Future<void> updateWallet({
    required String id,
    String? name,
    double? balance,
    String? icon,
    String? iconColor,
  }) async {
    final wallets = state.wallets
        .map((wallet) => wallet.id == id
            ? wallet.copyWith(
                name: name,
                balance: balance,
                icon: icon,
                iconColor: iconColor,
              )
            : wallet)
        .toList();
    final next = state.copyWith(wallets: wallets);
    await applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: id,
      details: '?? ????? ?????? ???????',
      apply: () async => next,
    );
  }

  Future<void> reorderWallets(List<WalletEntity> ordered) async {
    final next = state.copyWith(wallets: ordered);
    await applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: 'wallets-order',
      details: '?? ????? ????? ???????',
      apply: () async => next,
    );
  }

  Future<void> toggleWalletHighlight(String walletId) async {
    final wallets = state.wallets.map((wallet) {
      if (wallet.id != walletId) return wallet;
      return wallet.copyWith(isHighlighted: !wallet.isHighlighted);
    }).toList();
    final next = state.copyWith(wallets: wallets);
    await applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: walletId,
      details: '????? ????? ???????',
      apply: () async => next,
    );
  }

  Future<void> deleteWallet(String id) async {
    final next = state.copyWith(
      wallets: state.wallets.where((wallet) => wallet.id != id).toList(),
    );
    await applyAndLog(
      action: 'delete',
      entityType: 'wallet',
      entityId: id,
      details: '?? ??? ?????',
      apply: () async => next,
    );
  }

  Future<void> applySavingsReserve({
    required String walletId,
    required double amount,
    required String action,
  }) async {
    if (amount <= 0) return;
    final walletList = List<WalletEntity>.from(state.wallets);
    final index = walletList.indexWhere((wallet) => wallet.id == walletId);
    if (index == -1) return;
    final wallet = walletList[index];

    double nextReserved = wallet.reservedForSavings;
    if (action == 'allocate') {
      nextReserved += amount;
    } else {
      nextReserved -= amount;
    }
    if (nextReserved < 0) nextReserved = 0;

    walletList[index] = wallet.copyWith(reservedForSavings: nextReserved);
    final totalReserved =
        walletList.fold<double>(0, (sum, item) => sum + item.reservedForSavings);
    final linked = state.budgetSetup.linkedWallets
        .map(
          (jar) => jar.id == 'linked-savings-default'
              ? LinkedWalletEntity(
                  id: jar.id,
                  name: jar.name,
                  balance: totalReserved,
                  monthlyAmount: jar.monthlyAmount,
                  executionDay: jar.executionDay,
                  fundingSource: jar.fundingSource,
                  funding: jar.funding,
                  icon: jar.icon,
                  iconColor: jar.iconColor,
                  automationType: jar.automationType,
                  categories: jar.categories,
                )
              : jar,
        )
        .toList();

    final next = state.copyWith(
      wallets: walletList,
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: linked),
    );
    final label = action == 'allocate'
        ? '?? ????? ${amount.toStringAsFixed(2)} ??????? ?? ${wallet.name}'
        : action == 'cancel'
            ? '?? ????? ????? ${amount.toStringAsFixed(2)} ?? ${wallet.name}'
            : '?? ??? ${amount.toStringAsFixed(2)} ?? ??????? ?? ${wallet.name}';
    await applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: wallet.id,
      details: label,
      apply: () async => next,
    );
  }
}

