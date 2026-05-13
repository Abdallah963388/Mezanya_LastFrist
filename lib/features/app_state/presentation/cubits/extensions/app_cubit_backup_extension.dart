import 'dart:convert';

import '../../../domain/entities/app_state_entity.dart';
import '../../../../wallets/domain/entities/wallet_entity.dart';
import '../app_cubit.dart';

extension AppCubitBackupExtension on AppCubit {
  Future<void> updateAutoBackupTimestamp(DateTime at) async {
    final next = state.copyWith(lastAutoBackupAt: at.toIso8601String());
    await repository.saveState(next);
    emitState(next);
  }

  String exportStateJson() => jsonEncode(state.toMap());

  Future<void> importStateJson(String jsonString) async {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final next = AppStateEntity.fromMap(map);
    await applyAndLog(
      action: 'import',
      entityType: 'backup',
      entityId: 'import',
      details: '?? ??????? ???? ????????',
      apply: () async => next,
    );
  }

  Future<void> mergeStateJson(String remoteJson) async {
    final remoteMap = jsonDecode(remoteJson) as Map<String, dynamic>;
    final remote = AppStateEntity.fromMap(remoteMap);
    final local = state;

    final mergedWallets = {
      for (final wallet in [...local.wallets, ...remote.wallets]) wallet.id: wallet,
    }.values.toList();
    final mergedTransactions = {
      for (final transaction in [...local.transactions, ...remote.transactions])
        transaction.id: transaction,
    }.values.toList();
    final mergedRecurring = {
      for (final recurring in [
        ...local.recurringTransactions,
        ...remote.recurringTransactions,
      ])
        recurring.id: recurring,
    }.values.toList();
    final mergedGoals = {
      for (final goal in [...local.goals, ...remote.goals]) goal.id: goal,
    }.values.toList();
    final mergedCategories = {
      for (final category in [...local.categories, ...remote.categories])
        category.id: category,
    }.values.toList();

    final localBudgetNewer =
        local.lastAutoBackupAt.compareTo(remote.lastAutoBackupAt) >= 0;
    final budget = localBudgetNewer ? local.budgetSetup : remote.budgetSetup;

    final next = local.copyWith(
      wallets: mergedWallets,
      transactions: mergedTransactions,
      recurringTransactions: mergedRecurring,
      goals: mergedGoals,
      categories: mergedCategories,
      budgetSetup: budget,
    );

    await applyAndLog(
      action: 'import',
      entityType: 'backup',
      entityId: 'merge',
      details: '?? ??? ?????? ?????????? ?? ???????? ???????',
      apply: () async => next,
    );
  }

  Future<void> resetAllData() async {
    final next = AppStateEntity.initial();
    await applyAndLog(
      action: 'delete',
      entityType: 'all-data',
      entityId: 'reset',
      details: '?? ??? ?? ?????? ???????',
      apply: () async => next,
    );
  }

  Future<void> wipeDataSelective({
    bool transactions = false,
    bool logs = false,
    bool wallets = false,
    bool recurring = false,
    bool budget = false,
    bool categories = false,
    bool goals = false,
    bool notifications = false,
  }) async {
    var next = state;
    final details = <String>[];

    if (transactions) {
      next = next.copyWith(transactions: []);
      details.add('?????????');
    }
    if (logs) {
      next = next.copyWith(logs: []);
      details.add('??? ??????');
    }
    if (wallets) {
      next = next.copyWith(
        wallets: const [
          WalletEntity(id: 'wallet-cash-default', name: '?????', balance: 0),
          WalletEntity(id: 'wallet-bank-default', name: '?????', balance: 0),
        ],
      );
      details.add('??????? ????????');
    }
    if (recurring) {
      next = next.copyWith(recurringTransactions: []);
      details.add('????????? ????????');
    }
    if (budget) {
      next = next.copyWith(
        budgetSetup: next.budgetSetup.copyWith(
          incomeSources: [],
          debts: [],
          allocations: [],
          linkedWallets: next.budgetSetup.linkedWallets
              .where((wallet) => wallet.id == 'linked-savings-default')
              .toList(),
        ),
      );
      details.add('??? ?????????');
    }
    if (categories) {
      next = next.copyWith(categories: []);
      details.add('??????');
    }
    if (goals) {
      next = next.copyWith(goals: []);
      details.add('???????');
    }
    if (notifications) {
      next = next.copyWith(notifications: []);
      details.add('?????????');
    }

    if (details.isEmpty) return;

    await applyAndLog(
      action: 'delete',
      entityType: 'selective-wipe',
      entityId: 'reset',
      details: '?? ??? ?????? ?????: ${details.join('? ')}',
      apply: () async => next,
    );
  }
}

