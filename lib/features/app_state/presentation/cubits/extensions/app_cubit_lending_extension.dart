import '../../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../../transactions/domain/entities/transaction_entity.dart';
import '../app_cubit.dart';

extension AppCubitLendingExtension on AppCubit {
  Future<void> addLentRecord({
    required String personName,
    required double amount,
    required String walletId,
    required DateTime expectedReturnDate,
    DateTime? lentDate,
    bool isMonthlyInstallments = false,
    String? existingPersonId,
    String? notes,
  }) async {
    final effectiveLentDate = lentDate ?? DateTime.now();
    final walletName = state.wallets
        .where((wallet) => wallet.id == walletId)
        .map((wallet) => wallet.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    final entryId = generateId('lent-entry');
    final newEntry = <String, dynamic>{
      'id': entryId,
      'amount': amount,
      'lentDate': effectiveLentDate.toIso8601String(),
      'expectedReturnDate': expectedReturnDate.toIso8601String(),
      'notes': notes,
      'isSettled': false,
    };

    final transaction = TransactionEntity(
      id: generateId('txn'),
      walletId: walletId,
      amount: amount,
      type: 'expense',
      notes: '???? ?? $personName',
      createdAt: effectiveLentDate,
    );

    List<RecurringTransactionEntity> updatedList;
    String personId;

    final existing = existingPersonId != null
        ? state.recurringTransactions
            .where((item) => item.id == existingPersonId)
            .cast<RecurringTransactionEntity?>()
            .firstWhere((_) => true, orElse: () => null)
        : null;

    if (existing != null) {
      personId = existing.id;
      final updatedPerson = existing.copyWith(
        walletId: walletId,
        lentEntries: [...existing.lentEntries, newEntry],
        isLentArchived: false,
        amount: existing.outstandingLentAmount + amount,
      );
      updatedList = state.recurringTransactions
          .map((item) => item.id == personId ? updatedPerson : item)
          .toList();
    } else {
      personId = generateId('rec');
      final person = RecurringTransactionEntity(
        id: personId,
        name: personName,
        type: 'expense',
        amount: amount,
        dayOfMonth: 1,
        executionType: 'confirm',
        walletId: walletId,
        budgetScope: 'outside-budget',
        recurrencePattern: 'manual-variable',
        icon: 'handshake',
        iconColor: '#1a7a4a',
        isLent: true,
        lentPersonName: personName,
        lentEntries: [newEntry],
      );
      updatedList = [...state.recurringTransactions, person];
    }

    await applyAndLog(
      action: 'add',
      entityType: 'lent-record',
      entityId: personId,
      details:
          '???? ?? $personName ????? ${amount.toStringAsFixed(2)} ?? ${walletName ?? walletId}',
      titleOverride: personName,
      apply: () async {
        final stateAfterTx = await repository.addTransaction(transaction);
        return stateAfterTx.copyWith(recurringTransactions: updatedList);
      },
    );
  }

  Future<void> settleLentEntry(String personId, String entryId) async {
    final person = state.recurringTransactions
        .where((item) => item.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;

    final entry = person.lentEntries
        .where((item) => item['id'] == entryId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);
    if (entry == null) return;

    final entryAmount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final updatedEntries = person.lentEntries
        .map((item) =>
            item['id'] == entryId ? {...item, 'isSettled': true} : item)
        .toList();
    final allSettled =
        updatedEntries.every((item) => item['isSettled'] == true);
    final updatedPerson = person.copyWith(
      lentEntries: updatedEntries,
      amount: (person.outstandingLentAmount - entryAmount)
          .clamp(0, double.infinity),
      isLentArchived: allSettled,
    );

    final transaction = TransactionEntity(
      id: generateId('txn'),
      walletId: person.walletId,
      amount: entryAmount,
      type: 'income',
      notes: '??????? ???? ?? ${person.lentPersonName ?? person.name}',
      createdAt: DateTime.now(),
    );

    final updatedList = state.recurringTransactions
        .map((item) => item.id == personId ? updatedPerson : item)
        .toList();

    await applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          '??????? ???? ?? ${person.lentPersonName ?? person.name} ????? ${entryAmount.toStringAsFixed(2)}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async {
        final stateAfterTx = await repository.addTransaction(transaction);
        return stateAfterTx.copyWith(recurringTransactions: updatedList);
      },
    );
  }

  Future<void> writeOffLentEntry(String personId, String entryId) async {
    final person = state.recurringTransactions
        .where((item) => item.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;

    final entryAmount = (person.lentEntries
                .where((item) => item['id'] == entryId)
                .cast<Map<String, dynamic>?>()
                .firstWhere((_) => true, orElse: () => null)?['amount'] as num?)
            ?.toDouble() ??
        0;

    final updatedEntries = person.lentEntries
        .map((item) =>
            item['id'] == entryId ? {...item, 'isSettled': true} : item)
        .toList();
    final allSettled =
        updatedEntries.every((item) => item['isSettled'] == true);
    final updatedPerson = person.copyWith(
      lentEntries: updatedEntries,
      amount: (person.outstandingLentAmount - entryAmount)
          .clamp(0, double.infinity),
      isLentArchived: allSettled,
    );
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((item) => item.id == personId ? updatedPerson : item)
          .toList(),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          '????? ?? ???? ${person.lentPersonName ?? person.name} ????? ${entryAmount.toStringAsFixed(2)}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  Future<void> postponeLentEntry(
    String personId,
    String entryId,
    DateTime newDate,
  ) async {
    final person = state.recurringTransactions
        .where((item) => item.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final updatedEntries = person.lentEntries
        .map((item) => item['id'] == entryId
            ? {...item, 'expectedReturnDate': newDate.toIso8601String()}
            : item)
        .toList();
    final updatedPerson = person.copyWith(lentEntries: updatedEntries);
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((item) => item.id == personId ? updatedPerson : item)
          .toList(),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          '????? ???? ${person.lentPersonName ?? person.name} ??? ${newDate.day}/${newDate.month}/${newDate.year}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  Future<void> archiveLentPerson(String personId, {bool archive = true}) async {
    final person = state.recurringTransactions
        .where((item) => item.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final updated = person.copyWith(isLentArchived: archive);
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((item) => item.id == personId ? updated : item)
          .toList(),
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details: archive
          ? '????? ${person.lentPersonName ?? person.name}'
          : '????? ????? ${person.lentPersonName ?? person.name}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  Future<void> settleLentRecord(String id) async {}
  Future<void> writeOffLentRecord(String id) async {}
  Future<void> postponeLentRecord(String id, DateTime date) async {}
}
