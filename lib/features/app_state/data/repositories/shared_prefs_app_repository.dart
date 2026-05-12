import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../budget/domain/repositories/budget_repository.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../wallets/domain/repositories/wallet_repository.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';
import '../../domain/services/app_state_mutation_service.dart';

class SharedPrefsAppRepository
    implements
        AppRepository,
        WalletRepository,
        TransactionRepository,
        BudgetRepository {
  SharedPrefsAppRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<AppStateEntity> loadState() async {
    final legacy = _readLegacyState();
    final hasSplitState = _hasSplitState;

    if (!hasSplitState) {
      final state = legacy ?? AppStateEntity.initial();
      await saveState(state);
      return state;
    }

    final base = legacy ?? AppStateEntity.initial();
    return base.copyWith(
      wallets: _readWallets() ?? base.wallets,
      transactions: _readTransactions() ?? base.transactions,
      budgetSetup: _readBudget() ?? base.budgetSetup,
    );
  }

  @override
  Future<void> saveState(AppStateEntity state) async {
    await _writeStatePayload(state);
    await _writeWallets(state.wallets);
    await _writeTransactions(state.transactions);
    await _writeBudget(state.budgetSetup);
  }

  @override
  Future<List<WalletEntity>> loadWallets() async {
    final wallets = _readWallets();
    if (wallets != null) {
      return wallets;
    }

    final state = _readLegacyState() ?? AppStateEntity.initial();
    await saveWallets(state.wallets);
    return state.wallets;
  }

  @override
  Future<void> saveWallets(List<WalletEntity> wallets) async {
    await _writeWallets(wallets);
    final state = await loadState();
    await _writeStatePayload(state.copyWith(wallets: wallets));
  }

  @override
  Future<List<TransactionEntity>> loadTransactions() async {
    final transactions = _readTransactions();
    if (transactions != null) {
      return transactions;
    }

    final state = _readLegacyState() ?? AppStateEntity.initial();
    await saveTransactions(state.transactions);
    return state.transactions;
  }

  @override
  Future<void> saveTransactions(List<TransactionEntity> transactions) async {
    await _writeTransactions(transactions);
    final state = await loadState();
    await _writeStatePayload(state.copyWith(transactions: transactions));
  }

  @override
  Future<BudgetSetupEntity> loadBudget() async {
    final budget = _readBudget();
    if (budget != null) {
      return budget;
    }

    final state = _readLegacyState() ?? AppStateEntity.initial();
    await saveBudget(state.budgetSetup);
    return state.budgetSetup;
  }

  @override
  Future<void> saveBudget(BudgetSetupEntity budget) async {
    await _writeBudget(budget);
    final state = await loadState();
    await _writeStatePayload(state.copyWith(budgetSetup: budget));
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

  bool get _hasSplitState =>
      _prefs.containsKey(SharedPrefsKeys.wallets) ||
      _prefs.containsKey(SharedPrefsKeys.transactions) ||
      _prefs.containsKey(SharedPrefsKeys.budget);

  AppStateEntity? _readLegacyState() {
    final payload = _prefs.getString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return AppStateEntity.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  List<WalletEntity>? _readWallets() {
    final payload = _prefs.getString(SharedPrefsKeys.wallets);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WalletEntity.fromMap)
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<TransactionEntity>? _readTransactions() {
    final payload = _prefs.getString(SharedPrefsKeys.transactions);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TransactionEntity.fromMap)
          .toList();
    } catch (_) {
      return null;
    }
  }

  BudgetSetupEntity? _readBudget() {
    final payload = _prefs.getString(SharedPrefsKeys.budget);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return BudgetSetupEntity.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeStatePayload(AppStateEntity state) {
    return _prefs.setString(
      SharedPrefsKeys.appState,
      jsonEncode(state.toMap()),
    );
  }

  Future<void> _writeWallets(List<WalletEntity> wallets) {
    return _prefs.setString(
      SharedPrefsKeys.wallets,
      jsonEncode(wallets.map((wallet) => wallet.toMap()).toList()),
    );
  }

  Future<void> _writeTransactions(List<TransactionEntity> transactions) {
    return _prefs.setString(
      SharedPrefsKeys.transactions,
      jsonEncode(
        transactions.map((transaction) => transaction.toMap()).toList(),
      ),
    );
  }

  Future<void> _writeBudget(BudgetSetupEntity budget) {
    return _prefs.setString(
      SharedPrefsKeys.budget,
      jsonEncode(budget.toMap()),
    );
  }
}
