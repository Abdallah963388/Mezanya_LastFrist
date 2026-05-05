import 'package:flutter/material.dart';

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

        final lentRecords = debtRecords.where((r) => r.isLent).toList();
        final borrowedRecords = debtRecords
            .where((r) => !r.isLent && r.expensePlanKind == 'installment')
            .toList();

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
                _sectionHeader(
                  label: 'سلّفت للناس',
                  color: _lentAccent,
                  icon: Icons.handshake_outlined,
                ),
                const SizedBox(height: 10),
                if (lentRecords.isEmpty)
                  _emptyCard('ما سلّفتش حد حالياً.')
                else
                  ...lentRecords.map((r) => _lentCard(state, r)),
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

  // ── بطاقة السلفة ─────────────────────────────────────────────────────────
  Widget _lentCard(AppStateEntity state, RecurringTransactionEntity record) {
    const accent = _lentAccent;
    final walletName = _walletName(state, record.walletId);
    final returnDate = record.anchorDate != null
        ? DateTime.tryParse(record.anchorDate!)
        : null;
    final returnLabel = returnDate != null
        ? '${returnDate.day}/${returnDate.month}/${returnDate.year}'
        : 'غير محدد';
    final isOverdue =
        returnDate != null && returnDate.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accent.withValues(alpha: isOverdue ? 0.55 : 0.22),
            width: isOverdue ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.handshake_outlined,
                      color: accent, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.lentPersonName ?? record.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'محفظة: $walletName',
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
                    record.amount.toStringAsFixed(2),
                    style: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
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
                      isOverdue ? '⚠ $returnLabel' : returnLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isOverdue
                            ? const Color(0xFFC0392B)
                            : const Color(0xFF1A7A4A),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
            if (record.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                record.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _confirmSettleLent(record),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('تم الاسترداد',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: const BorderSide(color: accent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _openPostponeSheet(record),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text('تأجيل', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                onPressed: () async {
                  await widget.cubit
                      .deleteRecurringTransaction(record.id);
                },
                child: const Icon(Icons.delete_outline, size: 18),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSettleLent(RecurringTransactionEntity record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاسترداد'),
        content: Text(
          'هل استردّيت مبلغ ${record.amount.toStringAsFixed(2)} من ${record.lentPersonName ?? record.name}؟\n\nسيُضاف المبلغ لمحفظتك تلقائياً.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: _lentAccent),
            child: const Text('تم الاسترداد'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.cubit.settleLentRecord(record.id);
    }
  }

  Future<void> _openPostponeSheet(RecurringTransactionEntity record) async {
    DateTime picked = record.anchorDate != null
        ? (DateTime.tryParse(record.anchorDate!) ?? DateTime.now())
        : DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'تأجيل استرداد السلفة',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر تاريخ الاسترداد الجديد لسلفة ${record.lentPersonName ?? record.name}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: picked,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365 * 5)),
                    );
                    if (d != null) setS(() => picked = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _lentAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _lentAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: _lentAccent),
                      const SizedBox(width: 10),
                      Text(
                        '${picked.day}/${picked.month}/${picked.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _lentAccent,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _lentAccent),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await widget.cubit
                          .postponeLentRecord(record.id, picked);
                    },
                    child: const Text('تأكيد التأجيل'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── فورم إضافة سلفة ──────────────────────────────────────────────────────
  Future<void> _openLentForm(AppStateEntity state) async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String walletId =
        state.wallets.isNotEmpty ? state.wallets.first.id : '';
    DateTime returnDate =
        DateTime.now().add(const Duration(days: 30));
    bool isMonthly = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Hero ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A7A4A), Color(0xFF2DAE6B)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.handshake_outlined,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تسجيل سلفة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'المبلغ يُخصم من المحفظة فوراً',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── اسم الشخص ──────────────────────────────────────────
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشخص',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // ── المبلغ ──────────────────────────────────────────────
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المسلَّف',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // ── المحفظة ─────────────────────────────────────────────
                if (state.wallets.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: walletId.isEmpty ? null : walletId,
                        isExpanded: true,
                        hint: const Text('اختر المحفظة'),
                        items: state.wallets.map((w) {
                          return DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setS(() => walletId = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── تاريخ الاسترداد المتوقع ─────────────────────────────
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: returnDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365 * 5)),
                    );
                    if (d != null) setS(() => returnDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'تاريخ الاسترداد المتوقع: ${returnDate.day}/${returnDate.month}/${returnDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 4),

                // ── أقساط شهرية؟ ────────────────────────────────────────
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: isMonthly,
                  title: const Text('يردها أقساط شهرية',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('سيظهر تذكير شهري',
                      style: TextStyle(fontSize: 12)),
                  onChanged: (v) => setS(() => isMonthly = v),
                ),

                // ── ملاحظة ──────────────────────────────────────────────
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _lentAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final amount = double.tryParse(
                              amountCtrl.text.trim()) ??
                          0;
                      if (name.isEmpty || amount <= 0 || walletId.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'من فضلك أدخل اسم الشخص والمبلغ والمحفظة')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await widget.cubit.addLentRecord(
                        personName: name,
                        amount: amount,
                        walletId: walletId,
                        expectedReturnDate: returnDate,
                        isMonthlyInstallments: isMonthly,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تسجيل السلفة',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
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
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.84,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _sharedCardBackground,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: AppIconPickerDialog.iconWidgetForName(
                        record.icon,
                        color: accent,
                        size: 31,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_typeLabel(record)} · ${_executionLabel(record.executionType)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    record.isVariableIncome
                        ? 'متغير'
                        : record.amount.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Color(0xFF254034),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _DetailsTable(rows: _detailsRows(state, record)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openRecurringComposer(
                        mode: record.type,
                        editing: record,
                        subscriptionOnlyMode:
                            record.expensePlanKind == 'subscription',
                        debtOnlyMode: record.expensePlanKind == 'installment',
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.cubit.deleteRecurringTransaction(record.id);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
