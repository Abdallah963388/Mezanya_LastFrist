import 'package:flutter/foundation.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';

class AppController extends ChangeNotifier {
  AppController(this._repository);

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

  Future<void> addTransaction({
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    required double amount,
    required String type,
    String? allocationId,
    String? budgetScope,
    String? incomeSourceId,
    String? categoryId,
    String? transferType,
    String? notes,
    DateTime? createdAt,
  }) async {
    final transaction = TransactionEntity(
      id: 'txn-${DateTime.now().millisecondsSinceEpoch}',
      walletId: walletId,
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      allocationId: allocationId,
      budgetScope: budgetScope,
      incomeSourceId: incomeSourceId,
      categoryId: categoryId,
      transferType: transferType,
      amount: amount,
      type: type,
      notes: notes,
      createdAt: createdAt ?? DateTime.now(),
    );
    _state = await _repository.addTransaction(transaction);
    notifyListeners();
  }

  Future<void> updateBudgetSetup(BudgetSetupEntity setup) async {
    _state = await _repository.updateBudgetSetup(setup);
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
        .map((wallet) => wallet.id == id ? wallet.copyWith(name: name, balance: balance, icon: icon, iconColor: iconColor) : wallet)
        .toList();
    _state = _state.copyWith(wallets: wallets);
    await _repository.saveState(_state);
    notifyListeners();
  }

  Future<void> deleteWallet(String id) async {
    _state = _state.copyWith(wallets: _state.wallets.where((wallet) => wallet.id != id).toList());
    await _repository.saveState(_state);
    notifyListeners();
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    final budget = _state.budgetSetup;
    await updateBudgetSetup(
      budget.copyWith(linkedWallets: [...budget.linkedWallets, linkedWallet]),
    );
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    final budget = _state.budgetSetup;
    await updateBudgetSetup(
      budget.copyWith(
        linkedWallets: budget.linkedWallets
            .map((item) => item.id == linkedWallet.id ? linkedWallet : item)
            .toList(),
      ),
    );
  }

  Future<void> deleteLinkedWallet(String id) async {
    final budget = _state.budgetSetup;
    await updateBudgetSetup(
      budget.copyWith(
        linkedWallets: budget.linkedWallets.where((wallet) => wallet.id != id).toList(),
      ),
    );
  }

  Future<void> setCategories(List<CategoryEntity> categories) async {
    _state = _state.copyWith(categories: categories);
    await _repository.saveState(_state);
    notifyListeners();
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    final budget = _state.budgetSetup;
    final allocations = budget.allocations
        .map((item) => item.id == allocationId
            ? item.copyWith(categories: categories)
            : item)
        .toList();
    await updateBudgetSetup(budget.copyWith(allocations: allocations));
  }

  Future<void> updateLinkedWalletCategories({
    required String linkedWalletId,
    required List<CategoryEntity> categories,
  }) async {
    final budget = _state.budgetSetup;
    final linkedWallets = budget.linkedWallets
        .map((item) => item.id == linkedWalletId
            ? item.copyWith(categories: categories)
            : item)
        .toList();
    await updateBudgetSetup(budget.copyWith(linkedWallets: linkedWallets));
  }
}
