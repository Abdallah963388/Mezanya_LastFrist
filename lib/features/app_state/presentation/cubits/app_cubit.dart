import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';

class AppCubit extends Cubit<AppStateEntity> {
  AppCubit(this._repository) : super(AppStateEntity.initial());

  final AppRepository _repository;

  Future<void> initialize() async {
    emit(await _repository.loadState());
    await ensureDefaultSavingsJar();
    await syncSavingsJarWithReserved();
    await _migrateOrphanedDebtRecurring();
    final key = _monthKey();
    if (!state.monthlyBudgetSnapshots.containsKey(key)) {
      final next = _withMonthlySnapshot(state, state.budgetSetup);
      await _repository.saveState(next);
      emit(next);
    }
  }

  /// مزامنة الديون/الاشتراكات القديمة التي تُحفظ كـ RecurringTransaction
  /// بدون DebtEntity مقابلة في budget.debts
  Future<void> _migrateOrphanedDebtRecurring() async {
    final linkedIds = state.budgetSetup.debts
        .map((d) => d.recurringTransactionId)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    final orphaned = state.recurringTransactions.where(
      (r) =>
          r.isDebtOrSubscription &&
          r.type == 'expense' &&
          r.budgetScope == 'within-budget' &&
          !linkedIds.contains(r.id),
    );

    if (orphaned.isEmpty) return;

    final fallbackFundingSource = state.budgetSetup.incomeSources.isNotEmpty
        ? state.budgetSetup.incomeSources.first.id
        : '';

    final newDebts = orphaned.map((r) => DebtEntity(
          id: 'debt-${r.id}',
          name: r.name,
          amount: r.amount,
          executionDay: r.dayOfMonth.clamp(1, 28),
          type: r.executionType,
          fundingSource: fallbackFundingSource,
          recurringTransactionId: r.id,
          kind: r.expensePlanKind == 'installment' ? 'installment' : 'subscription',
          principalTotal: r.debtPrincipalTotal,
          recurrencePattern: r.recurrencePattern,
          monthOfYear: r.monthOfYear,
        ));

    final nextSetup = state.budgetSetup.copyWith(
      debts: [...state.budgetSetup.debts, ...newDebts],
    );
    final next = state.copyWith(budgetSetup: nextSetup);
    await _repository.saveState(next);
    emit(next);
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  String _monthKey([DateTime? at]) {
    final date = at ?? DateTime.now();
    final mm = date.month.toString().padLeft(2, '0');
    return '${date.year}-$mm';
  }

  AppStateEntity _withMonthlySnapshot(
    AppStateEntity source,
    BudgetSetupEntity setup, [
    DateTime? month,
  ]) {
    final snapshots = Map<String, Map<String, dynamic>>.from(
      source.monthlyBudgetSnapshots,
    );
    snapshots[_monthKey(month)] = setup.toMap();
    return source.copyWith(monthlyBudgetSnapshots: snapshots);
  }

  Map<String, dynamic> _coreMap(AppStateEntity appState) {
    final map = appState.toMap();
    map.remove('logs');
    return map;
  }

  AppStateEntity _restoreFromCore(String coreJson, List<LogEntryEntity> logs) {
    final map = jsonDecode(coreJson) as Map<String, dynamic>;
    return AppStateEntity.fromMap(map).copyWith(logs: logs);
  }

  Future<void> _applyAndLog({
    required String action,
    required String entityType,
    required String entityId,
    required String details,
    required Future<AppStateEntity> Function() apply,
  }) async {
    final before = jsonEncode(_coreMap(state));
    final nextRaw = await apply();
    final after = jsonEncode(_coreMap(nextRaw));
    final title = _notificationTitle(action, entityType);
    final log = LogEntryEntity(
      id: _id('log'),
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: DateTime.now(),
      beforeState: before,
      afterState: after,
      isReverted: false,
    );
    final notification = NotificationEntity(
      id: _id('notif'),
      title: title,
      message: details,
      createdAt: DateTime.now(),
      type: entityType,
      relatedLogId: log.id,
    );
    final next = nextRaw.copyWith(
      logs: [log, ...nextRaw.logs].take(600).toList(),
      notifications:
          [notification, ...nextRaw.notifications].take(800).toList(),
    );
    await _repository.saveState(next);
    emit(next);
  }

  String _notificationTitle(String action, String entityType) {
    if (entityType == 'income' || entityType == 'transaction') {
      return 'إشعار معاملة';
    }
    if (entityType == 'budget') {
      return 'إشعار الميزانية';
    }
    if (entityType == 'recurring-transaction') {
      return 'إشعار معاملة متكررة';
    }
    if (entityType == 'goal') {
      return 'إشعار هدف';
    }
    if (action == 'delete') {
      return 'إشعار حذف';
    }
    return 'إشعار جديد';
  }

  Future<void> addWallet({
    required String name,
    required double openingBalance,
    String? icon,
    String? iconColor,
  }) async {
    final wallet = WalletEntity(
      id: _id('wallet'),
      name: name,
      balance: openingBalance,
      icon: icon,
      iconColor: iconColor,
    );
    await _applyAndLog(
      action: 'add',
      entityType: 'wallet',
      entityId: wallet.id,
      details: 'تمت إضافة محفظة جديدة: $name',
      apply: () => _repository.addWallet(wallet),
    );
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
    final walletName = walletId == null
        ? null
        : state.wallets
            .where((w) => w.id == walletId)
            .map((w) => w.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);
    final incomeName = incomeSourceId == null
        ? null
        : state.budgetSetup.incomeSources
            .where((i) => i.id == incomeSourceId)
            .map((i) => i.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);
    final allocationName = allocationId == null
        ? null
        : state.budgetSetup.allocations
            .where((a) => a.id == allocationId)
            .map((a) => a.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);

    final transaction = TransactionEntity(
      id: _id('txn'),
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
    await _applyAndLog(
      action: type == 'transfer' ? 'transfer' : 'add',
      entityType: 'transaction',
      entityId: transaction.id,
      details: _transactionDetails(
        type: type,
        amount: amount,
        walletName: walletName,
        incomeName: incomeName,
        allocationName: allocationName,
        budgetScope: budgetScope,
      ),
      apply: () => _repository.addTransaction(transaction),
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
      final source = incomeName ?? 'مصدر غير محدد';
      final wallet = walletName ?? 'محفظة غير محددة';
      return 'معاملة دخل بقيمة ${amount.toStringAsFixed(2)} من $source إلى $wallet';
    }
    if (type == 'expense') {
      final budgetLabel =
          budgetScope == 'within-budget' ? 'داخل الميزانية' : 'خارج الميزانية';
      final alloc = allocationName == null ? '' : ' ضمن مخصص $allocationName';
      final wallet = walletName ?? 'محفظة غير محددة';
      return 'معاملة مصروف بقيمة ${amount.toStringAsFixed(2)} من $wallet ($budgetLabel)$alloc';
    }
    return 'معاملة تحويل بقيمة ${amount.toStringAsFixed(2)}';
  }

  Future<void> deleteTransaction(String transactionId) async {
    final target =
        state.transactions.where((t) => t.id == transactionId).toList();
    if (target.isEmpty) {
      return;
    }
    final transaction = target.first;
    var wallets = List<WalletEntity>.from(state.wallets);
    var linked = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);

    if (transaction.transferType == 'allocation-to-jar') {
      linked = linked.map((j) {
        if (transaction.toWalletId != null && j.id == transaction.toWalletId) {
          return LinkedWalletEntity(
            id: j.id,
            name: j.name,
            balance: j.balance - transaction.amount,
            monthlyAmount: j.monthlyAmount,
            executionDay: j.executionDay,
            fundingSource: j.fundingSource,
            funding: j.funding,
            icon: j.icon,
            iconColor: j.iconColor,
            automationType: j.automationType,
            categories: j.categories,
          );
        }
        return j;
      }).toList();
    } else if (transaction.transferType == 'jar-to-allocation') {
      linked = linked.map((j) {
        if (transaction.walletId != null && j.id == transaction.walletId) {
          return LinkedWalletEntity(
            id: j.id,
            name: j.name,
            balance: j.balance + transaction.amount,
            monthlyAmount: j.monthlyAmount,
            executionDay: j.executionDay,
            fundingSource: j.fundingSource,
            funding: j.funding,
            icon: j.icon,
            iconColor: j.iconColor,
            automationType: j.automationType,
            categories: j.categories,
          );
        }
        return j;
      }).toList();
    } else if (transaction.type == 'transfer') {
      wallets = wallets.map((w) {
        if (transaction.fromWalletId != null &&
            w.id == transaction.fromWalletId) {
          return w.copyWith(balance: w.balance + transaction.amount);
        }
        if (transaction.toWalletId != null && w.id == transaction.toWalletId) {
          return w.copyWith(balance: w.balance - transaction.amount);
        }
        return w;
      }).toList();
      linked = linked.map((j) {
        if (transaction.toWalletId != null && j.id == transaction.toWalletId) {
          return LinkedWalletEntity(
            id: j.id,
            name: j.name,
            balance: j.balance - transaction.amount,
            monthlyAmount: j.monthlyAmount,
            executionDay: j.executionDay,
            fundingSource: j.fundingSource,
            funding: j.funding,
            icon: j.icon,
            iconColor: j.iconColor,
            automationType: j.automationType,
            categories: j.categories,
          );
        }
        return j;
      }).toList();
    } else if (transaction.type == 'income') {
      wallets = wallets.map((w) {
        if (transaction.walletId != null && w.id == transaction.walletId) {
          return w.copyWith(balance: w.balance - transaction.amount);
        }
        return w;
      }).toList();
    } else if (transaction.type == 'expense') {
      wallets = wallets.map((w) {
        if (transaction.walletId != null && w.id == transaction.walletId) {
          return w.copyWith(balance: w.balance + transaction.amount);
        }
        return w;
      }).toList();
    }

    final next = state.copyWith(
      wallets: wallets,
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: linked),
      transactions:
          state.transactions.where((t) => t.id != transactionId).toList(),
    );
    await _applyAndLog(
      action: 'delete',
      entityType: 'transaction',
      entityId: transactionId,
      details:
          'تم حذف معاملة ${_transactionTypeLabel(transaction.type)} بقيمة ${transaction.amount.toStringAsFixed(2)}',
      apply: () async => next,
    );
  }

  Future<void> updateBudgetSetup(BudgetSetupEntity setup) async {
    await _applyAndLog(
      action: 'edit',
      entityType: 'budget',
      entityId: 'budget-setup',
      details: 'تم تعديل إعدادات الميزانية',
      apply: () async {
        final raw = await _repository.updateBudgetSetup(setup);
        return _withMonthlySnapshot(raw, setup);
      },
    );
  }

  Future<void> updateWallet({
    required String id,
    String? name,
    double? balance,
    String? icon,
    String? iconColor,
  }) async {
    final wallets = state.wallets
        .map((wallet) => wallet.id == id
            ? wallet.copyWith(
                name: name, balance: balance, icon: icon, iconColor: iconColor)
            : wallet)
        .toList();
    final next = state.copyWith(wallets: wallets);
    await _applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: id,
      details: 'تم تعديل بيانات المحفظة',
      apply: () async => next,
    );
  }

  Future<void> reorderWallets(List<WalletEntity> ordered) async {
    final next = state.copyWith(wallets: ordered);
    await _applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: 'wallets-order',
      details: 'تم إعادة ترتيب المحافظ',
      apply: () async => next,
    );
  }

  Future<void> reorderJars(List<LinkedWalletEntity> ordered) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: ordered),
    );
  }

  Future<void> deleteWallet(String id) async {
    final next = state.copyWith(
        wallets: state.wallets.where((wallet) => wallet.id != id).toList());
    await _applyAndLog(
      action: 'delete',
      entityType: 'wallet',
      entityId: id,
      details: 'تم حذف محفظة',
      apply: () async => next,
    );
  }

  Future<void> applySavingsReserve({
    required String walletId,
    required double amount,
    required String action,
  }) async {
    if (amount <= 0) return;
    final walletList = List<WalletEntity>.from(state.wallets);
    final idx = walletList.indexWhere((w) => w.id == walletId);
    if (idx == -1) return;
    final wallet = walletList[idx];

    double nextReserved = wallet.reservedForSavings;
    if (action == 'allocate') {
      nextReserved += amount;
    } else {
      nextReserved -= amount;
    }
    if (nextReserved < 0) nextReserved = 0;

    walletList[idx] = wallet.copyWith(reservedForSavings: nextReserved);
    final totalReserved =
        walletList.fold<double>(0, (s, w) => s + w.reservedForSavings);
    final linked = state.budgetSetup.linkedWallets
        .map(
          (j) => j.id == 'linked-savings-default'
              ? LinkedWalletEntity(
                  id: j.id,
                  name: j.name,
                  balance: totalReserved,
                  monthlyAmount: j.monthlyAmount,
                  executionDay: j.executionDay,
                  fundingSource: j.fundingSource,
                  funding: j.funding,
                  icon: j.icon,
                  iconColor: j.iconColor,
                  automationType: j.automationType,
                  categories: j.categories,
                )
              : j,
        )
        .toList();

    final next = state.copyWith(
      wallets: walletList,
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: linked),
    );
    final label = action == 'allocate'
        ? 'تم تخصيص ${amount.toStringAsFixed(2)} للتوفير من ${wallet.name}'
        : action == 'cancel'
            ? 'تم إلغاء تخصيص ${amount.toStringAsFixed(2)} من ${wallet.name}'
            : 'تم صرف ${amount.toStringAsFixed(2)} من التخصيص في ${wallet.name}';
    await _applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: wallet.id,
      details: label,
      apply: () async => next,
    );
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(state.budgetSetup.copyWith(
        linkedWallets: [...state.budgetSetup.linkedWallets, linkedWallet]));
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .map((item) => item.id == linkedWallet.id ? linkedWallet : item)
            .toList(),
      ),
    );
  }

  Future<void> deleteLinkedWallet(String id) async {
    if (id == 'linked-savings-default') {
      return;
    }
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .where((wallet) => wallet.id != id)
            .toList(),
      ),
    );
  }

  Future<void> setCategories(List<CategoryEntity> categories) async {
    final next = state.copyWith(categories: categories);
    await _applyAndLog(
      action: 'edit',
      entityType: 'category',
      entityId: 'categories',
      details: 'تم تحديث الفئات',
      apply: () async => next,
    );
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    final allocations = state.budgetSetup.allocations
        .map((item) => item.id == allocationId
            ? AllocationEntity(
                id: item.id,
                name: item.name,
                icon: item.icon,
                iconColor: item.iconColor,
                rolloverBehavior: item.rolloverBehavior,
                funding: item.funding,
                categories: categories,
              )
            : item)
        .toList();
    await updateBudgetSetup(
        state.budgetSetup.copyWith(allocations: allocations));
  }

  Future<void> updateLinkedWalletCategories({
    required String linkedWalletId,
    required List<CategoryEntity> categories,
  }) async {
    final linkedWallets = state.budgetSetup.linkedWallets
        .map((item) => item.id == linkedWalletId
            ? LinkedWalletEntity(
                id: item.id,
                name: item.name,
                balance: item.balance,
                monthlyAmount: item.monthlyAmount,
                executionDay: item.executionDay,
                fundingSource: item.fundingSource,
                funding: item.funding,
                icon: item.icon,
                iconColor: item.iconColor,
                automationType: item.automationType,
                categories: categories,
              )
            : item)
        .toList();
    await updateBudgetSetup(
        state.budgetSetup.copyWith(linkedWallets: linkedWallets));
  }

  Future<void> updateSettings({
    String? userName,
    String? currencyCode,
    bool? notificationsEnabled,
    String? googleEmail,
    String? backupDirectoryPath,
    String? autoBackupMode,
    String? profileImageUrl,
  }) async {
    final next = state.copyWith(
      userName: userName,
      currencyCode: currencyCode,
      notificationsEnabled: notificationsEnabled,
      googleEmail: googleEmail,
      backupDirectoryPath: backupDirectoryPath,
      autoBackupMode: autoBackupMode,
      profileImageUrl: profileImageUrl,
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'settings',
      entityId: 'app-settings',
      details: 'تم تعديل إعدادات التطبيق',
      apply: () async => next,
    );
  }

  Future<void> updateAutoBackupTimestamp(DateTime at) async {
    final next = state.copyWith(lastAutoBackupAt: at.toIso8601String());
    await _repository.saveState(next);
    emit(next);
  }

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
    String? notes,
  }) async {
    final recurring = RecurringTransactionEntity(
      id: id ?? _id('rec'),
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
      notes: notes,
    );

    // زامن DebtEntity في budget.debts عند إضافة اشتراك/دين من خارج شاشة الميزانية
    final alreadyLinked = state.budgetSetup.debts
        .any((d) => d.recurringTransactionId == recurring.id);
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
              recurrencePattern: recurring.recurrencePattern,
              monthOfYear: recurring.monthOfYear,
            ),
          ])
        : state.budgetSetup;

    final next = state.copyWith(
      recurringTransactions: [...state.recurringTransactions, recurring],
      budgetSetup: nextBudget,
    );
    await _applyAndLog(
      action: 'add',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: _recurringTransactionDetails('إضافة معاملة متكررة', recurring),
      apply: () async => next,
    );
  }

  Future<void> updateRecurringTransaction(
      RecurringTransactionEntity recurring) async {
    // زامن DebtEntity المرتبط لو كان دين/اشتراك
    BudgetSetupEntity nextBudget = state.budgetSetup;
    if (recurring.isDebtOrSubscription) {
      final linkedIndex = state.budgetSetup.debts
          .indexWhere((d) => d.recurringTransactionId == recurring.id);
      if (linkedIndex >= 0) {
        final existing = state.budgetSetup.debts[linkedIndex];
        final updated = existing.copyWith(
          name: recurring.name,
          amount: recurring.amount,
          executionDay: recurring.dayOfMonth.clamp(1, 28),
          type: recurring.executionType,
          kind: recurring.expensePlanKind == 'installment'
              ? 'installment'
              : 'subscription',
          principalTotal: recurring.debtPrincipalTotal,
          recurrencePattern: recurring.recurrencePattern,
          monthOfYear: recurring.monthOfYear,
        );
        final updatedDebts = List<DebtEntity>.from(state.budgetSetup.debts)
          ..[linkedIndex] = updated;
        nextBudget = state.budgetSetup.copyWith(debts: updatedDebts);
      }
    }
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((item) => item.id == recurring.id ? recurring : item)
          .toList(),
      budgetSetup: nextBudget,
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: _recurringTransactionDetails('تعديل معاملة متكررة', recurring),
      apply: () async => next,
    );
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final target =
        state.recurringTransactions.where((item) => item.id == id).toList();
    final deleted = target.isEmpty ? null : target.first;

    // احذف DebtEntity المرتبط لو وُجد
    final nextBudget = state.budgetSetup.copyWith(
      debts: state.budgetSetup.debts
          .where((d) => d.recurringTransactionId != id)
          .toList(),
    );

    final next = state.copyWith(
      recurringTransactions:
          state.recurringTransactions.where((item) => item.id != id).toList(),
      budgetSetup: nextBudget,
    );
    await _applyAndLog(
      action: 'delete',
      entityType: 'recurring-transaction',
      entityId: id,
      details: deleted == null
          ? 'تم حذف معاملة متكررة'
          : _recurringTransactionDetails('حذف معاملة متكررة', deleted),
      apply: () async => next,
    );
  }

  String _transactionTypeLabel(String type) {
    return switch (type) {
      'income' => 'دخل',
      'expense' => 'مصروف',
      'transfer' => 'تحويل',
      _ => type,
    };
  }

  String _executionTypeLabel(String type) {
    return switch (type) {
      'auto' => 'تلقائي',
      'confirm' => 'يحتاج تأكيد',
      'manual' => 'يدوي',
      _ => type,
    };
  }

  String _budgetScopeLabel(String scope) {
    return scope == 'within-budget' ? 'داخل الميزانية' : 'خارج الميزانية';
  }

  String _recurrenceLabel(String pattern) {
    return switch (pattern) {
      'daily' => 'يومي',
      'weekly' => 'أسبوعي',
      'biweekly' => 'كل أسبوعين',
      'every_3_weeks' => 'كل 3 أسابيع',
      'monthly' => 'شهري',
      'every_2_months' => 'كل شهرين',
      'every_3_months' => 'كل 3 شهور',
      'every_6_months' => 'كل 6 شهور',
      'yearly' => 'سنوي',
      'manual-variable' => 'يدوي متغير',
      _ => pattern,
    };
  }

  String _recurringTransactionDetails(
    String action,
    RecurringTransactionEntity recurring,
  ) {
    final type = _transactionTypeLabel(recurring.type);
    final amount = recurring.isVariableIncome
        ? 'دخل متغير'
        : recurring.amount.toStringAsFixed(2);
    final debtLabel = recurring.isDebtOrSubscription
        ? recurring.expensePlanKind == 'installment'
            ? ' · تقسيط'
            : recurring.expensePlanKind == 'subscription'
                ? ' · اشتراك'
                : ' · دين أو اشتراك'
        : '';
    return '$action: ${recurring.name} · النوع: $type · القيمة: $amount · التكرار: ${_recurrenceLabel(recurring.recurrencePattern)} · التنفيذ: ${_executionTypeLabel(recurring.executionType)} · ${_budgetScopeLabel(recurring.budgetScope)}$debtLabel';
  }

  Future<void> ensureDefaultSavingsJar() async {
    final defaultIndex = state.budgetSetup.linkedWallets
        .indexWhere((w) => w.id == 'linked-savings-default');
    if (defaultIndex != -1) {
      final current = state.budgetSetup.linkedWallets[defaultIndex];
      if (current.name != 'التوفير') {
        final linkedWallets =
            List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
        linkedWallets[defaultIndex] = LinkedWalletEntity(
          id: current.id,
          name: 'التوفير',
          balance: current.balance,
          monthlyAmount: current.monthlyAmount,
          executionDay: current.executionDay,
          fundingSource: current.fundingSource,
          funding: current.funding,
          icon: current.icon,
          iconColor: current.iconColor,
          automationType: current.automationType,
          categories: current.categories,
        );
        final next = state.copyWith(
          budgetSetup: state.budgetSetup.copyWith(linkedWallets: linkedWallets),
        );
        await _repository.saveState(next);
        emit(next);
      }
      return;
    }
    final fallbackIncomeId = state.budgetSetup.incomeSources.isNotEmpty
        ? state.budgetSetup.incomeSources.first.id
        : '';
    final defaultJar = LinkedWalletEntity(
      id: 'linked-savings-default',
      name: 'التوفير',
      balance: 0,
      monthlyAmount: 0,
      executionDay: 1,
      fundingSource: fallbackIncomeId,
      funding: fallbackIncomeId.isEmpty
          ? const []
          : [
              LinkedWalletEntityFunding(
                id: _id('fund-linked'),
                incomeSourceId: fallbackIncomeId,
                plannedAmount: 0,
              ),
            ],
      icon: 'savings',
      iconColor: '#0f766e',
      automationType: 'confirm',
      categories: const [],
    );
    final nextSetup = state.budgetSetup.copyWith(
      linkedWallets: [...state.budgetSetup.linkedWallets, defaultJar],
    );
    await _applyAndLog(
      action: 'add',
      entityType: 'linked-wallet',
      entityId: defaultJar.id,
      details: 'تم إنشاء حصالة التوفير الافتراضية',
      apply: () async => state.copyWith(budgetSetup: nextSetup),
    );
  }

  Future<void> syncSavingsJarWithReserved() async {
    final totalReserved =
        state.wallets.fold<double>(0, (sum, w) => sum + w.reservedForSavings);
    final idx = state.budgetSetup.linkedWallets
        .indexWhere((w) => w.id == 'linked-savings-default');
    if (idx == -1) return;
    final current = state.budgetSetup.linkedWallets[idx];
    if ((current.balance - totalReserved).abs() < 0.0001) {
      return;
    }
    final linked =
        List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
    linked[idx] = LinkedWalletEntity(
      id: current.id,
      name: current.name,
      balance: totalReserved,
      monthlyAmount: current.monthlyAmount,
      executionDay: current.executionDay,
      fundingSource: current.fundingSource,
      funding: current.funding,
      icon: current.icon,
      iconColor: current.iconColor,
      automationType: current.automationType,
      categories: current.categories,
    );
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: linked),
    );
    await _repository.saveState(next);
    emit(next);
  }

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    String icon = 'savings',
    String iconColor = '#2f6f5e',
    String? notes,
  }) async {
    final goal = GoalEntity(
      id: _id('goal'),
      name: name,
      targetAmount: targetAmount,
      startDate: startDate,
      endDate: endDate,
      icon: icon,
      iconColor: iconColor,
      notes: notes,
    );
    final next = state.copyWith(goals: [...state.goals, goal]);
    await _applyAndLog(
      action: 'add',
      entityType: 'goal',
      entityId: goal.id,
      details: 'تمت إضافة هدف: $name',
      apply: () async => next,
    );
  }

  Future<void> updateGoal(GoalEntity goal) async {
    final next = state.copyWith(
      goals:
          state.goals.map((item) => item.id == goal.id ? goal : item).toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'goal',
      entityId: goal.id,
      details: 'تم تعديل هدف',
      apply: () async => next,
    );
  }

  Future<void> deleteGoal(String id) async {
    final next = state.copyWith(
        goals: state.goals.where((item) => item.id != id).toList());
    await _applyAndLog(
      action: 'delete',
      entityType: 'goal',
      entityId: id,
      details: 'تم حذف هدف',
      apply: () async => next,
    );
  }

  String exportStateJson() => jsonEncode(state.toMap());

  Future<void> importStateJson(String jsonString) async {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final next = AppStateEntity.fromMap(map);
    await _applyAndLog(
      action: 'import',
      entityType: 'backup',
      entityId: 'import',
      details: 'تم استيراد نسخة احتياطية',
      apply: () async => next,
    );
  }

  Future<void> resetAllData() async {
    final next = AppStateEntity.initial();
    await _applyAndLog(
      action: 'delete',
      entityType: 'all-data',
      entityId: 'reset',
      details: 'تم حذف كل بيانات التطبيق',
      apply: () async => next,
    );
  }

  Future<void> toggleLogRevert(String logId) async {
    final target = state.logs.where((log) => log.id == logId).toList();
    if (target.isEmpty) return;
    final log = target.first;

    final updatedLogs = state.logs
        .map((item) => item.id == logId
            ? item.copyWith(
                isReverted: !item.isReverted,
                revertedAt: item.isReverted ? null : DateTime.now())
            : item)
        .toList();

    final restored = _restoreFromCore(
        log.isReverted ? log.afterState : log.beforeState, updatedLogs);
    final revertLog = LogEntryEntity(
      id: _id('log'),
      action: 'revert',
      entityType: log.entityType,
      entityId: log.entityId,
      details: log.isReverted
          ? 'تم التراجع عن التراجع'
          : 'تم التراجع عن العملية الأصلية',
      timestamp: DateTime.now(),
      beforeState: jsonEncode(_coreMap(state.copyWith(logs: updatedLogs))),
      afterState: jsonEncode(_coreMap(restored)),
      isReverted: false,
    );
    final revertNotification = NotificationEntity(
      id: _id('notif'),
      title: 'إشعار التراجع',
      message: revertLog.details,
      createdAt: DateTime.now(),
      type: 'revert',
      relatedLogId: revertLog.id,
    );
    final next = restored.copyWith(
      logs: [revertLog, ...updatedLogs].take(600).toList(),
      notifications:
          [revertNotification, ...state.notifications].take(800).toList(),
    );
    await _repository.saveState(next);
    emit(next);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final updated = state.notifications
        .map((n) => n.id == notificationId && !n.isRead
            ? n.copyWith(readAt: DateTime.now())
            : n)
        .toList();
    final next = state.copyWith(notifications: updated);
    await _repository.saveState(next);
    emit(next);
  }
}
