import '../../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../../wallets/domain/entities/wallet_entity.dart';
import 'app_cubit_budget_extension.dart';
import '../app_cubit.dart';

extension AppCubitSpacesExtension on AppCubit {
  Future<void> reorderJars(List<LinkedWalletEntity> ordered) async {
    await updateBudgetSetup(state.budgetSetup.copyWith(linkedWallets: ordered));
  }

  Future<void> toggleJarHighlight(String jarId) async {
    final jars = state.budgetSetup.linkedWallets.map((jar) {
      if (jar.id != jarId) return jar;
      return jar.copyWith(isHighlighted: !jar.isHighlighted);
    }).toList();
    await updateBudgetSetup(state.budgetSetup.copyWith(linkedWallets: jars));
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: [...state.budgetSetup.linkedWallets, linkedWallet],
      ),
    );
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .map((item) => item.id == linkedWallet.id ? linkedWallet : item)
            .toList(),
      ),
    );
  }

  Future<void> confirmJarDistribution(String jarId) async {
    final jars = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
    var wallets = List<WalletEntity>.from(state.wallets);
    final index = jars.indexWhere((jar) => jar.id == jarId);
    if (index == -1) return;
    final jar = jars[index];
    final amount = jar.pendingDistribution;
    if (amount <= 0) return;

    final nextBalances = Map<String, double>.from(jar.walletBalances);
    if (jar.pendingDistributionWalletId.isNotEmpty) {
      nextBalances[jar.pendingDistributionWalletId] =
          (nextBalances[jar.pendingDistributionWalletId] ?? 0) + amount;
    }
    jars[index] = jar.copyWith(
      balance: jar.balance + amount,
      walletBalances: nextBalances,
      pendingDistribution: 0,
      pendingDistributionWalletId: '',
      pendingDistributionSourceId: '',
    );

    if (jar.pendingDistributionWalletId.isNotEmpty) {
      final walletIndex =
          wallets.indexWhere((wallet) => wallet.id == jar.pendingDistributionWalletId);
      if (walletIndex != -1) {
        wallets[walletIndex] =
            wallets[walletIndex].copyWith(balance: wallets[walletIndex].balance - amount);
      }
    }

    final next = state.copyWith(
      wallets: wallets,
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: jars),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'jar',
      entityId: jarId,
      details: '?? ????? ????? ${amount.toStringAsFixed(2)} ?????? ${jar.name}',
      apply: () async => next,
    );
  }

  Future<void> postponeJarDistribution(String jarId) async {
    final jars = state.budgetSetup.linkedWallets
        .map((jar) => jar.id == jarId
            ? jar.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
              )
            : jar)
        .toList();
    final jar = state.budgetSetup.linkedWallets.firstWhere(
      (item) => item.id == jarId,
      orElse: () => state.budgetSetup.linkedWallets.first,
    );
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: jars),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'jar',
      entityId: jarId,
      details:
          '?? ????? ????? ${jar.pendingDistribution.toStringAsFixed(2)} ?????? ${jar.name}',
      apply: () async => next,
    );
  }

  Future<void> confirmAllocationDistribution(String allocationId) async {
    final allocations = List<AllocationEntity>.from(state.budgetSetup.allocations);
    var wallets = List<WalletEntity>.from(state.wallets);
    final index = allocations.indexWhere((allocation) => allocation.id == allocationId);
    if (index == -1) return;
    final allocation = allocations[index];
    final amount = allocation.pendingDistribution;
    if (amount <= 0) return;

    final nextBalances = Map<String, double>.from(allocation.walletBalances);
    if (allocation.pendingDistributionWalletId.isNotEmpty) {
      nextBalances[allocation.pendingDistributionWalletId] =
          (nextBalances[allocation.pendingDistributionWalletId] ?? 0) + amount;
    }
    allocations[index] = allocation.copyWith(
      balance: allocation.balance + amount,
      walletBalances: nextBalances,
      pendingDistribution: 0,
      pendingDistributionWalletId: '',
      pendingDistributionSourceId: '',
    );

    if (allocation.pendingDistributionWalletId.isNotEmpty) {
      final walletIndex = wallets.indexWhere(
        (wallet) => wallet.id == allocation.pendingDistributionWalletId,
      );
      if (walletIndex != -1) {
        wallets[walletIndex] =
            wallets[walletIndex].copyWith(balance: wallets[walletIndex].balance - amount);
      }
    }

    final next = state.copyWith(
      wallets: wallets,
      budgetSetup: state.budgetSetup.copyWith(allocations: allocations),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'allocation',
      entityId: allocationId,
      details:
          '?? ????? ????? ${amount.toStringAsFixed(2)} ?????? ${allocation.name}',
      apply: () async => next,
    );
  }

  Future<void> postponeAllocationDistribution(String allocationId) async {
    final allocation = state.budgetSetup.allocations.firstWhere(
      (item) => item.id == allocationId,
      orElse: () => state.budgetSetup.allocations.first,
    );
    final allocations = state.budgetSetup.allocations
        .map((item) => item.id == allocationId
            ? item.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
              )
            : item)
        .toList();
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(allocations: allocations),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'allocation',
      entityId: allocationId,
      details:
          '?? ????? ????? ${allocation.pendingDistribution.toStringAsFixed(2)} ?????? ${allocation.name}',
      apply: () async => next,
    );
  }

  Future<void> updateJarWalletSources({
    required String jarId,
    required List<JarWalletSource> sources,
  }) async {
    final linkedWallets = state.budgetSetup.linkedWallets
        .map((jar) => jar.id == jarId ? jar.copyWith(walletSources: sources) : jar)
        .toList();
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: linkedWallets),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'jar',
      entityId: jarId,
      details: '?? ????? ????? ???????',
      apply: () async => next,
    );
  }

  Future<void> transferBetweenJars({
    required String sourceJarId,
    required String targetJarId,
    required double amount,
    String? physicalWalletId,
  }) async {
    var linkedWallets = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);

    final sourceIndex = linkedWallets.indexWhere((jar) => jar.id == sourceJarId);
    final targetIndex = linkedWallets.indexWhere((jar) => jar.id == targetJarId);
    if (sourceIndex == -1 || targetIndex == -1) return;

    final sourceJar = linkedWallets[sourceIndex];
    final targetJar = linkedWallets[targetIndex];

    List<JarWalletSource> sourceSources = List.from(sourceJar.walletSources);
    if (physicalWalletId != null) {
      final existing = sourceSources.firstWhere(
        (source) => source.walletId == physicalWalletId,
        orElse: () => JarWalletSource(walletId: physicalWalletId, amount: 0),
      );
      final newAmount = (existing.amount - amount).clamp(0.0, double.infinity);
      sourceSources = [
        ...sourceSources.where((source) => source.walletId != physicalWalletId),
        if (newAmount > 0)
          JarWalletSource(walletId: physicalWalletId, amount: newAmount),
      ];
    }
    linkedWallets[sourceIndex] = sourceJar.copyWith(
      balance: sourceJar.balance - amount,
      walletSources: sourceSources,
    );

    List<JarWalletSource> targetSources = List.from(targetJar.walletSources);
    if (physicalWalletId != null) {
      final existing = targetSources.firstWhere(
        (source) => source.walletId == physicalWalletId,
        orElse: () => JarWalletSource(walletId: physicalWalletId, amount: 0),
      );
      final newAmount = existing.amount + amount;
      targetSources = [
        ...targetSources.where((source) => source.walletId != physicalWalletId),
        JarWalletSource(walletId: physicalWalletId, amount: newAmount),
      ];
    }
    linkedWallets[targetIndex] = targetJar.copyWith(
      balance: targetJar.balance + amount,
      walletSources: targetSources,
    );

    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: linkedWallets),
    );
    await applyAndLog(
      action: 'transfer',
      entityType: 'jar',
      entityId: sourceJarId,
      details:
          '????? ????? ${amount.toStringAsFixed(2)} ?? ${sourceJar.name} ??? ${targetJar.name}',
      apply: () async => next,
    );
  }

  Future<void> deleteLinkedWallet(String id) async {
    if (id == 'linked-savings-default') {
      return;
    }
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets:
            state.budgetSetup.linkedWallets.where((wallet) => wallet.id != id).toList(),
      ),
    );
  }

  Future<void> ensureDefaultSavingsJar() async {
    final defaultIndex = state.budgetSetup.linkedWallets
        .indexWhere((wallet) => wallet.id == 'linked-savings-default');
    if (defaultIndex != -1) {
      final current = state.budgetSetup.linkedWallets[defaultIndex];
      if (current.name != '???????') {
        final linkedWallets = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
        linkedWallets[defaultIndex] = LinkedWalletEntity(
          id: current.id,
          name: '???????',
          balance: current.balance,
          monthlyAmount: current.monthlyAmount,
          executionDay: current.executionDay,
          fundingSource: current.fundingSource,
          funding: current.funding,
          icon: current.icon,
          iconColor: current.iconColor,
          automationType: current.automationType,
          categories: current.categories,
        );
        final next = state.copyWith(
          budgetSetup: state.budgetSetup.copyWith(linkedWallets: linkedWallets),
        );
        await repository.saveState(next);
        emitState(next);
      }
      return;
    }

    final fallbackIncomeId = state.budgetSetup.incomeSources.isNotEmpty
        ? state.budgetSetup.incomeSources.first.id
        : '';
    final defaultJar = LinkedWalletEntity(
      id: 'linked-savings-default',
      name: '???????',
      balance: 0,
      monthlyAmount: 0,
      executionDay: 1,
      fundingSource: fallbackIncomeId,
      funding: fallbackIncomeId.isEmpty
          ? const []
          : [
              LinkedWalletEntityFunding(
                id: generateId('fund-linked'),
                incomeSourceId: fallbackIncomeId,
                plannedAmount: 0,
              ),
            ],
      icon: 'savings',
      iconColor: '#0f766e',
      automationType: 'confirm',
      categories: const [],
    );
    final nextSetup = state.budgetSetup.copyWith(
      linkedWallets: [...state.budgetSetup.linkedWallets, defaultJar],
    );
    await applyAndLog(
      action: 'add',
      entityType: 'linked-wallet',
      entityId: defaultJar.id,
      details: '?? ????? ????? ??????? ??????????',
      apply: () async => state.copyWith(budgetSetup: nextSetup),
    );
  }

  Future<void> syncSavingsJarWithReserved() async {
    final totalReserved =
        state.wallets.fold<double>(0, (sum, wallet) => sum + wallet.reservedForSavings);
    final index = state.budgetSetup.linkedWallets
        .indexWhere((wallet) => wallet.id == 'linked-savings-default');
    if (index == -1) return;
    final current = state.budgetSetup.linkedWallets[index];
    if ((current.balance - totalReserved).abs() < 0.0001) {
      return;
    }
    final linkedWallets = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
    linkedWallets[index] = LinkedWalletEntity(
      id: current.id,
      name: current.name,
      balance: totalReserved,
      monthlyAmount: current.monthlyAmount,
      executionDay: current.executionDay,
      fundingSource: current.fundingSource,
      funding: current.funding,
      icon: current.icon,
      iconColor: current.iconColor,
      automationType: current.automationType,
      categories: current.categories,
    );
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: linkedWallets),
    );
    await repository.saveState(next);
    emitState(next);
  }
}

