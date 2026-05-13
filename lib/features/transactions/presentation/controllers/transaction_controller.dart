import 'package:flutter/foundation.dart';

import '../../../budget/domain/repositories/budget_repository.dart';
import '../../../wallets/domain/repositories/wallet_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/add_transaction_usecase.dart';

class TransactionController extends ChangeNotifier {
  TransactionController(
    TransactionRepository transactionRepository,
    WalletRepository walletRepository,
    BudgetRepository budgetRepository, {
    AddTransactionUseCase? addTransactionUseCase,
  })  : _repository = transactionRepository,
        _addTransactionUseCase = addTransactionUseCase ??
            AddTransactionUseCase.repository(
              walletRepository,
              transactionRepository,
              budgetRepository,
            );

  final TransactionRepository _repository;
  final AddTransactionUseCase _addTransactionUseCase;

  List<TransactionEntity> _transactions = [];

  bool _isSubmittingTransaction = false;

  List<TransactionEntity> get transactions => _transactions;

  List<TransactionEntity> get latestTransactions {
    final items = [..._transactions];

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return items.take(10).toList();
  }

  double get totalIncome => _transactions
      .where((transaction) => transaction.type == 'income')
      .fold(0, (sum, transaction) => sum + transaction.amount);

  double get totalExpenses => _transactions
      .where((transaction) => transaction.type == 'expense')
      .fold(0, (sum, transaction) => sum + transaction.amount);

  bool get hasTransactions => _transactions.isNotEmpty;

  int get transactionCount => _transactions.length;

  List<TransactionEntity> transactionsForPeriod(
    DateTime start,
    DateTime end,
  ) {
    return _transactions
        .where(
          (transaction) =>
              !transaction.createdAt.isBefore(start) &&
              !transaction.createdAt.isAfter(end),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> initialize() async {
    _transactions = await _repository.loadTransactions();
    notifyListeners();
  }

  Future<void> refresh() async {
    _transactions = await _repository.loadTransactions();
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
    if (_isSubmittingTransaction) {
      return;
    }

    _isSubmittingTransaction = true;

    try {
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

      _transactions = await _addTransactionUseCase.add(transaction);
      notifyListeners();
    } finally {
      _isSubmittingTransaction = false;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    final updated = _transactions
        .where((transaction) => transaction.id != transactionId)
        .toList();

    await _repository.saveTransactions(updated);

    _transactions = updated;

    notifyListeners();
  }
}

