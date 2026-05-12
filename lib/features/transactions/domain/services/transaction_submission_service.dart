class TransactionSubmissionRequest {
  const TransactionSubmissionRequest({
    required this.walletId,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.toWalletId,
    this.allocationId,
    this.budgetScope,
    this.incomeSourceId,
    this.notes,
    this.categoryId,
  });

  final String? walletId;
  final String? toWalletId;
  final double amount;
  final String type;
  final DateTime createdAt;
  final String? allocationId;
  final String? budgetScope;
  final String? incomeSourceId;
  final String? notes;
  final String? categoryId;
}

class TransactionSubmissionService {
  const TransactionSubmissionService._();

  static TransactionSubmissionRequest build({
    required String walletId,
    required String type,
    required double amount,
    required DateTime createdAt,
    required String budgetTargetId,
    required String incomeJarId,
    required String incomeBudgetScope,
    required String incomeSourceId,
    required String notes,
    required String? categoryId,
  }) {
    final resolvedWalletId = walletId == 'no-wallet' ? null : walletId;

    String? allocationId;
    String? toWalletId;

    if (budgetTargetId.startsWith('alloc:')) {
      allocationId = budgetTargetId.replaceFirst('alloc:', '');
    }

    if (budgetTargetId.startsWith('jar:')) {
      toWalletId = budgetTargetId.replaceFirst('jar:', '');
    }

    if (type == 'income' &&
        incomeBudgetScope == 'within-budget' &&
        incomeJarId.isNotEmpty) {
      toWalletId = incomeJarId;
    }

    return TransactionSubmissionRequest(
      walletId: resolvedWalletId,
      toWalletId: toWalletId,
      amount: amount,
      type: type,
      createdAt: createdAt,
      allocationId: allocationId,
      budgetScope: type == 'income'
          ? incomeBudgetScope
          : (budgetTargetId.isEmpty ? 'outside-budget' : 'within-budget'),
      incomeSourceId:
          incomeSourceId == 'wallet-only' ? null : incomeSourceId,
      notes: notes.trim().isEmpty ? null : notes.trim(),
      categoryId: categoryId,
    );
  }
}
