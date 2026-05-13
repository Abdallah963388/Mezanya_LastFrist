import '../../../../transactions/domain/entities/transaction_entity.dart';
import '../../../domain/services/transaction_mutation_service.dart';
import '../app_cubit.dart';

extension AppCubitTransactionsExtension on AppCubit {
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
    String? details,
  }) async {
    final walletName = walletId == null
        ? null
        : state.wallets
            .where((wallet) => wallet.id == walletId)
            .map((wallet) => wallet.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);
    final incomeName = incomeSourceId == null
        ? null
        : state.budgetSetup.incomeSources
            .where((income) => income.id == incomeSourceId)
            .map((income) => income.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);
    final allocationName = allocationId == null
        ? null
        : state.budgetSetup.allocations
            .where((allocation) => allocation.id == allocationId)
            .map((allocation) => allocation.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);

    final transaction = TransactionEntity(
      id: generateId('txn'),
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
    await applyAndLog(
      action: type == 'transfer' ? 'transfer' : 'add',
      entityType: 'transaction',
      entityId: transaction.id,
      details: details ??
          _transactionDetails(
            type: type,
            amount: amount,
            walletName: walletName,
            incomeName: incomeName,
            allocationName: allocationName,
            budgetScope: budgetScope,
          ),
      titleOverride: notes?.isNotEmpty == true
          ? notes
          : incomeName ?? walletName ?? (type == 'income' ? '???' : '?????'),
      apply: () async {
        await transactionController.addTransaction(
          walletId: walletId,
          fromWalletId: fromWalletId,
          toWalletId: toWalletId,
          amount: amount,
          type: type,
          allocationId: allocationId,
          toAllocationId: toAllocationId,
          budgetScope: budgetScope,
          incomeSourceId: incomeSourceId,
          categoryId: categoryId,
          transferType: transferType,
          notes: notes,
          createdAt: createdAt,
        );

        return repository.loadState();
      },
    );
  }

  @Deprecated('Use TransactionController instead')
  Future<void> deleteTransaction(String transactionId) async {
    final target = state.transactions.where((item) => item.id == transactionId).toList();
    if (target.isEmpty) return;
    final transaction = target.first;

    final mutationResult = TransactionMutationService.reverseTransaction(
      wallets: state.wallets,
      transactions: state.transactions,
      budgetSetup: state.budgetSetup,
      transaction: transaction,
    );

    final refreshedState = await repository.loadState();
    final next = refreshedState.copyWith(
      wallets: mutationResult.wallets,
      budgetSetup: mutationResult.budgetSetup,
      transactions: refreshedState.transactions,
    );

    await applyAndLog(
      action: 'delete',
      entityType: 'transaction',
      entityId: transactionId,
      details:
          '?? ??? ?????? ${_transactionTypeLabel(transaction.type)} ????? ${transaction.amount.toStringAsFixed(2)}',
      apply: () async => next,
    );
  }

  String _transactionDetails({
    required String type,
    required double amount,
    String? walletName,
    String? incomeName,
    String? allocationName,
    String? budgetScope,
  }) {
    if (type == 'income') {
      final source = incomeName ?? '???? ??? ????';
      final wallet = walletName ?? '????? ??? ?????';
      return '?????? ??? ????? ${amount.toStringAsFixed(2)} ?? $source ??? $wallet';
    }
    if (type == 'expense') {
      final budgetLabel =
          budgetScope == 'within-budget' ? '???? ?????????' : '???? ?????????';
      final allocation = allocationName == null ? '' : ' ??? ???? $allocationName';
      final wallet = walletName ?? '????? ??? ?????';
      return '?????? ????? ????? ${amount.toStringAsFixed(2)} ?? $wallet ($budgetLabel)$allocation';
    }
    return '?????? ????? ????? ${amount.toStringAsFixed(2)}';
  }

  String _transactionTypeLabel(String type) {
    return switch (type) {
      'income' => '???',
      'expense' => '?????',
      'transfer' => '?????',
      _ => type,
    };
  }
}

