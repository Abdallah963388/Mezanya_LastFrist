import '../../domain/entities/transaction_entity.dart';

class TransactionState {
  const TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.isSubmitting = false,
  });

  final List<TransactionEntity> transactions;
  final bool isLoading;
  final bool isSubmitting;

  bool get hasTransactions => transactions.isNotEmpty;

  int get transactionCount => transactions.length;

  List<TransactionEntity> get latestTransactions {
    final items = [...transactions];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(10).toList();
  }

  double get totalIncome => transactions
      .where((transaction) => transaction.type == 'income')
      .fold(0, (sum, transaction) => sum + transaction.amount);

  double get totalExpenses => transactions
      .where((transaction) => transaction.type == 'expense')
      .fold(0, (sum, transaction) => sum + transaction.amount);

  TransactionState copyWith({
    List<TransactionEntity>? transactions,
    bool? isLoading,
    bool? isSubmitting,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
