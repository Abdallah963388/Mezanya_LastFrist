import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../widgets/transaction_details_sheet.dart';
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
        final records = state.recurringTransactions.where(_matchesTab).toList()
          ..sort((a, b) {
            final nameCompare = a.name.compareTo(b.name);
            if (nameCompare != 0) return nameCompare;
            return a.dayOfMonth.compareTo(b.dayOfMonth);
          });
        final inBudget = records
            .where((item) => item.budgetScope == 'within-budget')
            .toList();
        final outBudget = records
            .where((item) => item.budgetScope != 'within-budget')
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
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: _handleAddPressed,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_addButtonLabel()),
                ),
              ),
              const SizedBox(height: 16),
              if (_tab == 'subscriptions') ...[
                if (inBudget.isEmpty)
                  _emptyCard(_emptyScopeLabel())
                else
                  ...inBudget.map((record) => _recurringCard(state, record)),
              ] else
                _scopeSection(
                  state: state,
                  title: 'داخل الميزانية',
                  subtitle: _scopeSubtitle(),
                  records: inBudget,
                  emptyLabel: _emptyScopeLabel(),
                  accent: _currentAccent,
                ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesTab(RecurringTransactionEntity item) {
    if (_tab == 'subscriptions') {
      return item.type == 'expense' && item.expensePlanKind == 'subscription';
    }
    return item.type == 'expense' && item.expensePlanKind == 'installment';
  }

  Color get _currentAccent {
    if (_tab == 'subscriptions') return _subscriptionAccent;
    return _debtAccent;
  }

  String _tabTitle() {
    if (_tab == 'subscriptions') return 'الاشتراكات المتكررة';
    return 'الديون والأقساط';
  }

  String _addButtonLabel() {
    if (_tab == 'subscriptions') return 'إضافة اشتراك';
    return 'إضافة دين';
  }

  String _scopeSubtitle() {
    if (_tab == 'subscriptions') {
      return 'اشتراكاتك المرتبطة بالميزانية مثل خدمات البث والأدوات الدورية.';
    }
    return 'الديون والأقساط المرتبطة بخطة الميزانية.';
  }

  String _emptyScopeLabel() {
    if (_tab == 'subscriptions') {
      return 'لا توجد اشتراكات مسجلة حالياً.';
    }
    return 'لا توجد ديون أو أقساط مسجلة حالياً.';
  }

  void _handleAddPressed() {
    if (_tab == 'subscriptions') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubscriptionPresetSelectionScreen(
            cubit: widget.cubit,
          ),
          fullscreenDialog: true,
        ),
      );
      return;
    }
    _openRecurringComposer(
      mode: 'expense',
      initialExpensePlanKind: 'installment',
      debtOnlyMode: true,
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
                color: selected ? _currentAccent : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? _currentAccent : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scopeSection({
    required AppStateEntity state,
    required String title,
    required String subtitle,
    required List<RecurringTransactionEntity> records,
    required String emptyLabel,
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final total = records
        .where((item) => !item.isVariableIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.layers_rounded, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                total.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),
          if (records.isEmpty)
            _emptyCard(emptyLabel)
          else
            ...records.map((record) => _recurringCard(state, record)),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
                        subscriptionOnlyMode: record.expensePlanKind == 'subscription',
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
      'manual-variable' => 'يدوي متغير',
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
          initialExpensePlanKind: editing?.expensePlanKind ?? initialExpensePlanKind,
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
          color:
              Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65),
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
