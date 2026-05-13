import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import 'transaction_state.dart';

class TransactionCubit extends Cubit<TransactionState> {
  TransactionCubit(
    this._repository,
    this._addTransactionUseCase,
  ) : super(const TransactionState());

  final TransactionRepository _repository;
  final AddTransactionUseCase _addTransactionUseCase;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final transactions = await _repository.loadTransactions();
    emit(state.copyWith(transactions: transactions, isLoading: false));
  }

  Future<void> refresh() async {
    final transactions = await _repository.loadTransactions();
    emit(state.copyWith(transactions: transactions));
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
    if (state.isSubmitting) {
      return;
    }

    emit(state.copyWith(isSubmitting: true));
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

      final transactions = await _addTransactionUseCase.add(transaction);
      emit(
        state.copyWith(
          transactions: transactions,
          isSubmitting: false,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isSubmitting: false));
      rethrow;
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    final updated = state.transactions
        .where((transaction) => transaction.id != transactionId)
        .toList();

    await _repository.saveTransactions(updated);
    emit(state.copyWith(transactions: updated));
  }

  List<TransactionEntity> transactionsForPeriod(
    DateTime start,
    DateTime end,
  ) {
    return state.transactions
        .where(
          (transaction) =>
              !transaction.createdAt.isBefore(start) &&
              !transaction.createdAt.isAfter(end),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
