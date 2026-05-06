import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import 'recurring_transaction_composer_screen.dart';
import 'subscription_preset_selection_screen.dart';

class DebtsAndSubscriptionsScreen extends StatefulWidget {
  const DebtsAndSubscriptionsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<DebtsAndSubscriptionsScreen> createState() =>
      _DebtsAndSubscriptionsScreenState();
}

class _DebtsAndSubscriptionsScreenState
    extends State<DebtsAndSubscriptionsScreen> {
  static const Color _debtAccent = Color(0xFFC65D2E);
  static const Color _lentAccent = Color(0xFF1A7A4A);
  static const Color _subscriptionAccent = Color(0xFF2E5CC6);
  static const Color _sharedCardBackground = Color(0xFFF9F3E7);

  String _tab = 'subscriptions';
  bool _archiveExpanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;

        final List<RecurringTransactionEntity> debtRecords = state
            .recurringTransactions
            .where((r) =>
                r.expensePlanKind == 'installment' ||
                r.expensePlanKind == 'lent')
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        final subscriptionRecords = state.recurringTransactions
            .where((r) =>
                r.type == 'expense' && r.expensePlanKind == 'subscription')
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        // ── السلفات: فصل النشط عن الأرشيف
        final allLentPersons = state.recurringTransactions
            .where((r) => r.isLent)
            .toList()
          ..sort((a, b) => (a.lentPersonName ?? a.name).compareTo(b.lentPersonName ?? b.name));
        final activeLentPersons = allLentPersons
            .where((r) => !r.isLentArchived)
            .toList();
        final archivedLentPersons = allLentPersons
            .where((r) => r.isLentArchived)
            .toList();
        final borrowedRecords = state.recurringTransactions
            .where((r) => !r.isLent && r.expensePlanKind == 'installment')
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('الديون والاشتراكات'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _typeSwitcher(),
              const SizedBox(height: 14),
              if (_tab == 'subscriptions') ...[
                _actionButton(
                  label: 'إضافة اشتراك جديد',
                  icon: Icons.subscriptions_rounded,
                  color: _subscriptionAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionPresetSelectionScreen(
                          cubit: widget.cubit,
                        ),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (subscriptionRecords.isEmpty)
                  _emptyCard('لا توجد اشتراكات مسجلة حالياً.')
                else
                  ...subscriptionRecords
                      .map((r) => _recurringCard(state, r)),
              ] else ...[
                // ── زرار الإضافة ─────────────────────────────────────────
                _actionButton(
                  label: 'دين أو قسط',
                  icon: Icons.account_balance_outlined,
                  color: _debtAccent,
                  onTap: () => _openRecurringComposer(
                    mode: 'expense',
                    initialExpensePlanKind: 'installment',
                    debtOnlyMode: true,
                  ),
                ),
                const SizedBox(height: 20),

                // ── سكشن: ديون عليّ ──────────────────────────────────────
                _sectionHeader(
                  label: 'ديون وأقساط عليّ',
                  color: _debtAccent,
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 10),
                if (borrowedRecords.isEmpty)
                  _emptyCard('لا توجد ديون أو أقساط مسجلة حالياً.')
                else
                  ...borrowedRecords.map((r) => _recurringCard(state, r)),

                const SizedBox(height: 20),

                // ── سكشن: سلّفت للناس ────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _sectionHeader(
                        label: 'سلّفت للناس',
                        color: _lentAccent,
                        icon: Icons.handshake_outlined,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openLentForm(state, existingPersonId: null),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('سلفة جديدة'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _lentAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (activeLentPersons.isEmpty)
                  _emptyCard('ما سلّفتش حد حالياً.')
                else
                  ...activeLentPersons.map((r) => _lentPersonCard(state, r)),

                // ── قسم الأرشيف ────────────────────────────────────────────
                if (archivedLentPersons.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => setState(() => _archiveExpanded = !_archiveExpanded),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'الأرشيف (${archivedLentPersons.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _archiveExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_archiveExpanded) ...[
                    const SizedBox(height: 8),
                    ...archivedLentPersons.map((r) => _lentPersonCard(state, r, isArchived: true)),
                  ],
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: color,
        ),
      ),
    ]);
  }

  Color get _currentAccent {
    if (_tab == 'subscriptions') return _subscriptionAccent;
    return _debtAccent;
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeSwitcher() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          _switchTile(
            'subscriptions',
            'الاشتراكات',
            Icons.subscriptions_rounded,
          ),
          const SizedBox(width: 8),
          _switchTile('debts', 'الديون', Icons.account_balance_outlined),
        ],
      ),
    );
  }

  Widget _switchTile(String value, String label, IconData icon) {
    final selected = _tab == value;
    final accent = value == 'subscriptions' ? _subscriptionAccent : _debtAccent;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = value),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.surface : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? accent : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? accent : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── بطاقة الشخص (السلف) ──────────────────────────────────────────────────
  Widget _lentPersonCard(
    AppStateEntity state,
    RecurringTransactionEntity person, {
    bool isArchived = false,
  }) {
    final accent = _parseColor(person.iconColor);
    final personName = person.lentPersonName ?? person.name;
    final outstanding = person.outstandingLentAmount;
    final totalEntries = person.lentEntries.length;
    final pendingCount = person.lentEntries.where((e) => e['isSettled'] != true).length;
    final walletName = _walletName(state, person.walletId);

    DateTime? earliestDue;
    for (final e in person.lentEntries.where((e) => e['isSettled'] != true)) {
      final d = e['expectedReturnDate'] != null
          ? DateTime.tryParse(e['expectedReturnDate'] as String)
          : null;
      if (d != null && (earliestDue == null || d.isBefore(earliestDue))) {
        earliestDue = d;
      }
    }
    final isOverdue = earliestDue != null && earliestDue.isBefore(DateTime.now());
    final dueLbl = earliestDue != null
        ? '${earliestDue.day}/${earliestDue.month}/${earliestDue.year}'
        : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openLentPersonSheet(state, person),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isArchived
                ? Colors.grey.withValues(alpha: 0.05)
                : const Color(0xFFF0FAF4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isArchived
                  ? Colors.grey.withValues(alpha: 0.2)
                  : accent.withValues(alpha: isOverdue ? 0.55 : 0.22),
              width: isOverdue ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (isArchived ? Colors.grey : accent)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: AppIconPickerDialog.iconWidgetForName(
                  isArchived ? 'archive' : person.icon,
                  color: isArchived ? Colors.grey : accent,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isArchived ? Colors.grey.shade600 : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'محفظة: $walletName · $pendingCount/${totalEntries} سلف',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  outstanding.toStringAsFixed(2),
                  style: TextStyle(
                    color: isArchived ? Colors.grey : accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (!isArchived) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? const Color(0xFFFFEDED)
                          : const Color(0xFFE8F5ED),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isOverdue ? '⚠ $dueLbl' : dueLbl,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOverdue
                            ? const Color(0xFFC0392B)
                            : accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openLentPersonSheet(
    AppStateEntity state,
    RecurringTransactionEntity person,
  ) async {
    final theme = Theme.of(context);
    final accent = _parseColor(person.iconColor);
    final personName = person.lentPersonName ?? person.name;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          final currentState = widget.cubit.state;
          final currentPerson = currentState.recurringTransactions
              .where((r) => r.id == person.id)
              .cast<RecurringTransactionEntity?>()
              .firstWhere((_) => true, orElse: () => null) ?? person;
          
          final pendingEntries = currentPerson.lentEntries.where((e) => e['isSettled'] != true).toList();
          
          final historyTxs = currentState.transactions.where((t) =>
              ((t.notes?.contains('سلفة لـ $personName') ?? false) ||
               (t.notes?.contains('استرداد سلفة من $personName') ?? false))
          ).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.9,
            child: Column(
              children: [
                // ── Hero Header ──────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(child: AppIconPickerDialog.iconWidgetForName(person.icon, color: Colors.white, size: 28)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(personName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                        Text('إجمالي غير مسترد: ${currentPerson.outstandingLentAmount.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    )),
                    IconButton.filledTonal(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _openLentForm(currentState, existingPersonId: currentPerson.id);
                      },
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Expanding Card for Pending Entries ──────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LentEntriesExpandingCard(
                    theme: theme,
                    accent: accent,
                    person: currentPerson,
                    pendingEntries: pendingEntries,
                    onEntryAction: () => setS(() {}),
                    cubit: widget.cubit,
                  ),
                ),

                const SizedBox(height: 16),

                // ── History Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Icon(Icons.history_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('سجل المعاملات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ]),
                ),

                // ── History List ────────────────────────────────────────
                Expanded(
                  child: historyTxs.isEmpty
                      ? const Center(child: Text('لا توجد معاملات مسجلة'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          itemCount: historyTxs.length,
                          itemBuilder: (ctx, i) {
                            final tx = historyTxs[i];
                            final isIncome = tx.type == 'income';
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(isIncome ? Icons.south_west_rounded : Icons.north_east_rounded, size: 16, color: isIncome ? Colors.green : Colors.red),
                              ),
                              title: Text(isIncome ? 'استرداد مبلغ' : 'إخراج سلفة', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(DateFormat('d MMMM yyyy', 'ar').format(tx.createdAt), style: const TextStyle(fontSize: 11)),
                              trailing: Text('${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)}',
                                  style: TextStyle(fontWeight: FontWeight.w900, color: isIncome ? Colors.green : Colors.red)),
                            );
                          },
                        ),
                ),

                // ── أزرار الشخص ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await widget.cubit.archiveLentPerson(person.id, archive: !person.isLentArchived);
                      },
                      icon: Icon(person.isLentArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 16),
                      label: Text(person.isLentArchived ? 'إلغاء الأرشفة' : 'أرشفة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await widget.cubit.deleteRecurringTransaction(person.id);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('حذف'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDialog({required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _lentAccent),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── فورم إضافة سلفة (جديد أو لشخص موجود) ────────────────────────────────
  Future<void> _openLentForm(AppStateEntity state, {String? existingPersonId}) async {
    final existingPerson = existingPersonId != null
        ? state.recurringTransactions
            .where((r) => r.id == existingPersonId)
            .cast<RecurringTransactionEntity?>()
            .firstWhere((_) => true, orElse: () => null)
        : null;

    final nameCtrl = TextEditingController(text: existingPerson?.lentPersonName ?? existingPerson?.name ?? '');
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String walletId = existingPerson?.walletId ?? (state.wallets.isNotEmpty ? state.wallets.first.id : '');
    DateTime lentDate = DateTime.now();
    DateTime returnDate = DateTime.now().add(const Duration(days: 30));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 46, height: 5,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A7A4A), Color(0xFF2DAE6B)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(children: [
                    Container(width: 48, height: 48,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Icon(Icons.handshake_outlined, color: Colors.white, size: 26))),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(existingPerson != null ? 'سلفة جديدة لـ ${existingPerson.lentPersonName ?? existingPerson.name}' : 'تسجيل سلفة',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      const Text('المبلغ يُخصم من المحفظة فوراً',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),

                // اسم الشخص
                if (existingPerson == null)
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الشخص', prefixIcon: Icon(Icons.person_outline_rounded)))
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _lentAccent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(Icons.person_rounded, color: _lentAccent, size: 20),
                      const SizedBox(width: 10),
                      Text(existingPerson.lentPersonName ?? existingPerson.name, style: const TextStyle(fontWeight: FontWeight.w800, color: _lentAccent)),
                    ]),
                  ),
                const SizedBox(height: 12),

                // المبلغ
                TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.payments_outlined))),
                const SizedBox(height: 12),

                // المحفظة
                if (state.wallets.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(16)),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                      value: walletId.isEmpty ? null : walletId, isExpanded: true, hint: const Text('اختر المحفظة'),
                      items: state.wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                      onChanged: (v) { if (v != null) setS(() => walletId = v); },
                    )),
                  ),
                  const SizedBox(height: 12),
                ],

                // تاريخ السلفة
                _datePicker(ctx: ctx, label: 'تاريخ السلفة', date: lentDate,
                    firstDate: DateTime(2020), lastDate: DateTime.now(),
                    onPicked: (d) => setS(() => lentDate = d)),
                const SizedBox(height: 10),

                // تاريخ الاسترداد
                _datePicker(ctx: ctx, label: 'تاريخ الاسترداد المتوقع', date: returnDate,
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    onPicked: (d) => setS(() => returnDate = d)),
                const SizedBox(height: 12),

                // ملاحظة
                TextField(controller: notesCtrl, maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', prefixIcon: Icon(Icons.notes_outlined))),
                const SizedBox(height: 20),

                SizedBox(width: double.infinity, child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _lentAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    final name = existingPerson != null ? (existingPerson.lentPersonName ?? existingPerson.name) : nameCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (name.isEmpty || amount <= 0 || walletId.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('أدخل الاسم والمبلغ والمحفظة')));
                      return;
                    }
                    Navigator.pop(ctx);
                    await widget.cubit.addLentRecord(
                      personName: name, amount: amount, walletId: walletId,
                      lentDate: lentDate, expectedReturnDate: returnDate,
                      existingPersonId: existingPersonId,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('تسجيل السلفة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                )),
              ],
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  Widget _datePicker({
    required BuildContext ctx,
    required String label,
    required DateTime date,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final d = await showDatePicker(context: ctx, initialDate: date, firstDate: firstDate, lastDate: lastDate);
        if (d != null) onPicked(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(Icons.calendar_month_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text('$label: ${date.day}/${date.month}/${date.year}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }


  Widget _recurringCard(
    AppStateEntity state,
    RecurringTransactionEntity record,
  ) {
    final accent = _parseColor(record.iconColor);
    final amountLabel =
        record.isVariableIncome ? 'متغير' : record.amount.toStringAsFixed(2);
    final wallet = _walletName(state, record.walletId);
    final execution = _executionLabel(record.executionType);
    final scope =
        record.budgetScope == 'within-budget' ? 'داخل الميزانية' : 'عام';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openDetailsSheet(state, record),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _sharedCardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: AppIconPickerDialog.iconWidgetForName(
                    record.icon,
                    color: accent,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          amountLabel,
                          style: const TextStyle(
                            color: Color(0xFF254034),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _recurrenceLabel(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _miniTag(execution),
                        _miniTag(scope),
                        if (wallet != '-') _miniTag(wallet),
                        if (record.type == 'expense')
                          _miniTag(_expensePlanKindLabel(record)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_left_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _openDetailsSheet(
    AppStateEntity state,
    RecurringTransactionEntity record,
  ) async {
    final accent = _parseColor(record.iconColor);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setS) {
          // Re-fetch the current state of this record to handle updates (like payments)
          final currentState = widget.cubit.state;
          final currentRecord = currentState.recurringTransactions
                  .where((r) => r.id == record.id)
                  .cast<RecurringTransactionEntity?>()
                  .firstWhere((_) => true, orElse: () => null) ??
              record;

          final isDebt = currentRecord.expensePlanKind == 'installment';

          return SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.88,
            child: Column(
              children: [
                // ── Hero Header ──────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: AppIconPickerDialog.iconWidgetForName(
                            currentRecord.icon,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentRecord.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_typeLabel(currentRecord)} · ${_executionLabel(currentRecord.executionType)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currentRecord.isVariableIncome
                                ? 'متغير'
                                : currentRecord.amount.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            'ج.م',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // ── Interactive Fulfillment Card (for Debts) ──────────
                      if (isDebt) ...[
                        _DebtInstallmentInteractiveCard(
                          record: currentRecord,
                          state: currentState,
                          accent: accent,
                          onPaid: () => setS(() {}),
                          cubit: widget.cubit,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Details Table ──────────────────────────────────────
                      _sectionTitle(context, 'تفاصيل المعاملة',
                          Icons.info_outline_rounded),
                      const SizedBox(height: 10),
                      _DetailsTable(rows: _detailsRows(currentState, currentRecord)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // ── Action Buttons ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _openRecurringComposer(
                              mode: currentRecord.type,
                              editing: currentRecord,
                              subscriptionOnlyMode:
                                  currentRecord.expensePlanKind ==
                                      'subscription',
                              debtOnlyMode: currentRecord.expensePlanKind ==
                                  'installment',
                            );
                          },
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          label: const Text('تعديل البيانات',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        onPressed: () async {
                          final confirm = await _confirmDialog(
                            title: 'حذف المعاملة',
                            content: 'هل أنت متأكد من حذف ${currentRecord.name}؟',
                          );
                          if (confirm) {
                            await widget.cubit
                                .deleteRecurringTransaction(currentRecord.id);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Map<String, String> _detailsRows(
    AppStateEntity state,
    RecurringTransactionEntity record,
  ) {
    return {
      'اسم المعاملة': record.name,
      'النوع': _typeLabel(record),
      'القيمة': record.isVariableIncome
          ? 'دخل متغير'
          : record.amount.toStringAsFixed(2),
      'المحفظة': _walletName(state, record.walletId),
      'النطاق':
          record.budgetScope == 'within-budget' ? 'داخل الميزانية' : 'عام',
      'التكرار': _recurrenceLabel(record),
      'التنفيذ': _executionLabel(record.executionType),
      if (record.reminderLeadDays != null)
        'التنبيه قبل': _reminderLabel(record),
      if (record.incomeSourceId != null)
        'مصدر الدخل': _incomeName(state, record.incomeSourceId!),
      if (record.allocationId != null)
        'المخصص': _allocationName(state, record.allocationId!),
      if (record.targetJarId != null)
        'الحصالة': _jarName(state, record.targetJarId!),
      if (record.categoryIds.isNotEmpty)
        'الفئات':
            record.categoryIds.map((id) => _categoryName(state, id)).join('، '),
      if (record.type == 'expense') 'التصنيف': _expensePlanKindLabel(record),
      if (record.expensePlanKind == 'installment' &&
          record.debtPrincipalTotal != null)
        'إجمالي الأصل': record.debtPrincipalTotal!.toStringAsFixed(2),
      if (record.notes?.trim().isNotEmpty == true)
        'الملاحظات': record.notes!.trim(),
    };
  }

  String _recurrenceLabel(RecurringTransactionEntity record) {
    final timeSuffix = (record.scheduledTime ?? '').isEmpty
        ? ''
        : ' · ${record.scheduledTime}';
    final weekdayLabel = record.weekdays.isNotEmpty
        ? record.weekdays.map(_weekdayName).join('، ')
        : _weekdayName(record.weekday);
    return switch (record.recurrencePattern) {
      'daily' => 'يومي$timeSuffix',
      'weekly' => 'أسبوعي ($weekdayLabel)$timeSuffix',
      'biweekly' => 'كل أسبوعين ($weekdayLabel)$timeSuffix',
      'every_3_weeks' => 'كل 3 أسابيع ($weekdayLabel)$timeSuffix',
      'every_2_months' => 'كل شهرين يوم ${record.dayOfMonth}$timeSuffix',
      'every_3_months' => 'كل 3 شهور يوم ${record.dayOfMonth}$timeSuffix',
      'every_6_months' => 'كل 6 شهور يوم ${record.dayOfMonth}$timeSuffix',
      'yearly' =>
        'سنوي ${record.dayOfMonth}/${record.monthOfYear ?? 1}$timeSuffix',
      'manual-variable' => 'يدوي / مرة واحدة',
      _ => 'شهري يوم ${record.dayOfMonth}$timeSuffix',
    };
  }

  String _typeLabel(RecurringTransactionEntity record) {
    if (record.type == 'income') return 'دخل';
    return 'مصروف';
  }

  String _expensePlanKindLabel(RecurringTransactionEntity record) {
    if (record.expensePlanKind == 'installment') return 'قسط / دين';
    if (record.expensePlanKind == 'subscription') return 'اشتراك';
    if (record.expensePlanKind == 'lent') return 'سلفة';
    return 'مصروف متكرر';
  }

  String _executionLabel(String type) => type == 'auto' ? 'تلقائي' : 'يدوي';

  String _reminderLabel(RecurringTransactionEntity record) {
    final days = record.reminderLeadDays ?? 0;
    if (days == 0) {
      return record.recurrencePattern == 'daily' ||
              record.recurrencePattern == 'weekly' ||
              record.recurrencePattern == 'biweekly' ||
              record.recurrencePattern == 'every_3_weeks'
          ? 'في نفس الوقت'
          : 'في نفس اليوم';
    }
    if (record.recurrencePattern == 'daily' ||
        record.recurrencePattern == 'weekly' ||
        record.recurrencePattern == 'biweekly' ||
        record.recurrencePattern == 'every_3_weeks') {
      return 'قبلها بـ $days ساعة';
    }
    return 'قبلها بـ $days يوم';
  }

  String _walletName(AppStateEntity state, String id) {
    try {
      return state.wallets.firstWhere((w) => w.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _incomeName(AppStateEntity state, String id) {
    try {
      return state.budgetSetup.incomeSources.firstWhere((i) => i.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _allocationName(AppStateEntity state, String id) {
    try {
      return state.budgetSetup.allocations.firstWhere((a) => a.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _jarName(AppStateEntity state, String id) {
    try {
      return state.budgetSetup.linkedWallets.firstWhere((j) => j.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _categoryName(AppStateEntity state, String id) {
    try {
      return state.categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _weekdayName(int? dayIndex) {
    if (dayIndex == null) return '';
    return [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ][(dayIndex - 1).clamp(0, 6)];
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _openRecurringComposer({
    required String mode,
    RecurringTransactionEntity? editing,
    String? initialExpensePlanKind,
    bool subscriptionOnlyMode = false,
    bool debtOnlyMode = false,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: mode,
          initialRecurring: editing,
          initialWithinBudget: true,
          initialExpensePlanKind:
              editing?.expensePlanKind ?? initialExpensePlanKind,
          allowDelete: editing != null,
          subscriptionOnlyMode: subscriptionOnlyMode,
          debtOnlyMode: debtOnlyMode,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

class _LentEntriesExpandingCard extends StatefulWidget {
  const _LentEntriesExpandingCard({
    required this.theme,
    required this.accent,
    required this.person,
    required this.pendingEntries,
    required this.onEntryAction,
    required this.cubit,
  });

  final ThemeData theme;
  final Color accent;
  final RecurringTransactionEntity person;
  final List<dynamic> pendingEntries;
  final VoidCallback onEntryAction;
  final AppCubit cubit;

  @override
  State<_LentEntriesExpandingCard> createState() => _LentEntriesExpandingCardState();
}

class _LentEntriesExpandingCardState extends State<_LentEntriesExpandingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = widget.accent;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'سلفات لم تسدد (${widget.pendingEntries.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildEntriesList(),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    if (widget.pendingEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Text('لا توجد سلفات معلقة حالياً.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...widget.pendingEntries.map((entry) {
            final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
            final returnStr = entry['expectedReturnDate'] as String?;
            final returnDate = returnStr != null ? DateTime.tryParse(returnStr) : null;
            final entryId = entry['id'] as String;
            final isOverdue = returnDate != null && returnDate.isBefore(DateTime.now());

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOverdue ? Colors.red.withValues(alpha: 0.05) : widget.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            if (returnDate != null)
                              Text(
                                'تاريخ الاسترداد: ${returnDate.day}/${returnDate.month}',
                                style: TextStyle(fontSize: 11, color: isOverdue ? Colors.red : Colors.grey, fontWeight: isOverdue ? FontWeight.w700 : null),
                              ),
                          ],
                        ),
                      ),
                      _miniActionBtn(label: 'رد', icon: Icons.check_rounded, color: widget.accent, onTap: () async {
                        await widget.cubit.settleLentEntry(widget.person.id, entryId);
                        widget.onEntryAction();
                      }),
                      const SizedBox(width: 6),
                      _miniActionBtn(label: 'أجل', icon: Icons.update_rounded, color: Colors.blueGrey, onTap: () async {
                         final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (d != null) {
                            await widget.cubit.postponeLentEntry(widget.person.id, entryId, d);
                            widget.onEntryAction();
                          }
                      }),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _miniActionBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DebtInstallmentInteractiveCard extends StatefulWidget {
  const _DebtInstallmentInteractiveCard({
    required this.record,
    required this.state,
    required this.accent,
    required this.onPaid,
    required this.cubit,
  });

  final RecurringTransactionEntity record;
  final AppStateEntity state;
  final Color accent;
  final VoidCallback onPaid;
  final AppCubit cubit;

  @override
  State<_DebtInstallmentInteractiveCard> createState() =>
      _DebtInstallmentInteractiveCardState();
}

class _DebtInstallmentInteractiveCardState
    extends State<_DebtInstallmentInteractiveCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;
    final state = widget.state;

    // Calculate progress
    final totalPrincipal = record.debtPrincipalTotal ?? 0;
    final installmentAmt = record.amount;
    final totalInstallments = record.installmentCount ?? 0;

    // Find transactions related to this debt
    final payments = state.transactions
        .where((t) =>
            t.notes?.contains('سداد دين: ${record.name}') == true ||
            t.notes?.contains('سداد قسط: ${record.name}') == true)
        .toList();

    final paidAmount = payments.fold(0.0, (sum, t) => sum + t.amount);
    final paidCount = (paidAmount / (installmentAmt > 0 ? installmentAmt : 1)).floor();
    final remainingAmount = (totalPrincipal - paidAmount).clamp(0.0, totalPrincipal);

    // Check if paid this month
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final paidThisMonth = payments.any((t) => t.createdAt.isAfter(thisMonthStart));

    final progress = totalPrincipal > 0 ? (paidAmount / totalPrincipal).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded,
                            color: widget.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'موقف السداد',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            Text(
                              'متبقي ${remainingAmount.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'التقدم: $paidCount / $totalInstallments قسط',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: widget.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: widget.accent,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: paidThisMonth
                          ? Colors.green.withValues(alpha: 0.08)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: paidThisMonth
                            ? Colors.green.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: paidThisMonth
                                ? Colors.green.withValues(alpha: 0.15)
                                : theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            paidThisMonth
                                ? Icons.check_rounded
                                : Icons.calendar_today_rounded,
                            color: paidThisMonth
                                ? Colors.green
                                : theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paidThisMonth ? 'تم سداد قسط هذا الشهر' : 'قسط هذا الشهر',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: paidThisMonth ? Colors.green.shade800 : null,
                                ),
                              ),
                              Text(
                                paidThisMonth
                                    ? 'تم السداد بنجاح'
                                    : 'مستحق بقيمة ${installmentAmt.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!paidThisMonth)
                          FilledButton(
                            onPressed: () async {
                              await widget.cubit.addTransaction(
                                walletId: record.walletId,
                                amount: installmentAmt,
                                type: 'expense',
                                budgetScope: 'within-budget',
                                createdAt: DateTime.now(),
                                notes: 'سداد قسط: ${record.name}',
                                details: 'سداد قسط من صفحة الديون: ${record.name}',
                              );
                              widget.onPaid();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('سداد',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  final Map<String, String> rows;

  const _DetailsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        children: rows.entries.map((entry) {
          final isLast = entry.key == rows.entries.last.key;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
