import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../budget/data/repositories/budget_shared_prefs_repository.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../budget/domain/repositories/budget_repository.dart';
import '../../../transactions/data/repositories/transaction_shared_prefs_repository.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../wallets/data/repositories/wallet_shared_prefs_repository.dart';
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
  late final WalletRepository _walletRepository =
      WalletSharedPrefsRepository(_prefs);
  late final TransactionRepository _transactionRepository =
      TransactionSharedPrefsRepository(_prefs);
  late final BudgetRepository _budgetRepository =
      BudgetSharedPrefsRepository(_prefs);

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
      wallets: await loadWallets(),
      transactions: await loadTransactions(),
      budgetSetup: await loadBudget(),
    );
  }

  @override
  Future<void> saveState(AppStateEntity state) async {
    await _writeStatePayload(state);
    await _walletRepository.saveWallets(state.wallets);
    await _transactionRepository.saveTransactions(state.transactions);
    await _budgetRepository.saveBudget(state.budgetSetup);
  }

  @override
  Future<List<WalletEntity>> loadWallets() async {
    return _walletRepository.loadWallets();
  }

  @override
  Future<void> saveWallets(List<WalletEntity> wallets) async {
    await _walletRepository.saveWallets(wallets);
    final state = await loadState();
    await _writeStatePayload(state.copyWith(wallets: wallets));
  }

  @override
  Future<List<TransactionEntity>> loadTransactions() async {
    return _transactionRepository.loadTransactions();
  }

  @override
  Future<void> saveTransactions(List<TransactionEntity> transactions) async {
    await _transactionRepository.saveTransactions(transactions);
    final state = await loadState();
    await _writeStatePayload(state.copyWith(transactions: transactions));
  }

  @override
  Future<BudgetSetupEntity> loadBudget() async {
    return _budgetRepository.loadBudget();
  }

  @override
  Future<void> saveBudget(BudgetSetupEntity budget) async {
    await _budgetRepository.saveBudget(budget);
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

  Future<void> _writeStatePayload(AppStateEntity state) {
    return _prefs.setString(
      SharedPrefsKeys.appState,
      jsonEncode(state.toMap()),
    );
  }
}
