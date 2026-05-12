import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
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
    final next = AppStateMutationService.addWallet(
      current: current,
      wallet: wallet,
    );
    await saveState(next);
    return next;
  }

  @override
  Future<AppStateEntity> addTransaction(TransactionEntity transaction) async {
    final current = await loadState();
    final next = AppStateMutationService.addTransaction(
      current: current,
      transaction: transaction,
    );
    await saveState(next);
    return next;
  }

  @override
  Future<AppStateEntity> updateBudgetSetup(
    BudgetSetupEntity budgetSetup,
  ) async {
    final current = await loadState();
    final next = AppStateMutationService.updateBudgetSetup(
      current: current,
      budgetSetup: budgetSetup,
    );
    await saveState(next);
    return next;
  }
}
