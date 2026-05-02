import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/screens/recurring_transaction_composer_screen.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../domain/entities/log_entry_entity.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _tab = 'all';
  String _range = 'all';
  final Set<String> _entityTypes = <String>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final logs = _filtered(state.logs);
        return Scaffold(
          appBar: AppBar(
            title: const Text('السجلات'),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_alt_outlined),
                onPressed: _openFilters,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _tabChip('all', 'الكل'),
                      _tabChip('transaction', 'المعاملات'),
                      _tabChip('recurring', 'المتكررة'),
                      _tabChip('edit', 'تعديل'),
                      _tabChip('delete', 'حذف'),
                      _tabChip('transfer', 'تحويل'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text('لا توجد سجلات مطابقة للفلاتر الحالية.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final rows = _detailRowsForLog(state, log);
                          return _LogSummaryCard(
                            log: log,
                            title: _pretty(log),
                            actionName: _actionName(log.action),
                            entityName: _entityTypeName(log.entityType),
                            timestamp: _fmt(log.timestamp),
                            amount: rows['القيمة'] ?? rows['المبلغ'],
                            onTap: () => _openDetails(state, log),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabChip(String id, String label) {
    final selected = _tab == id;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _tab = id),
      ),
    );
  }

  List<LogEntryEntity> _filtered(List<LogEntryEntity> logs) {
    final now = DateTime.now();
    var filtered = logs.where((log) {
      if (_range == 'day') return now.difference(log.timestamp).inHours <= 24;
      if (_range == 'week') return now.difference(log.timestamp).inDays <= 7;
      if (_range == 'month') return now.difference(log.timestamp).inDays <= 30;
      return true;
    });
    if (_tab == 'transaction') {
      filtered = filtered.where((log) => log.entityType == 'transaction');
    } else if (_tab == 'recurring') {
      filtered =
          filtered.where((log) => log.entityType == 'recurring-transaction');
    } else if (_tab == 'edit') {
      filtered = filtered.where((log) => log.action == 'edit');
    } else if (_tab == 'delete') {
      filtered = filtered.where((log) => log.action == 'delete');
    } else if (_tab == 'transfer') {
      filtered = filtered.where((log) => log.action == 'transfer');
    }
    if (_entityTypes.isNotEmpty) {
      filtered = filtered.where((log) => _entityTypes.contains(log.entityType));
    }
    return filtered.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void _openFilters() {
    final selected = Set<String>.from(_entityTypes);
    String range = _range;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'فلترة السجلات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: range,
                decoration: const InputDecoration(labelText: 'المدى الزمني'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'day', child: Text('آخر يوم')),
                  DropdownMenuItem(value: 'week', child: Text('آخر أسبوع')),
                  DropdownMenuItem(value: 'month', child: Text('آخر شهر')),
                ],
                onChanged: (value) {
                  if (value != null) setSheet(() => range = value);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const [
                  'transaction',
                  'recurring-transaction',
                  'wallet',
                  'budget',
                  'settings',
                  'goal',
                ]
                    .map(
                      (type) => FilterChip(
                        label: Text(type),
                        selected: selected.contains(type),
                        onSelected: (on) {
                          setSheet(() {
                            if (on) {
                              selected.add(type);
                            } else {
                              selected.remove(type);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _range = range;
                    _entityTypes
                      ..clear()
                      ..addAll(selected);
                  });
                  Navigator.pop(context);
                },
                child: const Text('تطبيق الفلتر'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(AppStateEntity state, LogEntryEntity log) async {
    final rows = _detailRowsForLog(state, log);
    final transaction = _currentTransaction(state, log.entityId);
    final recurring = _currentRecurring(state, log.entityId);
    final canEditTransaction =
        log.entityType == 'transaction' && transaction != null;
    final canDeleteTransaction =
        log.entityType == 'transaction' && transaction != null;
    final canEditRecurring =
        log.entityType == 'recurring-transaction' && recurring != null;
    final canDeleteRecurring =
        log.entityType == 'recurring-transaction' && recurring != null;
    final canUndoDelete = log.action == 'delete' && !log.isReverted;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.82,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _pretty(log),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _DetailsTable(
              rows: {
                'نوع السجل': _actionName(log.action),
                'العنصر': _entityTypeName(log.entityType),
                'وقت التسجيل': _fmt(log.timestamp),
                if (log.revertedAt != null) 'وقت التراجع': _fmt(log.revertedAt!),
                ...rows,
              },
            ),
            const SizedBox(height: 14),
            if (canEditTransaction)
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await openTransactionDetailsSheet(
                    context,
                    cubit: widget.cubit,
                    transaction: transaction,
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل المعاملة'),
              ),
            if (canEditRecurring)
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => RecurringTransactionComposerScreen(
                        cubit: widget.cubit,
                        initialRecurring: recurring,
                        initialType: recurring.type,
                        initialWithinBudget:
                            recurring.budgetScope == 'within-budget',
                        allowDelete: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل المعاملة المتكررة'),
              ),
            if (canDeleteTransaction || canDeleteRecurring) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  if (canDeleteTransaction) {
                    await widget.cubit.deleteTransaction(log.entityId);
                  } else {
                    await widget.cubit.deleteRecurringTransaction(log.entityId);
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  canDeleteTransaction
                      ? 'حذف المعاملة'
                      : 'حذف المعاملة المتكررة',
                ),
              ),
            ],
            if (canUndoDelete) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.cubit.toggleLogRevert(log.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('تراجع عن الحذف'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, String> _detailRowsForLog(
    AppStateEntity currentState,
    LogEntryEntity log,
  ) {
    if (log.entityType == 'transaction') {
      final tx = _transactionForLog(currentState, log);
      if (tx == null) return {'الوصف': _pretty(log)};
      return _transactionRows(currentState, tx);
    }
    if (log.entityType == 'recurring-transaction') {
      final recurring = _recurringForLog(currentState, log);
      if (recurring == null) return {'الوصف': _pretty(log)};
      return _recurringRows(currentState, recurring);
    }
    return {'الوصف': _pretty(log)};
  }

  TransactionEntity? _transactionForLog(
    AppStateEntity currentState,
    LogEntryEntity log,
  ) {
    return _currentTransaction(currentState, log.entityId) ??
        _snapshotForLog(log, preferBefore: log.action == 'delete')
            ?.transactions
            .where((item) => item.id == log.entityId)
            .cast<TransactionEntity?>()
            .firstWhere((item) => item != null, orElse: () => null);
  }

  RecurringTransactionEntity? _recurringForLog(
    AppStateEntity currentState,
    LogEntryEntity log,
  ) {
    return _currentRecurring(currentState, log.entityId) ??
        _snapshotForLog(log, preferBefore: log.action == 'delete')
            ?.recurringTransactions
            .where((item) => item.id == log.entityId)
            .cast<RecurringTransactionEntity?>()
            .firstWhere((item) => item != null, orElse: () => null);
  }

  AppStateEntity? _snapshotForLog(
    LogEntryEntity log, {
    required bool preferBefore,
  }) {
    final raw = preferBefore ? log.beforeState : log.afterState;
    try {
      return AppStateEntity.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  TransactionEntity? _currentTransaction(AppStateEntity state, String id) {
    final items = state.transactions.where((item) => item.id == id).toList();
    return items.isEmpty ? null : items.first;
  }

  RecurringTransactionEntity? _currentRecurring(AppStateEntity state, String id) {
    final items =
        state.recurringTransactions.where((item) => item.id == id).toList();
    return items.isEmpty ? null : items.first;
  }

  Map<String, String> _transactionRows(AppStateEntity state, TransactionEntity tx) {
    return {
      'نوع العملية': _transactionTypeName(tx.type),
      'القيمة': tx.amount.toStringAsFixed(2),
      'التاريخ': DateFormat('yyyy/MM/dd', 'ar').format(tx.createdAt),
      'الوقت': DateFormat('HH:mm', 'ar').format(tx.createdAt),
      if (tx.walletId != null) 'المحفظة': _walletName(state, tx.walletId),
      if (tx.fromWalletId != null) 'من محفظة': _walletName(state, tx.fromWalletId),
      if (tx.toWalletId != null) 'إلى': _walletOrJarName(state, tx.toWalletId),
      if (tx.incomeSourceId != null) 'مصدر الدخل': _incomeName(state, tx.incomeSourceId),
      if (tx.allocationId != null) 'المخصص': _allocationName(state, tx.allocationId),
      if (tx.categoryId != null) 'الفئة': _categoryName(state, tx.categoryId),
      if (tx.budgetScope != null) 'النطاق': _budgetScopeName(tx.budgetScope!),
      if (tx.notes?.isNotEmpty == true) 'الملاحظات': tx.notes!,
    };
  }

  Map<String, String> _recurringRows(
    AppStateEntity state,
    RecurringTransactionEntity recurring,
  ) {
    return {
      'اسم العملية': recurring.name,
      'نوع العملية': _transactionTypeName(recurring.type),
      'القيمة': recurring.isVariableIncome
          ? 'دخل متغير'
          : recurring.amount.toStringAsFixed(2),
      'المحفظة': _walletName(state, recurring.walletId),
      'النطاق': _budgetScopeName(recurring.budgetScope),
      'التكرار': _recurrenceName(recurring.recurrencePattern),
      'التنفيذ': _executionName(recurring.executionType),
      'يوم الشهر': recurring.dayOfMonth.toString(),
      if (recurring.scheduledTime?.isNotEmpty == true) 'الوقت': recurring.scheduledTime!,
      if (recurring.isDebtOrSubscription) 'التصنيف': 'دين أو اشتراك',
      if (recurring.incomeSourceId != null)
        'مصدر الدخل': _incomeName(state, recurring.incomeSourceId),
      if (recurring.allocationId != null)
        'المخصص': _allocationName(state, recurring.allocationId),
      if (recurring.targetJarId != null)
        'الحصالة': _walletOrJarName(state, recurring.targetJarId),
      if (recurring.notes?.isNotEmpty == true) 'الملاحظات': recurring.notes!,
    };
  }

  String _pretty(LogEntryEntity log) {
    if (log.details.trim().isNotEmpty) return log.details.trim();
    return '${_actionName(log.action)} على ${_entityTypeName(log.entityType)}';
  }

  String _actionName(String action) {
    return switch (action) {
      'add' => 'إضافة',
      'edit' => 'تعديل',
      'delete' => 'حذف',
      'transfer' => 'تحويل',
      'revert' => 'تراجع',
      'import' => 'استيراد',
      _ => action,
    };
  }

  String _entityTypeName(String entityType) {
    return switch (entityType) {
      'transaction' => 'معاملة',
      'recurring-transaction' => 'معاملة متكررة',
      'wallet' => 'محفظة',
      'budget' => 'ميزانية',
      'linked-wallet' => 'حصالة',
      'category' => 'فئة',
      'settings' => 'إعدادات',
      'goal' => 'هدف',
      _ => entityType,
    };
  }

  String _transactionTypeName(String type) {
    return switch (type) {
      'income' => 'دخل',
      'expense' => 'مصروف',
      'transfer' => 'تحويل',
      _ => type,
    };
  }

  String _budgetScopeName(String scope) {
    return scope == 'within-budget' ? 'داخل الميزانية' : 'خارج الميزانية';
  }

  String _executionName(String type) {
    return switch (type) {
      'auto' => 'تلقائي',
      'confirm' => 'يحتاج تأكيد',
      'manual' => 'يدوي',
      _ => type,
    };
  }

  String _recurrenceName(String pattern) {
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

  String _walletName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final wallets = state.wallets.where((item) => item.id == id).toList();
    return wallets.isEmpty ? id : wallets.first.name;
  }

  String _walletOrJarName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final wallets = state.wallets.where((item) => item.id == id).toList();
    if (wallets.isNotEmpty) return wallets.first.name;
    final jars = state.budgetSetup.linkedWallets.where((item) => item.id == id).toList();
    return jars.isEmpty ? id : jars.first.name;
  }

  String _incomeName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items = state.budgetSetup.incomeSources.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _allocationName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items = state.budgetSetup.allocations.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _categoryName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items = state.categories.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _fmt(DateTime date) => DateFormat('yyyy/MM/dd HH:mm', 'ar').format(date);
}

class _LogSummaryCard extends StatelessWidget {
  const _LogSummaryCard({
    required this.log,
    required this.title,
    required this.actionName,
    required this.entityName,
    required this.timestamp,
    required this.onTap,
    this.amount,
  });

  final LogEntryEntity log;
  final String title;
  final String actionName;
  final String entityName;
  final String timestamp;
  final String? amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = log.action == 'delete'
        ? const Color(0xFFC65D2E)
        : const Color(0xFF2F6F5E);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_iconForAction(log.action), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$actionName - $entityName - $timestamp',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (amount != null) ...[
                const SizedBox(width: 8),
                Text(
                  amount!,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForAction(String action) {
    return switch (action) {
      'delete' => Icons.delete_outline_rounded,
      'edit' => Icons.edit_outlined,
      'transfer' => Icons.swap_horiz_rounded,
      _ => Icons.receipt_long_rounded,
    };
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = rows.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: entries.map((entry) {
          final isLast = identical(entry, entries.last);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
