import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';

import '../../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../../transactions/domain/entities/transaction_entity.dart';
import '../app_cubit.dart';

extension AppCubitRecurringExtension on AppCubit {
  Future<void> addRecurringTransaction({
    String? id,
    required String name,
    required String type,
    required double amount,
    required int dayOfMonth,
    required String executionType,
    required String walletId,
    required String budgetScope,
    required String recurrencePattern,
    required String icon,
    required String iconColor,
    int? weekday,
    List<int>? weekdays,
    int? monthOfYear,
    String? anchorDate,
    String? scheduledTime,
    int? reminderLeadDays,
    String? allocationId,
    String? targetJarId,
    String? incomeSourceId,
    List<String>? categoryIds,
    bool isVariableIncome = false,
    bool isDebtOrSubscription = false,
    String? expensePlanKind,
    double? debtPrincipalTotal,
    int? installmentCount,
    double? installmentDownPayment,
    String? notes,
  }) async {
    final recurring = RecurringTransactionEntity(
      id: id ?? generateId('rec'),
      name: name,
      type: type,
      amount: amount,
      dayOfMonth: dayOfMonth,
      executionType: executionType,
      walletId: walletId,
      budgetScope: budgetScope,
      recurrencePattern: recurrencePattern,
      icon: icon,
      iconColor: iconColor,
      weekday: weekday,
      weekdays: weekdays ?? const [],
      monthOfYear: monthOfYear,
      anchorDate: anchorDate,
      scheduledTime: scheduledTime,
      reminderLeadDays: reminderLeadDays,
      allocationId: allocationId,
      targetJarId: targetJarId,
      incomeSourceId: incomeSourceId,
      categoryIds: categoryIds ?? const [],
      isVariableIncome: isVariableIncome,
      isDebtOrSubscription: isDebtOrSubscription,
      expensePlanKind: expensePlanKind,
      debtPrincipalTotal: debtPrincipalTotal,
      installmentCount: installmentCount,
      installmentDownPayment: installmentDownPayment,
      notes: notes,
    );

    final alreadyLinked = state.budgetSetup.debts
        .any((debt) => debt.recurringTransactionId == recurring.id);
    final nextBudget = (isDebtOrSubscription && !alreadyLinked)
        ? state.budgetSetup.copyWith(debts: [
            ...state.budgetSetup.debts,
            DebtEntity(
              id: 'debt-${recurring.id}',
              name: recurring.name,
              amount: recurring.amount,
              executionDay: recurring.dayOfMonth.clamp(1, 28),
              type: recurring.executionType,
              fundingSource: state.budgetSetup.incomeSources.isNotEmpty
                  ? state.budgetSetup.incomeSources.first.id
                  : '',
              recurringTransactionId: recurring.id,
              kind: recurring.expensePlanKind == 'installment'
                  ? 'installment'
                  : 'subscription',
              principalTotal: recurring.debtPrincipalTotal,
              installmentCount: recurring.installmentCount,
              downPayment: recurring.installmentDownPayment,
              recurrencePattern: recurring.recurrencePattern,
              monthOfYear: recurring.monthOfYear,
            ),
          ])
        : state.budgetSetup;

    final next = state.copyWith(
      recurringTransactions: [...state.recurringTransactions, recurring],
      budgetSetup: nextBudget,
    );
    await applyAndLog(
      action: 'add',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: _recurringTransactionDetails('????? ?????? ??????', recurring),
      apply: () async => next,
    );
  }

  Future<void> updateRecurringTransaction(
    RecurringTransactionEntity recurring, {
    String? detailsOverride,
  }) async {
    final next = _applyRecurringSync(state, recurring);
    await applyAndLog(
      action: 'edit',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: detailsOverride ??
          _recurringTransactionDetails('????? ?????? ??????', recurring),
      titleOverride: recurring.name,
      apply: () async => next,
    );
  }

  Future<void> recordRecurringExpenseOccurrence({
    required RecurringTransactionEntity recurring,
    required double amount,
    required DateTime occurrence,
    required String transactionNotes,
    required String logDetails,
    String? titleOverride,
  }) async {
    final transaction = TransactionEntity(
      id: generateId('txn'),
      walletId: recurring.walletId,
      amount: amount,
      type: 'expense',
      budgetScope: recurring.budgetScope,
      allocationId: recurring.allocationId,
      categoryId:
          recurring.categoryIds.isNotEmpty ? recurring.categoryIds.first : null,
      notes: transactionNotes,
      createdAt: DateTime.now(),
    );

    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await applyAndLog(
      action: 'add',
      entityType: 'recurring-expense-handled',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? recurring.name,
      apply: () async {
        final stateAfterTx = await repository.addTransaction(transaction);
        return _applyRecurringSync(stateAfterTx, updatedRecurring);
      },
    );
  }

  Future<void> recordRecurringPostpone({
    required RecurringTransactionEntity recurring,
    required DateTime snoozedUntil,
    required String logDetails,
  }) async {
    final updatedRecurring = recurring.copyWith(
      snoozedUntil: snoozedUntil.toIso8601String(),
    );

    await applyAndLog(
      action: 'edit',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: recurring.name,
      apply: () async => _applyRecurringSync(state, updatedRecurring),
    );
  }

  Future<void> recordRecurringSkip({
    required RecurringTransactionEntity recurring,
    required DateTime occurrence,
    required String logDetails,
  }) async {
    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await applyAndLog(
      action: 'skip',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: recurring.name,
      apply: () async => _applyRecurringSync(state, updatedRecurring),
    );
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final target =
        state.recurringTransactions.where((item) => item.id == id).toList();
    final deleted = target.isEmpty ? null : target.first;

    final nextBudget = state.budgetSetup.copyWith(
      debts: state.budgetSetup.debts
          .where((debt) => debt.recurringTransactionId != id)
          .toList(),
    );

    final next = state.copyWith(
      recurringTransactions:
          state.recurringTransactions.where((item) => item.id != id).toList(),
      budgetSetup: nextBudget,
    );
    await applyAndLog(
      action: 'delete',
      entityType: 'recurring-transaction',
      entityId: id,
      details: deleted == null
          ? '?? ??? ?????? ??????'
          : _recurringTransactionDetails('??? ?????? ??????', deleted),
      apply: () async => next,
    );
  }

  AppStateEntity _applyRecurringSync(
    AppStateEntity source,
    RecurringTransactionEntity recurring,
  ) {
    BudgetSetupEntity nextBudget = source.budgetSetup;
    if (recurring.isDebtOrSubscription) {
      final linkedIndex = source.budgetSetup.debts
          .indexWhere((debt) => debt.recurringTransactionId == recurring.id);
      if (linkedIndex >= 0) {
        final existing = source.budgetSetup.debts[linkedIndex];
        final updated = existing.copyWith(
          name: recurring.name,
          amount: recurring.amount,
          executionDay: recurring.dayOfMonth.clamp(1, 28),
          type: recurring.executionType,
          kind: recurring.expensePlanKind == 'installment'
              ? 'installment'
              : 'subscription',
          principalTotal: recurring.debtPrincipalTotal,
          installmentCount: recurring.installmentCount,
          downPayment: recurring.installmentDownPayment,
          recurrencePattern: recurring.recurrencePattern,
          monthOfYear: recurring.monthOfYear,
        );
        final updatedDebts = List<DebtEntity>.from(source.budgetSetup.debts)
          ..[linkedIndex] = updated;
        nextBudget = source.budgetSetup.copyWith(debts: updatedDebts);
      }
    }
    return source.copyWith(
      recurringTransactions: source.recurringTransactions
          .map((item) => item.id == recurring.id ? recurring : item)
          .toList(),
      budgetSetup: nextBudget,
    );
  }

  String _transactionTypeLabel(String type) {
    return switch (type) {
      'income' => '???',
      'expense' => '?????',
      'transfer' => '?????',
      _ => type,
    };
  }

  String _executionTypeLabel(String type) {
    return switch (type) {
      'auto' => '??????',
      'confirm' => '????? ?????',
      'manual' => '????',
      _ => type,
    };
  }

  String _budgetScopeLabel(String scope) {
    return scope == 'within-budget' ? '???? ?????????' : '???? ?????????';
  }

  String _recurrenceLabel(String pattern) {
    return switch (pattern) {
      'daily' => '????',
      'weekly' => '??????',
      'biweekly' => '?? ???????',
      'every_3_weeks' => '?? 3 ??????',
      'monthly' => '????',
      'every_2_months' => '?? ?????',
      'every_3_months' => '?? 3 ????',
      'every_6_months' => '?? 6 ????',
      'yearly' => '????',
      'manual-variable' => '???? ?????',
      _ => pattern,
    };
  }

  String _recurringTransactionDetails(
    String action,
    RecurringTransactionEntity recurring,
  ) {
    final type = _transactionTypeLabel(recurring.type);
    final amount = recurring.isVariableIncome
        ? '??? ?????'
        : recurring.amount.toStringAsFixed(2);
    final debtLabel = recurring.isDebtOrSubscription
        ? recurring.expensePlanKind == 'installment'
            ? ' � ?????'
            : recurring.expensePlanKind == 'subscription'
                ? ' � ??????'
                : ' � ??? ?? ??????'
        : '';
    return '$action: ${recurring.name} � ?????: $type � ??????: $amount � ???????: ${_recurrenceLabel(recurring.recurrencePattern)} � ???????: ${_executionTypeLabel(recurring.executionType)} � ${_budgetScopeLabel(recurring.budgetScope)}$debtLabel';
  }
}
