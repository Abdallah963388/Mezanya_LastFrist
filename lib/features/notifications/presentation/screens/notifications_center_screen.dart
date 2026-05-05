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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
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
              label: 'سدد الآن',
              onPressed: recurring == null
                  ? () {}
                  : () => _recordDebt(
                        debt,
                        recurring,
                        pendingMeta.occurrence,
                      ),
            ),
            PendingNotificationAction(
              label: 'تأجيل',
              filled: false,
              onPressed: recurring == null
                  ? () {}
                  : () => _openRecurringPostponeDialog(
                        debt: debt,
                        recurring: recurring,
                        occurrence: pendingMeta.occurrence,
                        amount: decisionAmount,
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
                  final approved = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(
                        log.isReverted ? 'إلغاء التراجع؟' : 'تأكيد التراجع',
                      ),
                      content: Text(
                        log.isReverted
                            ? 'سيتم إلغاء التراجع وإعادة تطبيق الإجراء السابق.'
                            : 'سيتم التراجع عن هذا الإجراء وتحديث البيانات بناءً على السجل.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('تأكيد'),
                        ),
                      ],
                    ),
                  );
                  if (approved != true) return;
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
  ) =>
      BudgetRecurringPlanService.linkedRecurring(
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
    final picked = await _showPostponeDialog(
      title: 'تأجيل معاملة متكررة',
      name: source.name,
      amount: source.amount,
      kindLabel: 'راتب / دخل',
      occurrence: dueDate,
      allowSkip: false,
    );
    if (picked == null) return;

    final setup = widget.cubit.state.budgetSetup;
    final incomes = setup.incomeSources
        .map(
          (income) => income.id == source.id
              ? income.copyWith(snoozedUntil: picked.toIso8601String())
              : income,
        )
        .toList();
    await widget.cubit.updateBudgetSetup(
      setup.copyWith(incomeSources: incomes),
      detailsOverride:
          'تأجيل دخل: ${source.name} حتى ${DateFormat('d/M/yyyy', 'ar').format(picked)}',
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
      detailsOverride:
          'سدد الآن: ${debt.name} بقيمة ${debt.amount.toStringAsFixed(2)}',
    );
  }

  Future<void> _skipRecurringExpenseOccurrence(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
    String name,
    double amount,
  ) async {
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(
        lastHandledOccurrenceAt: occurrence.toIso8601String(),
        snoozedUntil: '',
      ),
      detailsOverride:
          'تخطي هذه المرة: $name بقيمة ${amount.toStringAsFixed(2)}',
    );
  }

  Future<void> _postponeRecurringExpenseUntil({
    required RecurringTransactionEntity recurring,
    required String name,
    required double amount,
    required DateTime until,
  }) async {
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(snoozedUntil: until.toIso8601String()),
      detailsOverride:
          'تأجيل معاملة متكررة: $name بقيمة ${amount.toStringAsFixed(2)} حتى ${DateFormat('d/M/yyyy', 'ar').format(until)}',
    );
  }

  Future<void> _openRecurringPostponeDialog({
    required DebtEntity debt,
    required RecurringTransactionEntity recurring,
    required DateTime occurrence,
    required double amount,
  }) async {
    final picked = await _showPostponeDialog(
      title: 'تأجيل معاملة متكررة',
      name: debt.name,
      amount: amount,
      kindLabel: debt.isSubscription ? 'اشتراك' : 'دفعة دين',
      occurrence: occurrence,
      allowSkip: true,
    );
    if (picked == null) return;
    if (picked == _PostponeChoice.skip) {
      await _skipRecurringExpenseOccurrence(
        recurring,
        occurrence,
        debt.name,
        amount,
      );
      return;
    }
    await _postponeRecurringExpenseUntil(
      recurring: recurring,
      name: debt.name,
      amount: amount,
      until: picked,
    );
  }

  Future<DateTime?> _showPostponeDialog({
    required String title,
    required String name,
    required double amount,
    required String kindLabel,
    required DateTime occurrence,
    required bool allowSkip,
  }) {
    final now = DateTime.now();
    DateTime atMorning(DateTime date) =>
        DateTime(date.year, date.month, date.day, 9);

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final accent = const Color(0xFF9B6B2F);
        final amountLabel = amount <= 0 ? 'مجاني' : amount.toStringAsFixed(2);

        Widget option({
          required IconData icon,
          required String label,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kindLabel,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$amountLabel · استحقاق ${DateFormat('d/M/yyyy', 'ar').format(occurrence)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (allowSkip)
                  option(
                    icon: Icons.skip_next_rounded,
                    label: 'تخطي هذه المرة',
                    subtitle: 'اعتبر هذه المرة منتهية وانتقل للاستحقاق القادم',
                    onTap: () =>
                        Navigator.of(dialogContext).pop(_PostponeChoice.skip),
                  ),
                option(
                  icon: Icons.today_rounded,
                  label: 'تأجيل يوم',
                  subtitle: 'إظهارها مرة أخرى غدًا',
                  onTap: () => Navigator.of(dialogContext).pop(
                    atMorning(now.add(const Duration(days: 1))),
                  ),
                ),
                option(
                  icon: Icons.event_repeat_rounded,
                  label: 'تأجيل 3 أيام',
                  subtitle: 'إظهارها بعد ثلاثة أيام',
                  onTap: () => Navigator.of(dialogContext).pop(
                    atMorning(now.add(const Duration(days: 3))),
                  ),
                ),
                option(
                  icon: Icons.edit_calendar_rounded,
                  label: 'تحديد تاريخ',
                  subtitle: 'اختار تاريخ مناسب يدويًا',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: now.add(const Duration(days: 1)),
                      firstDate: now.add(const Duration(days: 1)),
                      lastDate: DateTime(now.year + 1, now.month, now.day),
                    );
                    if (picked == null || !dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(atMorning(picked));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );
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

class _PostponeChoice {
  static final DateTime skip = DateTime(1);
}
