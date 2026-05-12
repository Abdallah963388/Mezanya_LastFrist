import 'package:flutter/foundation.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/add_transaction_usecase.dart';

class TransactionController extends ChangeNotifier {
  TransactionController(
    AppRepository repository, {
    AddTransactionUseCase? addTransactionUseCase,
  })  : _repository = repository,
        _addTransactionUseCase = addTransactionUseCase ??
            AddTransactionUseCase.repository(repository);

  final AppRepository _repository;
  final AddTransactionUseCase _addTransactionUseCase;

  AppStateEntity _state = AppStateEntity.initial();

  AppStateEntity get state => _state;
  List<TransactionEntity> get transactions => _state.transactions;

  Future<void> initialize() async {
    _state = await _repository.loadState();
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = await _repository.loadState();
    notifyListeners();
  }

  Future<void> addTransaction({
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    required double amount,
    required String type,
    String? allocationId,
    String? toAllocationId,
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
      toAllocationId: toAllocationId,
      budgetScope: budgetScope,
      incomeSourceId: incomeSourceId,
      categoryId: categoryId,
      transferType: transferType,
      amount: amount,
      type: type,
      notes: notes,
      createdAt: createdAt ?? DateTime.now(),
    );

    _state = await _addTransactionUseCase.add(transaction);
    notifyListeners();
  }
}
