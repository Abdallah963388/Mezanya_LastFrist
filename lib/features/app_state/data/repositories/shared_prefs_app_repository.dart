import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';
import '../../domain/services/app_state_mutation_service.dart';

class SharedPrefsAppRepository implements AppRepository {
  SharedPrefsAppRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<AppStateEntity> loadState() async {
    final payload = _prefs.getString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      final initial = AppStateEntity.initial();
      await saveState(initial);
      return initial;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return AppStateEntity.fromMap(decoded);
    } catch (_) {
      final fallback = AppStateEntity.initial();
      await saveState(fallback);
      return fallback;
    }
  }

  @override
  Future<void> saveState(AppStateEntity state) async {
    await _prefs.setString(SharedPrefsKeys.appState, jsonEncode(state.toMap()));
  }

  @override
  Future<AppStateEntity> addWallet(WalletEntity wallet) async {
    final current = await loadState();
    final next =
        current.copyWith(wallets: <WalletEntity>[...current.wallets, wallet]);
    await saveState(next);
    return next;
  }

  @override
  Future<AppStateEntity> addTransaction(TransactionEntity transaction) async {
    final current = await loadState();
    var wallets = List<WalletEntity>.from(current.wallets);
    var linkedWallets =
        List<LinkedWalletEntity>.from(current.budgetSetup.linkedWallets);
    var transactions = <TransactionEntity>[
      ...current.transactions,
      transaction
    ];

    if (transaction.transferType == 'allocation-to-jar') {
      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id != transaction.toWalletId) return wallet;
        return LinkedWalletEntity(
          id: wallet.id,
          name: wallet.name,
          balance: wallet.balance + transaction.amount,
          monthlyAmount: wallet.monthlyAmount,
          executionDay: wallet.executionDay,
          fundingSource: wallet.fundingSource,
          funding: wallet.funding,
          icon: wallet.icon,
          iconColor: wallet.iconColor,
          automationType: wallet.automationType,
          categories: wallet.categories,
        );
      }).toList();
    } else if (transaction.transferType == 'jar-to-allocation') {
      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id != transaction.walletId) return wallet;
        return LinkedWalletEntity(
          id: wallet.id,
          name: wallet.name,
          balance: wallet.balance - transaction.amount,
          monthlyAmount: wallet.monthlyAmount,
          executionDay: wallet.executionDay,
          fundingSource: wallet.fundingSource,
          funding: wallet.funding,
          icon: wallet.icon,
          iconColor: wallet.iconColor,
          automationType: wallet.automationType,
          categories: wallet.categories,
        );
      }).toList();
    } else if (transaction.transferType == 'jar-allocation' ||
        transaction.transferType == 'jar-funding' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend') {
      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id != transaction.toWalletId &&
            wallet.id != transaction.walletId) {
          return wallet;
        }
        final delta = transaction.transferType == 'jar-allocation' ||
                transaction.transferType == 'jar-funding'
            ? transaction.amount
            : -transaction.amount;
        return LinkedWalletEntity(
          id: wallet.id,
          name: wallet.name,
          balance: wallet.balance + delta,
          monthlyAmount: wallet.monthlyAmount,
          executionDay: wallet.executionDay,
          fundingSource: wallet.fundingSource,
          funding: wallet.funding,
          icon: wallet.icon,
          iconColor: wallet.iconColor,
          automationType: wallet.automationType,
          categories: wallet.categories,
        );
      }).toList();
    } else if (transaction.type == 'transfer' &&
        transaction.fromWalletId != null &&
        transaction.toWalletId != null) {
      wallets = wallets.map((wallet) {
        if (wallet.id == transaction.fromWalletId) {
          return wallet.copyWith(balance: wallet.balance - transaction.amount);
        }
        if (wallet.id == transaction.toWalletId) {
          return wallet.copyWith(balance: wallet.balance + transaction.amount);
        }
        return wallet;
      }).toList();

      linkedWallets = linkedWallets.map((wallet) {
        if (wallet.id == transaction.toWalletId) {
          return LinkedWalletEntity(
            id: wallet.id,
            name: wallet.name,
            balance: wallet.balance + transaction.amount,
            monthlyAmount: wallet.monthlyAmount,
            executionDay: wallet.executionDay,
            fundingSource: wallet.fundingSource,
            funding: wallet.funding,
            icon: wallet.icon,
            iconColor: wallet.iconColor,
            automationType: wallet.automationType,
            categories: wallet.categories,
          );
        }
        return wallet;
      }).toList();
    } else if (transaction.type == 'income' &&
        transaction.incomeSourceId != null) {
      wallets = wallets.map((wallet) {
        if (wallet.id != transaction.walletId) return wallet;
        final nextBalance = wallet.balance + transaction.amount;
        return wallet.copyWith(balance: nextBalance);
      }).toList();

      final sourceId = transaction.incomeSourceId!;
      var remaining = transaction.amount;

      for (final jar in linkedWallets) {
        final jarPlan = jar.funding
            .where((f) => f.incomeSourceId == sourceId)
            .fold<double>(0, (s, f) => s + f.plannedAmount);
        if (jarPlan <= 0 || remaining <= 0) {
          continue;
        }
        final transferAmount = jarPlan <= remaining ? jarPlan : remaining;
        remaining -= transferAmount;

        linkedWallets = linkedWallets.map((wallet) {
          if (wallet.id != jar.id) {
            return wallet;
          }
          return LinkedWalletEntity(
            id: wallet.id,
            name: wallet.name,
            balance: wallet.balance + transferAmount,
            monthlyAmount: wallet.monthlyAmount,
            executionDay: wallet.executionDay,
            fundingSource: wallet.fundingSource,
            funding: wallet.funding,
            icon: wallet.icon,
            iconColor: wallet.iconColor,
            automationType: wallet.automationType,
            categories: wallet.categories,
          );
        }).toList();

        transactions.add(
          TransactionEntity(
            id: 'txn-auto-jar-${DateTime.now().microsecondsSinceEpoch}',
            amount: transferAmount,
            type: 'transfer',
            fromWalletId: transaction.walletId,
            toWalletId: jar.id,
            transferType: 'jar-funding',
            notes: 'تحويل تلقائي للحصالة: ${jar.name}',
            createdAt: transaction.createdAt,
            incomeSourceId: sourceId,
          ),
        );
      }

      remaining = 0;

      for (final debt in current.budgetSetup.debts
          .where((d) => d.fundingSource == sourceId)) {
        if (remaining <= 0) {
          break;
        }
        final debtAmount = debt.amount <= remaining ? debt.amount : remaining;
        remaining -= debtAmount;

        wallets = wallets.map((wallet) {
          if (wallet.id != transaction.walletId) {
            return wallet;
          }
          return wallet.copyWith(balance: wallet.balance - debtAmount);
        }).toList();

        transactions.add(
          TransactionEntity(
            id: 'txn-auto-debt-${DateTime.now().microsecondsSinceEpoch}',
            amount: debtAmount,
            type: 'expense',
            walletId: transaction.walletId,
            budgetScope: 'outside-budget',
            notes: 'سداد تلقائي للدين: ${debt.name}',
            createdAt: transaction.createdAt,
            incomeSourceId: sourceId,
          ),
        );
      }
    } else {
      wallets = wallets.map((wallet) {
        if (wallet.id != transaction.walletId) return wallet;
        final nextBalance = transaction.type == 'income'
            ? wallet.balance + transaction.amount
            : wallet.balance - transaction.amount;
        return wallet.copyWith(balance: nextBalance);
      }).toList();
    }

    final next = current.copyWith(
      wallets: wallets,
      budgetSetup: current.budgetSetup.copyWith(linkedWallets: linkedWallets),
      transactions: transactions,
    );
    await saveState(next);
    return next;
  }

  @override
  Future<AppStateEntity> updateBudgetSetup(
      BudgetSetupEntity budgetSetup) async {
    final current = await loadState();
    final next = current.copyWith(budgetSetup: budgetSetup);
    await saveState(next);
    return next;
  }
}
