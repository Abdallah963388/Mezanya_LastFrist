import 'package:flutter/material.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import 'recurring_transaction_composer_screen.dart';
import 'recurring_transactions_screen/helpers/recurring_transactions_screen_helper.dart';
import 'recurring_transactions_screen/sections/recurring_scope_section.dart';
import 'recurring_transactions_screen/sheets/recurring_transaction_details_sheet.dart';
import 'recurring_transactions_screen/widgets/recurring_add_button.dart';
import 'recurring_transactions_screen/widgets/recurring_type_switcher.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  static const Color _incomeAccent = Color(0xFF2F6F5E);
  static const Color _expenseAccent = Color(0xFFC65D2E);
  static const Color _sharedCardBackground = Color(0xFFF9F3E7);

  String _tab = 'expense';

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
        final inBudget = records.where((item) => item.budgetScope == 'within-budget').toList();
        final outBudget = records.where((item) => item.budgetScope != 'within-budget').toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            RecurringTypeSwitcher(
              tab: _tab,
              currentAccent: _currentAccent,
              onChanged: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: 14),
            RecurringAddButton(
              tab: _tab,
              onPressed: _handleAddPressed,
              expenseAccent: _expenseAccent,
              incomeAccent: _incomeAccent,
            ),
            const SizedBox(height: 16),
            RecurringScopeSection(
              state: state,
              title: 'داخل الميزانية',
              subtitle: RecurringTransactionsScreenHelper.scopeSubtitle(tab: _tab, withinBudget: true),
              records: inBudget,
              emptyLabel: RecurringTransactionsScreenHelper.emptyScopeLabel(tab: _tab, withinBudget: true),
              accent: _currentAccent,
              cardBackground: _sharedCardBackground,
              onRecordTap: (record) => _openDetailsSheet(state, record),
            ),
            const SizedBox(height: 14),
            RecurringScopeSection(
              state: state,
              title: 'عام',
              subtitle: RecurringTransactionsScreenHelper.scopeSubtitle(tab: _tab, withinBudget: false),
              records: outBudget,
              emptyLabel: RecurringTransactionsScreenHelper.emptyScopeLabel(tab: _tab, withinBudget: false),
              accent: _currentAccent,
              cardBackground: _sharedCardBackground,
              onRecordTap: (record) => _openDetailsSheet(state, record),
            ),
          ],
        );
      },
    );
  }

  bool _matchesTab(RecurringTransactionEntity item) {
    if (_tab == 'income') return item.type == 'income';
    return item.type == 'expense' && item.expensePlanKind != 'subscription' && item.expensePlanKind != 'installment';
  }

  Color get _currentAccent => _tab == 'income' ? _incomeAccent : _expenseAccent;

  void _handleAddPressed() {
    _openRecurringComposer(mode: _tab);
  }

  Future<void> _openDetailsSheet(AppStateEntity state, RecurringTransactionEntity record) async {
    await showRecurringTransactionDetailsSheet(
      context: context,
      cubit: widget.cubit,
      state: state,
      record: record,
      cardBackground: _sharedCardBackground,
      onEdit: () => _openRecurringComposer(
        mode: record.type,
        editing: record,
        subscriptionOnlyMode: record.expensePlanKind == 'subscription',
        debtOnlyMode: record.expensePlanKind == 'installment',
      ),
    );
  }

  Future<void> _openRecurringComposer({
    required String mode,
    RecurringTransactionEntity? editing,
    String? initialExpensePlanKind,
    bool subscriptionOnlyMode = false,
    bool debtOnlyMode = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: mode,
          initialRecurring: editing,
          initialWithinBudget: editing?.budgetScope == 'within-budget',
          initialExpensePlanKind: editing?.expensePlanKind ?? initialExpensePlanKind,
          allowDelete: editing != null,
          subscriptionOnlyMode: subscriptionOnlyMode,
          debtOnlyMode: debtOnlyMode,
        ),
      ),
    );
  }
}
