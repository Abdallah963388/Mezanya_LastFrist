import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../budget/domain/services/budget_recurring_plan_service.dart';
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';
import '../../domain/entities/notification_entity.dart';
import '../widgets/notification_center_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedTab = 'new';
  bool _showingRecurringDecisionDialog = false;
  final Set<String> _dismissedRecurringPromptKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        _scheduleRecurringDecisionPrompt(state);
        final pendingCards = _pendingNotificationCards(state);
        final historyItems = _historyNotifications(state);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NotificationsTabSelector(
              selectedTab: _selectedTab,
              pendingCount: pendingCards.length,
              historyCount: historyItems.length,
              onTabChanged: (value) => setState(() => _selectedTab = value),
            ),
            const SizedBox(height: 12),
            if (_selectedTab == 'new') ...[
              if (pendingCards.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('لا توجد إشعارات تحتاج إجراء الآن.'),
                  ),
                )
              else
                ...pendingCards,
            ] else ...[
              if (historyItems.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('سجل الإشعارات فارغ.'),
                  ),
                )
              else
                ...historyItems.map((item) => _buildHistoryTile(state, item)),
            ],
          ],
        );
      },
    );
  }

  void _scheduleRecurringDecisionPrompt(AppStateEntity state) {
    if (_showingRecurringDecisionDialog || !mounted) return;
    final decision = _nextRecurringDecision(state);
    if (decision == null) return;
    final key = _promptKey(decision.recurring, decision.prompt.occurrence);
    if (_dismissedRecurringPromptKeys.contains(key)) return;
    _showingRecurringDecisionDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showingRecurringDecisionDialog = false;
        return;
      }
      final action = await _showRecurringDecisionDialog(decision);
      if (!mounted) {
        _showingRecurringDecisionDialog = false;
        return;
      }
      if (action == null) {
        _dismissedRecurringPromptKeys.add(key);
      } else {
        await _handleRecurringDecisionAction(action, decision);
      }
      _showingRecurringDecisionDialog = false;
    });
  }

  List<Widget> _pendingNotificationCards(AppStateEntity state) {
    final cards = <Widget>[];
    final budget = state.budgetSetup;
    final now = DateTime.now();
    final month = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final cycleStart = budget.cycleStartFor(now);
    final cycleEnd = budget.cycleEndFor(now);
    final monthTransactions = state.transactions.where((transaction) {
      return transaction.createdAt.year == month.year &&
          transaction.createdAt.month == month.month;
    }).toList();
    final cycleTransactions = state.transactions.where((transaction) {
      return !transaction.createdAt.isBefore(cycleStart) &&
          !transaction.createdAt.isAfter(cycleEnd);
    }).toList();
    final incomeTransactions = monthTransactions
        .where((transaction) => transaction.type == 'income')
        .toList();

    for (final source in budget.incomeSources) {
      final sourceTransactions = incomeTransactions
          .where((transaction) => transaction.incomeSourceId == source.id)
          .toList();
      final pendingMeta = _incomePendingMeta(
        state,
        source,
        sourceTransactions,
        month,
      );
      if (pendingMeta == null) continue;

      cards.add(
        PendingNotificationCard(
          accent: pendingMeta.isDueOrLate
              ? const Color(0xFF0F9D7A)
              : const Color(0xFF4C8BF5),
          title: source.name,
          subtitle: pendingMeta.status,
          amount: source.amount,
          badge: pendingMeta.isDueOrLate ? 'مستحق الآن' : 'تنبيه مبكر',
          meta: _walletName(source.targetWalletId),
          icon: Icons.south_west_rounded,
          actions: [
            if (pendingMeta.canEarly)
              PendingNotificationAction(
                label: 'بكر',
                filled: false,
                onPressed: () => _recordIncome(source, early: true),
              ),
            if (pendingMeta.isDueOrLate)
              PendingNotificationAction(
                label: 'نزول',
                onPressed: () => _recordIncome(source),
              ),
            if (pendingMeta.isDueOrLate)
              PendingNotificationAction(
                label: 'تأجيل',
                filled: false,
                onPressed: () => _postponeIncome(source, month),
              ),
          ],
        ),
      );
    }

    for (final debt in budget.debts) {
      final recurring = _linkedRecurringDebt(state, debt);
      final pendingMeta = _expensePendingMeta(recurring);
      if (pendingMeta == null || !pendingMeta.pending) {
        continue;
      }
      final paidAmount = cycleTransactions
          .where(
              (transaction) => transaction.notes?.contains(debt.name) == true)
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
      final decisionAmount = BudgetRecurringPlanService.pendingDecisionAmount(
        debt: debt,
        recurring: recurring,
        cyclePaid: paidAmount,
      );
      if (decisionAmount <= 0) {
        continue;
      }

      cards.add(
        PendingNotificationCard(
          accent: const Color(0xFFC65D2E),
          title: debt.name,
          subtitle: pendingMeta.status,
          amount: decisionAmount,
          badge: 'دين أو اشتراك',
          meta: _walletName(recurring?.walletId ?? ''),
          icon: Icons.credit_card_rounded,
          actions: [
            PendingNotificationAction(
              label: 'نزول',
              onPressed: recurring == null
                  ? () {}
                  : () => _recordDebt(
                        debt,
                        recurring,
                        pendingMeta.occurrence,
                      ),
            ),
            PendingNotificationAction(
              label: 'تخطي المرة',
              filled: false,
              onPressed: recurring == null
                  ? () {}
                  : () => _skipRecurringExpenseOccurrence(
                        recurring,
                        pendingMeta.occurrence,
                      ),
            ),
          ],
        ),
      );
    }

    return cards;
  }

  List<NotificationEntity> _historyNotifications(AppStateEntity state) {
    final items = state.notifications.where((item) {
      if (item.relatedLogId == null) return false;
      final text = '${item.title} ${item.message}';
      return text.contains('دخل') ||
          text.contains('دين') ||
          text.contains('اشتراك') ||
          text.contains('تأجيل') ||
          text.contains('تراجع');
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Widget _buildHistoryTile(AppStateEntity state, NotificationEntity item) {
    final relatedLog =
        state.logs.where((log) => log.id == item.relatedLogId).toList();
    final log = relatedLog.isEmpty ? null : relatedLog.first;

    return NotificationHistoryCard(
      title: _historyTitle(item),
      timeLabel: DateFormat('d/M HH:mm', 'ar').format(item.createdAt),
      amountLabel: _historyAmount(item, log),
      accent: _historyAccent(item),
      icon: _historyIcon(item),
      onOpen: () => _openHistorySheet(item, log),
    );
  }

  Future<void> _openHistorySheet(
    NotificationEntity item,
    LogEntryEntity? log,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(item.message),
            const SizedBox(height: 16),
            ..._detailsRows(item, log).map(
              (row) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        row.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        row.value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (log != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.cubit.toggleLogRevert(log.id);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: Icon(
                  log.isReverted ? Icons.redo_rounded : Icons.undo_rounded,
                ),
                label: Text(
                  log.isReverted ? 'إلغاء التراجع' : 'التراجع عن الإجراء',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  RecurringTransactionEntity? _linkedRecurringIncome(
    AppStateEntity state,
    IncomeSourceEntity source,
  ) {
    final linked = state.recurringTransactions.where(
      (item) =>
          item.type == 'income' &&
          item.budgetScope == 'within-budget' &&
          (item.incomeSourceId == source.id ||
              ((item.incomeSourceId ?? '').isEmpty &&
                  item.name == source.name &&
                  item.walletId == source.targetWalletId)),
    );
    return linked.isEmpty ? null : linked.first;
  }

  _IncomePendingMeta? _incomePendingMeta(
    AppStateEntity state,
    IncomeSourceEntity source,
    List<TransactionEntity> sourceTransactions,
    DateTime month,
  ) {
    if (source.isVariable || sourceTransactions.isNotEmpty) {
      return null;
    }

    final recurring = _linkedRecurringIncome(state, source);
    final dueDate = _incomeDueDateForMonth(source, month);
    final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
    final canEarly = reminderLeadDays > 0 &&
        !today.isBefore(reminderDate) &&
        today.isBefore(dueDate);
    final isDueOrLate = !today.isBefore(dueDate);
    if (!canEarly && !isDueOrLate) return null;

    final dateLabel = '${dueDate.day}/${dueDate.month}';
    final timeLabel = recurring?.scheduledTime?.isNotEmpty == true
        ? recurring!.scheduledTime!
        : null;

    return _IncomePendingMeta(
      canEarly: canEarly,
      isDueOrLate: isDueOrLate,
      status: isDueOrLate
          ? 'مستحق الآن · $dateLabel${timeLabel == null ? '' : ' · $timeLabel'}'
          : 'بكر · $dateLabel${timeLabel == null ? '' : ' · $timeLabel'}',
    );
  }

  RecurringTransactionEntity? _linkedRecurringDebt(
    AppStateEntity state,
    DebtEntity debt,
  ) => BudgetRecurringPlanService.linkedRecurring(
        state.recurringTransactions,
        debt,
      );

  _ExpensePendingMeta? _expensePendingMeta(
    RecurringTransactionEntity? recurring,
  ) {
    if (recurring == null) {
      return null;
    }
    final now = DateTime.now();
    final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
    if (prompt == null) return null;
    return _ExpensePendingMeta(
      pending: true,
      status: switch (prompt.state) {
        RecurringExpensePromptState.upcoming =>
          'مستحق قريبًا · ${DateFormat('d/M HH:mm', 'ar').format(prompt.occurrence)}',
        RecurringExpensePromptState.due =>
          'مستحق الآن · ${DateFormat('d/M HH:mm', 'ar').format(prompt.occurrence)}',
        RecurringExpensePromptState.overdue => prompt.catchUpFromAuto
            ? 'دورة فائتة تحتاج قرارًا · ${DateFormat('d/M HH:mm', 'ar').format(prompt.occurrence)}'
            : 'استحقاق متأخر · ${DateFormat('d/M HH:mm', 'ar').format(prompt.occurrence)}',
      },
      occurrence: prompt.occurrence,
    );
  }

  DateTime _incomeDueDateForMonth(IncomeSourceEntity source, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = source.date.clamp(1, lastDay);
    return DateTime(month.year, month.month, day);
  }

  Future<void> _recordIncome(
    IncomeSourceEntity source, {
    bool early = false,
  }) async {
    double amount = source.amount;
    if (source.isVariable || amount <= 0) {
      final amountController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تسجيل دخل ${source.name}'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      amount = double.tryParse(amountController.text.trim()) ?? 0;
      if (amount <= 0) return;
    }

    final now = DateTime.now();
    await widget.cubit.addTransaction(
      walletId: source.targetWalletId,
      amount: amount,
      type: 'income',
      incomeSourceId: source.id,
      budgetScope: 'within-budget',
      createdAt: DateTime(now.year, now.month, now.day, 12),
      notes: early
          ? 'تسجيل دخل مبكر: ${source.name}'
          : 'تأكيد نزول دخل: ${source.name}',
    );
  }

  Future<void> _postponeIncome(
    IncomeSourceEntity source,
    DateTime month,
  ) async {
    final dueDate = _incomeDueDateForMonth(source, month);
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate.add(const Duration(days: 1)),
      firstDate: dueDate.add(const Duration(days: 1)),
      lastDate: DateTime(month.year, month.month + 1, 28),
    );
    if (picked == null) return;

    final setup = widget.cubit.state.budgetSetup;
    final incomes = setup.incomeSources
        .map(
          (income) => income.id == source.id
              ? IncomeSourceEntity(
                  id: income.id,
                  name: income.name,
                  amount: income.amount,
                  date: picked.day,
                  type: income.type,
                  targetWalletId: income.targetWalletId,
                  isVariable: income.isVariable,
                  isDefault: income.isDefault,
                )
              : income,
        )
        .toList();
    await widget.cubit.updateBudgetSetup(
      setup.copyWith(incomeSources: incomes),
    );
  }

  Future<void> _recordDebt(
    DebtEntity debt,
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) async {
    await widget.cubit.addTransaction(
      walletId: recurring.walletId,
      amount: debt.amount,
      type: 'expense',
      budgetScope: 'within-budget',
      createdAt: DateTime.now(),
      notes: 'سداد دين: ${debt.name}',
    );
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(
        lastHandledOccurrenceAt: occurrence.toIso8601String(),
        snoozedUntil: '',
      ),
    );
  }

  Future<void> _snoozeRecurringExpense(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) async {
    final now = DateTime.now();
    final nextSnooze = now.add(const Duration(hours: 1));
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(snoozedUntil: nextSnooze.toIso8601String()),
    );
  }

  Future<void> _skipRecurringExpenseOccurrence(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) async {
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(
        lastHandledOccurrenceAt: occurrence.toIso8601String(),
        snoozedUntil: '',
      ),
    );
  }

  _RecurringDecisionCandidate? _nextRecurringDecision(AppStateEntity state) {
    final now = DateTime.now();
    final cycleStart = state.budgetSetup.cycleStartFor(now);
    final cycleEnd = state.budgetSetup.cycleEndFor(now);
    final cycleTransactions = state.transactions.where((transaction) {
      return !transaction.createdAt.isBefore(cycleStart) &&
          !transaction.createdAt.isAfter(cycleEnd);
    }).toList();

    for (final debt in state.budgetSetup.debts) {
      final recurring = _linkedRecurringDebt(state, debt);
      if (recurring == null) continue;
      final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
      if (prompt == null ||
          prompt.state == RecurringExpensePromptState.upcoming) {
        continue;
      }
      final paidAmount = cycleTransactions
          .where(
              (transaction) => transaction.notes?.contains(debt.name) == true)
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
      final remaining = BudgetRecurringPlanService.pendingDecisionAmount(
        debt: debt,
        recurring: recurring,
        cyclePaid: paidAmount,
      );
      if (remaining <= 0) continue;
      return _RecurringDecisionCandidate(
        debt: debt,
        recurring: recurring,
        prompt: prompt,
        remaining: remaining,
      );
    }
    return null;
  }

  String _promptKey(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) {
    return '${recurring.id}-${occurrence.toIso8601String()}';
  }

  Future<_RecurringDecisionAction?> _showRecurringDecisionDialog(
    _RecurringDecisionCandidate candidate,
  ) {
    final dueLabel = DateFormat('d/M/yyyy - HH:mm', 'ar')
        .format(candidate.prompt.occurrence);
    final title = candidate.prompt.catchUpFromAuto
        ? 'معاملة فائتة تحتاج قرارًا'
        : 'معاملة متكررة مستحقة';
    final body = candidate.prompt.catchUpFromAuto
        ? 'هذه الدورة فات موعدها ولم يتم تنفيذها تلقائيًا. يمكنك تنفيذها الآن، أو تأجيلها قليلًا، أو تخطي هذه الدورة والانتقال للي بعدها.'
        : 'المعاملة ${candidate.debt.name} مستحقة الآن. يمكنك تنفيذها الآن، أو تأجيلها قليلًا، أو تخطي الدورة الحالية.';

    return showDialog<_RecurringDecisionAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate.debt.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 12),
            Text('المبلغ: ${candidate.remaining.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Text('موعد الاستحقاق: $dueLabel'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_RecurringDecisionAction.skip);
            },
            child: const Text('تخطي هذه المرة'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop(_RecurringDecisionAction.snooze);
            },
            child: const Text('تأجيل ساعة'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(_RecurringDecisionAction.executeNow);
            },
            child: const Text('تنفيذ الآن'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRecurringDecisionAction(
    _RecurringDecisionAction action,
    _RecurringDecisionCandidate candidate,
  ) async {
    final key = _promptKey(candidate.recurring, candidate.prompt.occurrence);
    switch (action) {
      case _RecurringDecisionAction.executeNow:
        _dismissedRecurringPromptKeys.remove(key);
        await _recordDebt(
          candidate.debt,
          candidate.recurring,
          candidate.prompt.occurrence,
        );
        break;
      case _RecurringDecisionAction.snooze:
        _dismissedRecurringPromptKeys.remove(key);
        await _snoozeRecurringExpense(
          candidate.recurring,
          candidate.prompt.occurrence,
        );
        break;
      case _RecurringDecisionAction.skip:
        _dismissedRecurringPromptKeys.remove(key);
        await _skipRecurringExpenseOccurrence(
          candidate.recurring,
          candidate.prompt.occurrence,
        );
        break;
    }
  }

  String _walletName(String walletId) {
    if (walletId.isEmpty) return 'بدون محفظة';
    final wallets =
        widget.cubit.state.wallets.where((wallet) => wallet.id == walletId);
    if (wallets.isEmpty) return 'بدون محفظة';
    return wallets.first.name;
  }

  String _historyTitle(NotificationEntity item) {
    return item.title.trim().isEmpty ? 'إشعار' : item.title.trim();
  }

  String _historyAmount(NotificationEntity item, LogEntryEntity? log) {
    final source = '${item.title} ${item.message} ${log?.details ?? ''}';
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(source);
    return match?.group(1) ?? 'بدون قيمة';
  }

  List<MapEntry<String, String>> _detailsRows(
    NotificationEntity item,
    LogEntryEntity? log,
  ) {
    final rows = <MapEntry<String, String>>[
      MapEntry('العنوان', item.title),
      MapEntry('القيمة', _historyAmount(item, log)),
      MapEntry(
        'الوقت',
        DateFormat('d/M/yyyy - HH:mm', 'ar').format(item.createdAt),
      ),
      MapEntry('الرسالة', item.message),
    ];
    if (log != null) {
      rows.add(MapEntry('الإجراء', log.action));
      rows.add(MapEntry('نوع العنصر', log.entityType));
      rows.add(MapEntry('الحالة', log.isReverted ? 'تم التراجع' : 'نشط'));
    }
    return rows;
  }

  Color _historyAccent(NotificationEntity item) {
    final text = '${item.title} ${item.message}';
    if (text.contains('دخل')) {
      return const Color(0xFF0F9D7A);
    }
    if (text.contains('تأجيل')) {
      return const Color(0xFF9B6B2F);
    }
    if (text.contains('دين') || text.contains('اشتراك')) {
      return const Color(0xFFC65D2E);
    }
    return const Color(0xFF2F6F5E);
  }

  IconData _historyIcon(NotificationEntity item) {
    final text = '${item.title} ${item.message}';
    if (text.contains('دخل')) {
      return Icons.south_west_rounded;
    }
    if (text.contains('دين') || text.contains('اشتراك')) {
      return Icons.credit_card_rounded;
    }
    if (text.contains('تأجيل')) {
      return Icons.schedule_rounded;
    }
    return Icons.notifications_active_rounded;
  }
}

class _IncomePendingMeta {
  const _IncomePendingMeta({
    required this.canEarly,
    required this.isDueOrLate,
    required this.status,
  });

  final bool canEarly;
  final bool isDueOrLate;
  final String status;
}

class _ExpensePendingMeta {
  const _ExpensePendingMeta({
    required this.pending,
    required this.status,
    required this.occurrence,
  });

  final bool pending;
  final String status;
  final DateTime occurrence;
}

enum _RecurringDecisionAction {
  executeNow,
  snooze,
  skip,
}

class _RecurringDecisionCandidate {
  const _RecurringDecisionCandidate({
    required this.debt,
    required this.recurring,
    required this.prompt,
    required this.remaining,
  });

  final DebtEntity debt;
  final RecurringTransactionEntity recurring;
  final RecurringExpensePrompt prompt;
  final double remaining;
}
