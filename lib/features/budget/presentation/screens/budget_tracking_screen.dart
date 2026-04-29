// ignore_for_file: no_wildcard_variable_uses

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/screens/recurring_transaction_composer_screen.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../domain/entities/budget_setup_entity.dart';
import 'budget_setup_screen.dart';

class BudgetTrackingScreen extends StatefulWidget {
  const BudgetTrackingScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _StaticInfoCard extends StatelessWidget {
  const _StaticInfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
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
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  /// [_cycleStart] = أول يوم في الدورة المعروضة حالياً
  late DateTime _cycleStart;
  bool _isIncomeExpanded = false;
  bool _processingAutomaticDebts = false;
  String? _dismissedAutoIncomeMonthKey;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    final budget = widget.cubit.state.budgetSetup;
    _cycleStart = budget.cycleStartFor(DateTime.now());
  }

  // ── الدورة الحالية ────────────────────────────────────────────────────────

  DateTime get _cycleEnd {
    final budget = widget.cubit.state.budgetSetup;
    return budget.cycleEndFor(_cycleStart);
  }

  /// للتوافق مع الكود القديم الذي يستخدم _month
  DateTime get _month => _cycleStart;

  void _goToPreviousCycle(BudgetSetupEntity budget) {
    setState(() {
      _cycleStart = DateTime(
        _cycleStart.year,
        _cycleStart.month - 1,
        budget.startDay.clamp(1, 28),
      );
    });
  }

  void _goToNextCycle(BudgetSetupEntity budget) {
    setState(() {
      _cycleStart = DateTime(
        _cycleStart.year,
        _cycleStart.month + 1,
        budget.startDay.clamp(1, 28),
      );
    });
  }

  bool _isCurrentCycle(BudgetSetupEntity budget) {
    final expected = budget.cycleStartFor(DateTime.now());
    return _cycleStart.year == expected.year &&
        _cycleStart.month == expected.month &&
        _cycleStart.day == expected.day;
  }

  bool _isFutureCycle(BudgetSetupEntity budget) {
    return _cycleStart.isAfter(budget.cycleStartFor(DateTime.now()));
  }

  bool _isPastCycle(BudgetSetupEntity budget) {
    return _cycleStart.isBefore(budget.cycleStartFor(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final budget = _budgetForMonth(state);
        final futureMonth = _isFutureMonth();
        final pastMonth = _isPastMonth();
        final hasBudgetPlan = _hasBudgetPlan(budget);
        final showSetupPromptOnly = futureMonth || !hasBudgetPlan;
        final budgetJars = budget.linkedWallets.toList();
        final monthTx = _monthTransactions(state.transactions);
        final incomeTx = monthTx.where((t) => t.type == 'income').toList();
        final expenseTx = monthTx.where((t) => t.type == 'expense').toList();
        final totalIncomeActual =
            incomeTx.fold<double>(0, (s, t) => s + t.amount);
        final totalExpenseActual =
            expenseTx.fold<double>(0, (s, t) => s + t.amount);
        final remainingIncome = totalIncomeActual - totalExpenseActual;
        // final totalDebts = budget.debts.fold<double>(0, (s, d) => s + d.amount);
        final isCurrentMonthView = _isCurrentCycle(budget);
        final hasPendingIncome =
            isCurrentMonthView && _hasPendingIncome(budget, incomeTx);
        final monthKey = budget.cycleKeyFor(_cycleStart);
        final shouldAutoExpandIncome =
            hasPendingIncome && _dismissedAutoIncomeMonthKey != monthKey;
        final isIncomeExpanded = _isIncomeExpanded || shouldAutoExpandIncome;
        // final isDebtExpanded = _isDebtExpanded || hasPendingDebt;
        if (isCurrentMonthView && hasBudgetPlan) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _processAutomaticDebts(state, budget, monthTx);
          });
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _monthBar(context),
            const SizedBox(height: 12),
            _heroSummaryCard(
              totalIncomeActual: totalIncomeActual,
              totalExpenseActual: totalExpenseActual,
              remainingIncome: remainingIncome,
            ),
            if (pastMonth) ...[
              const SizedBox(height: 14),
              _pastMonthSummaryCard(
                totalIncomeActual: totalIncomeActual,
                totalExpenseActual: totalExpenseActual,
                remainingIncome: remainingIncome,
              ),
            ],
            if (showSetupPromptOnly) ...[
              const SizedBox(height: 18),
              _budgetSetupPromptCard(futureMonth: futureMonth),
            ] else ...[
              const SizedBox(height: 18),
              _sectionTitle('الدخل'),
              const SizedBox(height: 12),
              _inlineSectionCard(
                title: 'الدخل الكلي',
                subtitle: 'كل مصادر الدخل المخطط لها لهذا الشهر',
                amount: totalIncomeActual,
                isExpanded: isIncomeExpanded,
                incomeTotalLayout: true,
                onTap: () {
                  setState(() {
                    if (isIncomeExpanded) {
                      _isIncomeExpanded = false;
                      if (hasPendingIncome) {
                        _dismissedAutoIncomeMonthKey = monthKey;
                      }
                    } else {
                      _isIncomeExpanded = true;
                      _dismissedAutoIncomeMonthKey = null;
                    }
                  });
                },
                expandedChildren:
                    _incomeInlineCards(state, budget, incomeTx, monthTx),
              ),
              const SizedBox(height: 18),
              _sectionTitle('المخصصات'),
              const SizedBox(height: 12),
              ...budget.allocations.isEmpty
                  ? <Widget>[
                      _sectionEmptyCard(
                        text: 'إعداد الميزانية الشهرية',
                        onTap: futureMonth || !pastMonth
                            ? _openBudgetSetupScreen
                            : null,
                      ),
                    ]
                  : budget.allocations.map((allocation) =>
                      _allocationSummaryTile(state, allocation, monthTx)),
              const SizedBox(height: 18),
              _sectionTitle('الحصالات'),
              const SizedBox(height: 12),
              ...budgetJars.isEmpty
                  ? const <Widget>[
                      _StaticInfoCard(
                          text: 'لا توجد حصالات ممولة في هذا الشهر.')
                    ]
                  : budgetJars
                      .map((jar) => _jarSummaryTile(state, jar, monthTx)),
              const SizedBox(height: 18),
              _sectionTitle('الديون'),
              const SizedBox(height: 12),
              ..._debtInlineCards(state, budget, monthTx),
              const SizedBox(height: 18),
              _sectionTitle('الملخص'),
              const SizedBox(height: 12),
              _summaryBreakdownCard(budget: budget),
              if (!pastMonth) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openBudgetSetupScreen,
                  icon: Icon(futureMonth
                      ? Icons.add_task_outlined
                      : Icons.edit_outlined),
                  label: Text(futureMonth
                      ? 'إعداد الميزانية الشهرية'
                      : 'تعديل الميزانية الشهرية'),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _monthBar(BuildContext context) {
    final budget = widget.cubit.state.budgetSetup;
    final cycleEnd = _cycleEnd;
    // عرض نطاق الدورة: "5 أبريل — 4 مايو 2025"
    final startLabel = DateFormat('d MMM', 'ar').format(_cycleStart);
    final endLabel = DateFormat('d MMM yyyy', 'ar').format(cycleEnd);
    final rangeLabel = '$startLabel — $endLabel';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _goToPreviousCycle(budget),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(rangeLabel,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            IconButton(
              onPressed: () => _goToNextCycle(budget),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  List<TransactionEntity> _monthTransactions(List<TransactionEntity> tx) {
    final end = _cycleEnd;
    return tx
        .where((t) =>
            !t.createdAt.isBefore(_cycleStart) &&
            !t.createdAt.isAfter(end) &&
            !_isJarReserveTx(t))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  BudgetSetupEntity _budgetForMonth(AppStateEntity state) {
    final budget = state.budgetSetup;
    final cycleKey = budget.cycleKeyFor(_cycleStart);

    // جرب الـ snapshot الجديد بمفتاح الدورة
    final cycleSnapshot = state.monthlyBudgetSnapshots[cycleKey];
    if (cycleSnapshot != null && cycleSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(cycleSnapshot);
    }

    // fallback: مفتاح الشهر القديم للتوافق مع البيانات السابقة
    final oldKey = '${_cycleStart.year}-${_cycleStart.month.toString().padLeft(2, '0')}';
    final oldSnapshot = state.monthlyBudgetSnapshots[oldKey];
    if (oldSnapshot != null && oldSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(oldSnapshot);
    }

    if (_isCurrentCycle(budget)) return state.budgetSetup;

    final end = _cycleEnd;
    for (final log in state.logs) {
      if (log.timestamp.isAfter(end)) continue;
      try {
        final map = jsonDecode(log.afterState) as Map<String, dynamic>;
        return AppStateEntity.fromMap(map).budgetSetup;
      } catch (_) {
        continue;
      }
    }
    return state.budgetSetup;
  }

  bool _isFutureMonth() => _isFutureCycle(widget.cubit.state.budgetSetup);

  bool _isPastMonth() => _isPastCycle(widget.cubit.state.budgetSetup);

  bool _hasBudgetPlan(BudgetSetupEntity budget) {
    return budget.allocations.isNotEmpty;
  }

  void _openBudgetSetupScreen() {
    final futureMonth = _isFutureMonth();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              futureMonth ? 'إعداد خطة الشهر القادم' : 'تعديل خطة الميزانية',
            ),
          ),
          body: BudgetSetupScreen(
            cubit: widget.cubit,
            displayMonth: _month,
          ),
        ),
      ),
    );
  }

  Widget _heroSummaryCard({
    required double totalIncomeActual,
    required double totalExpenseActual,
    required double remainingIncome,
  }) {
    final theme = Theme.of(context);
    final positive = remainingIncome >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? const [Color(0xFF165B47), Color(0xFF2F7D5E), Color(0xFF8DCB9B)]
              : const [Color(0xFF8E4A37), Color(0xFFC96B47)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF165B47).withValues(alpha: 0.20),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -14,
            start: -4,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 92,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          PositionedDirectional(
            bottom: -18,
            end: -4,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 82,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الباقي من الدخل الشهري',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                remainingIncome.toStringAsFixed(2),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _heroMiniStat(
                      label: 'الدخل',
                      value: totalIncomeActual,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _heroMiniStat(
                      label: 'المصروف',
                      value: totalExpenseActual,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMiniStat({
    required String label,
    required double value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastMonthSummaryCard({
    required double totalIncomeActual,
    required double totalExpenseActual,
    required double remainingIncome,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص هذا الشهر',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'هذا الشهر للعرض فقط. يمكنك مراجعة ما حدث داخل الخطة والمعاملات.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          _row('إجمالي الدخل', totalIncomeActual),
          _row('إجمالي المصروف', totalExpenseActual),
          _row('الصافي النهائي', remainingIncome, danger: remainingIncome < 0),
        ],
      ),
    );
  }

  Widget _budgetSetupPromptCard({required bool futureMonth}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFD8F3E5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 42,
              color: Color(0xFF0F9D7A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            futureMonth
                ? 'خطط لهذا الشهر بشكل مسبق'
                : 'ابدأ إعداد الميزانية الشهرية',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            futureMonth
                ? 'هذا الشهر لم يبدأ بعد. يمكنك تجهيز خطته الآن، لكنها لن تتحول إلى عرض الميزانية والمعاملات إلا عندما يبدأ الشهر فعليًا.'
                : 'بدون مخصصات لن تظهر خطة الميزانية. جهز دخلك ومخصصاتك أولًا ثم راجع الشهر من هنا.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isPastMonth() ? null : _openBudgetSetupScreen,
            icon: const Icon(Icons.tune_rounded),
            label: Text(
              futureMonth
                  ? 'إعداد هذا الشهر مسبقًا'
                  : 'إعداد الميزانية الشهرية',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(
          color: Theme.of(context).colorScheme.outlineVariant,
          thickness: 1,
          height: 1,
        ),
      ],
    );
  }

  Widget _sectionEmptyCard({
    required String text,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.open_in_new_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryBreakdownCard({required BudgetSetupEntity budget}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('المبلغ غير المخصص', budget.unallocatedAmount),
          _row(
            'التوفير المتوقع',
            budget.bufferEndBehavior == 'to-savings'
                ? budget.unallocatedAmount.clamp(0, double.infinity).toDouble()
                : 0,
          ),
        ],
      ),
    );
  }

  Widget _entityTile({
    required String title,
    required Widget leading,
    required String amountText,
    required String metaText,
    required VoidCallback onTap,
    String? supportingText,
    Widget? supportingCustom,
    String? trailingTopText,
    List<Widget> actions = const <Widget>[],
    double? progress,
    Color? progressColor,
    Color? tint,
    bool compactMeta = false,
    bool embeddedInIncomeCard = false,
  }) {
    final theme = Theme.of(context);
    final tileTint = tint ?? theme.colorScheme.surface;
    final accentStrip = tint ?? const Color(0xFF0F9D7A);
    final decoration = embeddedInIncomeCard
        ? BoxDecoration(
            color: accentStrip.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentStrip.withValues(alpha: 0.22),
            ),
          )
        : BoxDecoration(
            color: tint == null
                ? theme.colorScheme.surface
                : tileTint.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: tint == null
                  ? theme.colorScheme.outlineVariant
                  : tileTint.withValues(alpha: 0.24),
            ),
          );
    final radius = embeddedInIncomeCard ? 18.0 : 24.0;
    return Container(
      margin: EdgeInsets.only(bottom: embeddedInIncomeCard ? 8 : 10),
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              embeddedInIncomeCard ? 12 : 14,
              embeddedInIncomeCard ? 12 : 14,
              embeddedInIncomeCard ? 12 : 14,
              embeddedInIncomeCard ? 12 : 14,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),

                              // if (trailingTopText != null)
                              //   Text(
                              //     trailingTopText,
                              //     style: TextStyle(
                              //       fontSize: 12,
                              //       color: theme.colorScheme.onSurfaceVariant,
                              //       fontWeight: FontWeight.w700,
                              //     ),
                              //   ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compactMeta ? 11 : 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: compactMeta
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                          if (supportingCustom != null) ...[
                            const SizedBox(height: 4),
                            supportingCustom,
                          ] else if (supportingText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              supportingText,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 6),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      color: progressColor ?? theme.colorScheme.primary,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        Expanded(child: actions[i]),
                        if (i != actions.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBadge(String iconName, String colorHex, {double size = 54}) {
    final color = _colorFromHex(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: AppIconPickerDialog.iconWidgetForName(
          iconName,
          color: color,
          size: size * 0.42,
        ),
      ),
    );
  }

  String _monthWordLabel(DateTime date) {
    return DateFormat('d MMMM', 'ar').format(date);
  }

  String _recurrenceLabel(String pattern) => switch (pattern) {
        'daily' => 'يومي',
        'weekly' => 'أسبوعي',
        'biweekly' => 'كل أسبوعين',
        'every_3_weeks' => 'كل 3 أسابيع',
        'monthly' => 'شهري',
        'every_2_months' => 'كل شهرين',
        'every_3_months' => 'كل 3 شهور',
        'every_6_months' => 'كل 6 شهور',
        'yearly' => 'سنوي',
        _ => pattern,
      };

  Color _colorFromHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF0F9D7A);
  }

  Color _usageProgressColor(double ratio) {
    final value = ratio.clamp(0.0, 1.0).toDouble();
    if (value <= 0.4) {
      return Color.lerp(
            const Color(0xFF1D8F62),
            const Color(0xFFE4B83F),
            value / 0.4,
          ) ??
          const Color(0xFF1D8F62);
    }
    if (value <= 0.7) {
      return Color.lerp(
            const Color(0xFFE4B83F),
            const Color(0xFFE78A2E),
            (value - 0.4) / 0.3,
          ) ??
          const Color(0xFFE4B83F);
    }
    return Color.lerp(
          const Color(0xFFE78A2E),
          const Color(0xFFC63D32),
          (value - 0.7) / 0.3,
        ) ??
        const Color(0xFFC63D32);
  }

  // Widget _trackingSheetGrabHandle(ThemeData theme) {
  //   return Center(
  //     child: Container(
  //       width: 40,
  //       height: 4,
  //       margin: const EdgeInsets.only(bottom: 14),
  //       decoration: BoxDecoration(
  //         color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
  //         borderRadius: BorderRadius.circular(999),
  //       ),
  //     ),
  //   );
  // }

  // Widget _trackingSheetTransactionsHeader(ThemeData theme) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Divider(
  //         height: 32,
  //         thickness: 1,
  //         color: theme.colorScheme.outlineVariant,
  //       ),
  //       Text(
  //         'معاملات الشهر',
  //         style: theme.textTheme.titleSmall?.copyWith(
  //           fontWeight: FontWeight.w900,
  //         ),
  //       ),
  //       const SizedBox(height: 10),
  //     ],
  //   );
  // }

  Widget _trackingDetailHeroShell({
    required Color accent,
    required List<Widget> children,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onEdit != null)
            Align(
              alignment: Alignment.topLeft,
              child: IconButton.filledTonal(
                onPressed: onEdit,
                tooltip: 'تعديل',
                icon: const Icon(Icons.settings_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  foregroundColor: accent,
                ),
              ),
            ),
          if (onEdit != null) const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _trackingMonthTransactionTile(
    BuildContext sheetContext,
    ThemeData theme,
    TransactionEntity item,
  ) {
    final isIncome = item.type == 'income';
    final isExpense = item.type == 'expense';
    final amtColor = isIncome
        ? const Color(0xFF0F9D7A)
        : (isExpense ? theme.colorScheme.error : theme.colorScheme.primary);
    final icon = isIncome
        ? Icons.add_rounded
        : (isExpense ? Icons.remove_rounded : Icons.swap_horiz_rounded);
    final defaultTitle = isIncome ? 'دخل' : (isExpense ? 'مصروف' : 'تحويل');
    final prefix = isIncome ? '+' : (isExpense ? '-' : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.pop(sheetContext);
            final parentContext = context;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              openTransactionDetailsSheet(
                parentContext,
                cubit: widget.cubit,
                transaction: item,
              );
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: amtColor.withValues(alpha: 0.14),
                  child: Icon(icon, color: amtColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.notes?.isNotEmpty == true
                            ? item.notes!
                            : defaultTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMMM · h:mm a', 'ar')
                            .format(item.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: amtColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _trackingSheetTxList(
  //   BuildContext sheetContext,
  //   ThemeData theme,
  //   List<TransactionEntity> transactions,
  //   String emptyMessage,
  // ) {
  //   return Column(
  //     children: [
  //       ...transactions.map(
  //         (item) => _trackingMonthTransactionTile(sheetContext, theme, item),
  //       ),
  //       if (transactions.isEmpty)
  //         Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 12),
  //           child: Text(
  //             emptyMessage,
  //             style: TextStyle(
  //               color: theme.colorScheme.onSurfaceVariant,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //         ),
  //     ],
  //   );
  // }

  Widget _inlineSectionCard({
    required String title,
    required String subtitle,
    required double amount,
    required bool isExpanded,
    required VoidCallback onTap,
    List<Widget> expandedChildren = const <Widget>[],
    bool incomeTotalLayout = false,
  }) {
    final theme = Theme.of(context);
    final accent = title == 'الدخل الكلي'
        ? const Color(0xFF0F9D7A)
        : const Color(0xFFC65D2E);
    final shellColor = incomeTotalLayout
        ? accent.withValues(alpha: isExpanded ? 0.12 : 0.08)
        : accent.withValues(alpha: 0.10);
    final shellBorder = incomeTotalLayout
        ? accent.withValues(alpha: isExpanded ? 0.28 : 0.16)
        : accent.withValues(alpha: 0.22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            incomeTotalLayout ? 18 : 16,
            incomeTotalLayout ? 18 : 16,
            incomeTotalLayout ? 18 : 16,
            incomeTotalLayout ? 16 : 14,
          ),
          decoration: BoxDecoration(
            color: shellColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: shellBorder),
            boxShadow: incomeTotalLayout
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isExpanded ? 0.12 : 0.07),
                      blurRadius: isExpanded ? 26 : 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: incomeTotalLayout
                                      ? theme.colorScheme.onSurface
                                      : accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              amount.toStringAsFixed(2),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: incomeTotalLayout
                                    ? accent.withValues(alpha: 0.96)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: accent,
                    size: 28,
                  ),
                ],
              ),
              if (isExpanded && expandedChildren.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(top: incomeTotalLayout ? 16 : 14),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: accent.withValues(alpha: 0.14),
                  ),
                ),
                if (incomeTotalLayout) const SizedBox(height: 12),
                incomeTotalLayout
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: expandedChildren,
                        ),
                      )
                    : _sectionCurtainBody(children: expandedChildren),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCurtainBody({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.32),
        ),
      ),
      child: Column(children: children),
    );
  }

  bool _hasPendingIncome(
    BudgetSetupEntity budget,
    List<TransactionEntity> incomeTx,
  ) {
    final state = widget.cubit.state;
    for (final source in budget.incomeSources) {
      final sourceTx =
          incomeTx.where((t) => t.incomeSourceId == source.id).toList();
      final pendingMeta = _incomePendingMeta(state, source, sourceTx);
      if (pendingMeta?['pending'] == true) {
        return true;
      }
    }
    return false;
  }

  // bool _hasPendingDebt(
  //   AppStateEntity state,
  //   BudgetSetupEntity budget,
  //   List<TransactionEntity> monthTx,
  // ) {
  //   for (final debt in budget.debts) {
  //     final recurring = _linkedRecurringDebt(state, debt);
  //     final tx = monthTx.where((t) => t.notes?.contains(debt.name) == true);
  //     final paid = tx.fold<double>(0, (s, t) => s + t.amount);
  //     final remaining = (debt.amount - paid).clamp(0.0, debt.amount);
  //     final pendingMeta = _expensePendingMeta(recurring);
  //     if (pendingMeta?['pending'] == true && remaining > 0) {
  //       return true;
  //     }
  //   }
  //   return false;
  // }

  bool _isCurrentMonthView() =>
      _isCurrentCycle(widget.cubit.state.budgetSetup);

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
    if (linked.isEmpty) {
      return null;
    }
    return linked.first;
  }

  Map<String, dynamic>? _incomePendingMeta(
    AppStateEntity state,
    IncomeSourceEntity source,
    List<TransactionEntity> sourceTx,
  ) {
    if (source.isVariable || sourceTx.isNotEmpty || !_isCurrentMonthView()) {
      return null;
    }
    final recurring = _linkedRecurringIncome(state, source);
    final dueDate = _incomeDueDateForMonth(source, _month);
    final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
    final canEarly = reminderLeadDays > 0 &&
        !today.isBefore(reminderDate) &&
        today.isBefore(dueDate);
    final isDueOrLate = !today.isBefore(dueDate);
    if (!canEarly && !isDueOrLate) return null;

    // ── snooze check ──────────────────────────────────────────────────────
    if (source.isSnoozed) {
      final until = source.snoozedUntilDate!;
      return <String, dynamic>{
        'pending': false,
        'snoozed': true,
        'canEarly': false,
        'isDueOrLate': isDueOrLate,
        'status': 'مؤجل حتى ${DateFormat('d/M - HH:mm', 'ar').format(until)}',
        'dateLabel': '${dueDate.day}/${dueDate.month}',
        'timeLabel': null,
      };
    }

    final dateLabel = '${dueDate.day}/${dueDate.month}';
    final timeLabel = recurring?.scheduledTime?.isNotEmpty == true
        ? recurring!.scheduledTime!
        : null;
    final status = isDueOrLate
        ? 'مستحق الآن • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}'
        : 'بكر • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}';
    return <String, dynamic>{
      'pending': true,
      'snoozed': false,
      'canEarly': canEarly,
      'isDueOrLate': isDueOrLate,
      'status': status,
      'dateLabel': dateLabel,
      'timeLabel': timeLabel,
    };
  }

  Widget _compactActionButton({
    required String label,
    required VoidCallback onPressed,
    bool filled = true,
  }) {
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(label),
          );
  }

  double _incomeDisplayPool(IncomeSourceEntity source, double received) {
    if (source.isVariable) return 0;
    return received > 0 ? received : source.amount;
  }

  double _spentAttributedToIncomeSource(
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
    String incomeSourceId,
  ) {
    final counted = <String>{};
    var total = 0.0;

    for (final alloc in budget.allocations) {
      final fromThis = alloc.funding
          .where((f) => f.incomeSourceId == incomeSourceId)
          .fold<double>(0, (s, f) => s + f.plannedAmount);
      if (fromThis <= 0) continue;
      final plannedTotal =
          alloc.funding.fold<double>(0, (s, f) => s + f.plannedAmount);
      if (plannedTotal <= 0) continue;
      final share = fromThis / plannedTotal;
      for (final t in monthTx
          .where((x) => x.type == 'expense' && x.allocationId == alloc.id)) {
        counted.add(t.id);
        total += t.amount * share;
      }
    }

    for (final debt in budget.debts) {
      if (debt.fundingSource != incomeSourceId) continue;
      for (final t in monthTx.where(
          (x) => x.type == 'expense' && x.notes?.contains(debt.name) == true)) {
        if (!counted.contains(t.id)) {
          counted.add(t.id);
          total += t.amount;
        }
      }
    }

    return total;
  }

  double? _incomeRemainingProgress(
    IncomeSourceEntity source,
    double received,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    if (source.isVariable) return null;
    final pool = _incomeDisplayPool(source, received);
    if (pool <= 0) return null;
    final spent = _spentAttributedToIncomeSource(budget, monthTx, source.id);
    final ratio = ((pool - spent) / pool).clamp(0.0, 1.0);
    return ratio;
  }

  List<TransactionEntity> _monthTransactionsForIncomeSource(
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
    IncomeSourceEntity source,
    List<TransactionEntity> sourceIncomeTx,
  ) {
    final allocIds = budget.allocations
        .where((a) => a.funding.any((f) => f.incomeSourceId == source.id))
        .map((a) => a.id)
        .toSet();
    final debtNames = budget.debts
        .where((d) => d.fundingSource == source.id)
        .map((d) => d.name)
        .toSet();

    final out = <TransactionEntity>[
      ...sourceIncomeTx,
      ...monthTx.where((t) =>
          t.type == 'expense' &&
          t.allocationId != null &&
          allocIds.contains(t.allocationId)),
      ...monthTx.where((t) =>
          t.type == 'expense' &&
          debtNames.any((n) => t.notes?.contains(n) == true)),
    ];

    final seen = <String>{};
    final deduped = <TransactionEntity>[];
    for (final t in out) {
      if (seen.add(t.id)) deduped.add(t);
    }
    deduped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deduped;
  }

  List<Widget> _incomeInlineCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> incomeTx,
    List<TransactionEntity> monthTx,
  ) {
    return [
      ...budget.incomeSources.map((source) {
        final sourceTx =
            incomeTx.where((t) => t.incomeSourceId == source.id).toList();
        final received = sourceTx.fold<double>(0, (s, t) => s + t.amount);
        final recurring = _linkedRecurringIncome(state, source);
        final pendingMeta = _incomePendingMeta(state, source, sourceTx);
        final displayedAmount = received <= 0 ? source.amount : received;
        final pool = _incomeDisplayPool(source, received);
        final spent =
            _spentAttributedToIncomeSource(budget, monthTx, source.id);
        final afterSpend = (pool - spent).clamp(0.0, pool);
        final remProgress =
            _incomeRemainingProgress(source, received, budget, monthTx);
        final incomeProgressColor = remProgress == null
            ? const Color(0xFF0F9D7A)
            : _usageProgressColor(1 - remProgress);
        return _entityTile(
          title: source.name,
          leading: _iconBadge(
            recurring?.icon ?? 'cash',
            recurring?.iconColor ?? '#0f9d7a',
            size: 56,
          ),
          amountText: displayedAmount.truncate().toString(),
          metaText: source.isVariable
              ? 'غير ثابت'
              : _monthWordLabel(_incomeDueDateForMonth(source, _month)),
          trailingTopText: recurring?.scheduledTime?.isNotEmpty == true
              ? recurring!.scheduledTime!
              : null,
          supportingText: source.isVariable ? 'دخل غير ثابت' : null,
          supportingCustom: source.isVariable
              ? null
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'الباقي',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      afterSpend.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
          tint: const Color(0xFF0F9D7A),
          compactMeta: source.isVariable,
          progress: remProgress,
          progressColor: incomeProgressColor,
          embeddedInIncomeCard: true,
          onTap: () =>
              _openIncomeDetailsSheet(source, sourceTx, budget, monthTx),
          actions: pendingMeta == null
              ? const <Widget>[]
              : <Widget>[
                  if (pendingMeta['canEarly'] == true)
                    _compactActionButton(
                      label: 'بكر',
                      filled: false,
                      onPressed: () =>
                          _recordIncomeFromTracking(source, early: true),
                    ),
                  if (pendingMeta['isDueOrLate'] == true)
                    _compactActionButton(
                      label: 'نزول',
                      onPressed: () => _recordIncomeFromTracking(source),
                    ),
                  if (pendingMeta['isDueOrLate'] == true)
                    _compactActionButton(
                      label: 'تأجيل',
                      filled: false,
                      onPressed: () => _postponeIncome(source),
                    ),
                ],
        );
      }),
      ...incomeTx.where((t) => t.incomeSourceId == null).map(
            (t) => _entityTile(
              title: t.notes?.isNotEmpty == true ? t.notes! : 'دخل إضافي',
              leading: _iconBadge('cash', '#0f9d7a', size: 56),
              amountText: t.amount.toStringAsFixed(2),
              metaText: DateFormat('d MMMM', 'ar').format(t.createdAt),
              trailingTopText: DateFormat('HH:mm', 'ar').format(t.createdAt),
              tint: const Color(0xFF0F9D7A),
              embeddedInIncomeCard: true,
              onTap: () => _openTxSheet(title: 'دخل إضافي', tx: [t]),
            ),
          ),
    ];
  }

  Widget _allocationSummaryTile(AppStateEntity state,
      AllocationEntity allocation, List<TransactionEntity> monthTx) {
    final planned =
        allocation.funding.fold<double>(0, (s, f) => s + f.plannedAmount);
    final funded = allocation.funding.fold<double>(0, (sum, f) {
      final incomeReceived = monthTx
          .where(
              (t) => t.type == 'income' && t.incomeSourceId == f.incomeSourceId)
          .fold<double>(0, (s, t) => s + t.amount);
      return sum +
          (incomeReceived <= f.plannedAmount
              ? incomeReceived
              : f.plannedAmount);
    });
    final spent = monthTx
        .where((t) => t.type == 'expense' && t.allocationId == allocation.id)
        .fold<double>(0, (s, t) => s + t.amount);
    final remaining = funded - spent;
    final ratio = funded <= 0 ? 0.0 : (remaining / funded).clamp(0.0, 1.0);
    final color = _usageProgressColor(1 - ratio);

    return _entityTile(
      title: allocation.name,
      leading: _iconBadge(allocation.icon, allocation.iconColor, size: 54),
      amountText: remaining.toStringAsFixed(2),
      metaText: 'المخطط ${planned.toStringAsFixed(2)}',
      supportingText: 'المتاح ${funded.toStringAsFixed(2)}',
      progress: ratio,
      progressColor: color,
      onTap: () => _openAllocationSheet(state, allocation, monthTx),
    );
  }

  Widget _jarSummaryTile(AppStateEntity state, LinkedWalletEntity jar,
      List<TransactionEntity> monthTx) {
    return _entityTile(
      title: jar.name,
      leading: _iconBadge(jar.icon, jar.iconColor, size: 54),
      amountText: jar.balance.toStringAsFixed(2),
      metaText: 'المخصص الشهري ${jar.monthlyAmount.toStringAsFixed(2)}',
      supportingText: 'إجمالي رصيد الحصالة',
      progress: jar.monthlyAmount <= 0
          ? null
          : (monthTx
                      .where((t) => t.type == 'expense' && t.walletId == jar.id)
                      .fold<double>(0, (s, t) => s + t.amount) /
                  jar.monthlyAmount)
              .clamp(0.0, 1.0)
              .toDouble(),
      progressColor: jar.monthlyAmount <= 0
          ? null
          : _usageProgressColor((monthTx
                      .where((t) => t.type == 'expense' && t.walletId == jar.id)
                      .fold<double>(0, (s, t) => s + t.amount) /
                  jar.monthlyAmount)
              .clamp(0.0, 1.0)
              .toDouble()),
      onTap: () => _openJarSheet(state, jar, monthTx),
    );
  }

  List<Widget> _debtInlineCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    // نفصل الأقساط عن الاشتراكات
    final installments = budget.debts.where((d) => d.isInstallment).toList();
    final subscriptions = budget.debts.where((d) => d.isSubscription).toList();

    final widgets = <Widget>[];

    // ── الأقساط ────────────────────────────────────────────────────────────
    for (final debt in installments) {
      final recurring = _linkedRecurringDebt(state, debt);
      final allDebtTx = _allDebtPayments(state, debt);
      final paid = allDebtTx.fold<double>(0, (s, t) => s + t.amount);
      final principal = debt.principalTotal ?? debt.amount;
      final remaining = (principal - paid).clamp(0.0, principal);
      final paidRatio =
          principal <= 0 ? 0.0 : (paid / principal).clamp(0.0, 1.0);
      final pct = (paidRatio * 100).round().clamp(0, 100);
      final monthPaid = monthTx
          .where((t) => _transactionCountsTowardDebt(t, debt))
          .fold<double>(0, (s, t) => s + t.amount);
      final pendingMeta = _expensePendingMeta(recurring);
      final isPending =
          pendingMeta?['pending'] == true && monthPaid < debt.amount;
      final remainingInstallments = debt.amount > 0
          ? ((remaining - monthPaid) / debt.amount).ceil()
          : 0;

      widgets.add(_entityTile(
        title: debt.name,
        leading: _iconBadge(
          recurring?.icon ?? 'receipt',
          recurring?.iconColor ?? '#c65d2e',
          size: 54,
        ),
        amountText: remaining.toStringAsFixed(2),
        metaText:
            '$pct% مسدد · القسط ${debt.amount.toStringAsFixed(2)} · ${remainingInstallments > 0 ? '$remainingInstallments قسط متبقي' : 'مكتمل'}',
        supportingText: 'الأصل ${principal.toStringAsFixed(2)}',
        progress: paidRatio,
        progressColor: Colors.green,
        tint: isPending ? const Color(0xFFC65D2E) : null,
        onTap: () => _openDebtDetailsSheet(debt, allDebtTx, remaining),
        actions: isPending && recurring != null
            ? <Widget>[
                _compactActionButton(
                  label: 'تأكيد الخصم',
                  onPressed: () {
                    _confirmDebtPayment(state, budget, debt, recurring);
                  },
                ),
              ]
            : <Widget>[],
      ));
    }

    // ── الاشتراكات ──────────────────────────────────────────────────────────
    for (final debt in subscriptions) {
      final recurring = _linkedRecurringDebt(state, debt);
      final isDueThisCycle =
          debt.isDueInCycle(_cycleStart, _cycleEnd);
      final cyclePaid = monthTx
          .where((t) => _transactionCountsTowardDebt(t, debt))
          .fold<double>(0, (s, t) => s + t.amount);
      final cycleDue = debt.amountDueInCycle(_cycleStart, _cycleEnd);
      final pendingMeta = isDueThisCycle ? _expensePendingMeta(recurring) : null;
      final isPending = pendingMeta?['pending'] == true && cyclePaid < cycleDue;

      // الاشتراكات السنوية غير المستحقة في الدورة الحالية تظهر بشكل مختلف
      final isNotDueYet = !isDueThisCycle;
      final nextDue = recurring != null
          ? _nextRecurringOccurrence(recurring, DateTime.now())
          : null;
      final nextDueLabel = nextDue != null
          ? 'الاستحقاق القادم: ${_monthWordLabel(nextDue)}'
          : _recurrenceLabel(debt.recurrencePattern);

      widgets.add(_entityTile(
        title: debt.name,
        leading: _iconBadge(
          recurring?.icon ?? 'subscriptions',
          recurring?.iconColor ?? '#4a7c59',
          size: 54,
        ),
        amountText: debt.amount.toStringAsFixed(2),
        metaText: isNotDueYet
            ? nextDueLabel
            : (cyclePaid >= cycleDue
                ? 'تم الدفع ✓'
                : 'مستحق · ${debt.amount.toStringAsFixed(2)}'),
        supportingText: _recurrenceLabel(debt.recurrencePattern),
        progress: isNotDueYet
            ? null
            : (cycleDue <= 0
                ? null
                : (cyclePaid / cycleDue).clamp(0.0, 1.0).toDouble()),
        progressColor: Colors.teal,
        tint: isPending ? const Color(0xFFC65D2E) : null,
        onTap: () => _openDebtDetailsSheet(debt, monthTx, cycleDue - cyclePaid),
        actions: isPending && recurring != null
            ? <Widget>[
                _compactActionButton(
                  label: 'تأكيد الدفع',
                  onPressed: () =>
                      _confirmDebtPayment(state, budget, debt, recurring),
                ),
              ]
            : const <Widget>[],
      ));
    }

    if (widgets.isEmpty) {
      widgets.add(const _StaticInfoCard(text: 'لا توجد ديون أو اشتراكات.'));
    }

    return widgets;
  }

  Future<void> _openAllocationSheet(
    AppStateEntity state,
    AllocationEntity allocation,
    List<TransactionEntity> monthTx,
  ) async {
    final theme = Theme.of(context);
    final accent = _colorFromHex(allocation.iconColor);
    final planned = allocation.funding.fold<double>(
      0,
      (s, f) => s + f.plannedAmount,
    );
    final funded = allocation.funding.fold<double>(0, (sum, f) {
      final incomeReceived = monthTx
          .where(
              (t) => t.type == 'income' && t.incomeSourceId == f.incomeSourceId)
          .fold<double>(0, (s, t) => s + t.amount);
      return sum +
          (incomeReceived <= f.plannedAmount
              ? incomeReceived
              : f.plannedAmount);
    });
    final spent = monthTx
        .where((t) => t.type == 'expense' && t.allocationId == allocation.id)
        .fold<double>(0, (s, t) => s + t.amount);
    final remaining = funded - spent;
    final ratio = funded <= 0 ? 0.0 : (remaining / funded).clamp(0.0, 1.0);
    final progressColor = _usageProgressColor(1 - ratio);
    final tx = state.transactions
        .where((t) => !_isJarReserveTx(t) && t.allocationId == allocation.id)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _DraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: tx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات لهذا المخصص في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          _trackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _editAllocation(allocation);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconBadge(allocation.icon, allocation.iconColor, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allocation.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المخطط ${planned.toStringAsFixed(2)} · المتاح ${funded.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remaining.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'المصروف حتى الآن: ${spent.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: progressColor,
                  backgroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAllocation(AllocationEntity _) async {
    final state = widget.cubit.state;
    final budget = _budgetForMonth(state);
    final result = await openAllocationEditorScreen(
      context,
      current: _,
      incomeSources: budget.incomeSources,
      idFactory: _id,
    );
    if (result == null) return;
    if (result.deleteRequested) {
      final next = budget.allocations.where((e) => e.id != _.id).toList();
      await widget.cubit.updateBudgetSetup(
        budget.copyWith(allocations: next),
      );
      return;
    }

    final updated = result.entity;
    if (updated == null) return;
    final next =
        budget.allocations.map((e) => e.id == _.id ? updated : e).toList();
    await widget.cubit.updateBudgetSetup(
      budget.copyWith(allocations: next),
    );
  }

  Future<void> _openJarSheet(
    AppStateEntity state,
    LinkedWalletEntity jar,
    List<TransactionEntity> monthTx,
  ) async {
    final theme = Theme.of(context);
    final accent = _colorFromHex(jar.iconColor);
    final spentFromJar = monthTx
        .where((t) => t.type == 'expense' && t.walletId == jar.id)
        .fold<double>(0, (s, t) => s + t.amount);
    final ratio = jar.monthlyAmount <= 0
        ? null
        : (spentFromJar / jar.monthlyAmount).clamp(0.0, 1.0);
    final progressColor =
        ratio == null ? theme.colorScheme.primary : _usageProgressColor(ratio);
    final tx = state.transactions
        .where((t) =>
            !_isJarReserveTx(t) &&
            (t.walletId == jar.id ||
                t.toWalletId == jar.id ||
                t.fromWalletId == jar.id))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _DraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: tx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات مرتبطة بهذه الحصالة في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          _trackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _openBudgetSetupScreen();
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconBadge(jar.icon, jar.iconColor, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jar.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المخصص الشهري ${jar.monthlyAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    jar.balance.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'المصروف من الحصالة هذا الشهر: ${spentFromJar.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (ratio != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    color: progressColor,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openIncomeDetailsSheet(
    IncomeSourceEntity source,
    List<TransactionEntity> sourceIncomeTx,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) async {
    final theme = Theme.of(context);
    const accent = Color(0xFF0F9D7A);
    final dueDate = _incomeDueDateForMonth(source, _month);
    final received = sourceIncomeTx.fold<double>(0, (s, t) => s + t.amount);
    final displayedAmount = received <= 0 ? source.amount : received;
    final pool = _incomeDisplayPool(source, received);
    final spent = _spentAttributedToIncomeSource(budget, monthTx, source.id);
    final afterSpend = (pool - spent).clamp(0.0, pool);
    final remProgress =
        _incomeRemainingProgress(source, received, budget, monthTx);
    final pendingMeta =
        _incomePendingMeta(widget.cubit.state, source, sourceIncomeTx);
    final canEarly = pendingMeta?['canEarly'] == true;
    final isDueOrLate = pendingMeta?['isDueOrLate'] == true;
    final recurring = _linkedRecurringIncome(widget.cubit.state, source);
    final cycleTx = _monthTransactionsForIncomeSource(
        budget, monthTx, source, sourceIncomeTx);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _DraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: cycleTx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات مرتبطة بهذا الدخل في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          _trackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _editIncomeDirect(source);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconBadge(
                    recurring?.icon ?? 'cash',
                    recurring?.iconColor ?? '#0f9d7a',
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          source.isVariable
                              ? 'دخل غير ثابت'
                              : _monthWordLabel(dueDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (recurring?.scheduledTime?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              recurring!.scheduledTime!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayedAmount.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (!source.isVariable) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'الباقي',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      afterSpend.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                if (remProgress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: remProgress,
                      minHeight: 8,
                      color: accent,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ],
              if ((canEarly || isDueOrLate) && !source.isVariable) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (canEarly)
                      Expanded(
                        child: _compactActionButton(
                          label: 'بكر',
                          filled: false,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Future.microtask(() {
                              if (!mounted) return;
                              _recordIncomeFromTracking(source, early: true);
                            });
                          },
                        ),
                      ),
                    if (canEarly && isDueOrLate) const SizedBox(width: 8),
                    if (isDueOrLate)
                      Expanded(
                        child: _compactActionButton(
                          label: 'نزول',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Future.microtask(() {
                              if (!mounted) return;
                              _recordIncomeFromTracking(source);
                            });
                          },
                        ),
                      ),
                    if (isDueOrLate) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _compactActionButton(
                          label: 'تأجيل',
                          filled: false,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Future.microtask(() {
                              if (!mounted) return;
                              _postponeIncome(source);
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDebtDetailsSheet(
    DebtEntity debt,
    List<TransactionEntity> tx,
    double remaining,
  ) async {
    final theme = Theme.of(context);
    const accent = Color(0xFFC65D2E);
    final recurring = _linkedRecurringDebt(widget.cubit.state, debt);
    final dueDate = DateTime(
      _month.year,
      _month.month,
      debt.executionDay.clamp(1, 28),
    );
    final paid = tx.fold<double>(0, (s, t) => s + t.amount);
    final paidRatio =
        debt.amount <= 0 ? null : (paid / debt.amount).clamp(0.0, 1.0);
    final sortedTx = [...tx]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pctLabel =
        paidRatio == null ? '0' : (paidRatio * 100).round().toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _DraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: sortedTx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات سداد مسجلة لهذا الدين في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          _trackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _editDebtDirect(debt);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconBadge(
                    recurring?.icon ?? 'receipt',
                    recurring?.iconColor ?? '#c65d2e',
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'استحقاق ${_monthWordLabel(dueDate)} · الأصل ${debt.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remaining.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'تم سداد $pctLabel٪ · المتبقي ${remaining.toStringAsFixed(2)} من أصل ${debt.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (paidRatio != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: paidRatio,
                    minHeight: 8,
                    color: Colors.green,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editIncomeDirect(IncomeSourceEntity current) async {
    final state = widget.cubit.state;
    final wallets = state.wallets;
    final fallbackWalletId =
        wallets.isNotEmpty ? wallets.first.id : 'wallet-cash-default';
    final linkedRecurring = _linkedRecurringIncome(state, current);
    final draftRecurring = linkedRecurring ??
        RecurringTransactionEntity(
          id: '',
          name: current.name,
          type: 'income',
          amount: current.isVariable ? 0 : current.amount,
          dayOfMonth: current.date.clamp(1, 28),
          executionType: current.isVariable ? 'manual' : current.type,
          walletId: current.targetWalletId.isEmpty
              ? fallbackWalletId
              : current.targetWalletId,
          budgetScope: 'within-budget',
          recurrencePattern: 'monthly',
          icon: 'cash',
          iconColor: '#0f9d7a',
          incomeSourceId: current.id,
          isVariableIncome: current.isVariable,
          isDebtOrSubscription: false,
        );

    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: 'income',
          initialWithinBudget: true,
          initialRecurring: draftRecurring,
          returnOnSave: true,
          allowDelete: true,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == null) {
      return;
    }

    final setup = widget.cubit.state.budgetSetup;
    if (result.deleteRequested) {
      final linked = widget.cubit.state.recurringTransactions
          .where((r) => r.incomeSourceId == current.id)
          .toList();
      for (final recurring in linked) {
        await widget.cubit.deleteRecurringTransaction(recurring.id);
      }
      if (linked.isEmpty && linkedRecurring != null) {
        await widget.cubit.deleteRecurringTransaction(linkedRecurring.id);
      }
      final incomes =
          setup.incomeSources.where((e) => e.id != current.id).toList();
      await widget.cubit
          .updateBudgetSetup(setup.copyWith(incomeSources: incomes));
      return;
    }

    final recurring = result.recurring;
    if (recurring == null) {
      return;
    }

    final updated = IncomeSourceEntity(
      id: current.id,
      name: recurring.name,
      amount: recurring.isVariableIncome ? 0 : recurring.amount,
      date: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.isVariableIncome ? 'manual' : recurring.executionType,
      targetWalletId: recurring.walletId,
      isVariable: recurring.isVariableIncome,
      isDefault: current.isDefault,
    );
    final incomes = setup.incomeSources
        .map((e) => e.id == current.id ? updated : e)
        .toList();
    await widget.cubit
        .updateBudgetSetup(setup.copyWith(incomeSources: incomes));

    if (linkedRecurring == null) {
      await widget.cubit.addRecurringTransaction(
        name: recurring.name,
        type: recurring.type,
        amount: recurring.amount,
        dayOfMonth: recurring.dayOfMonth,
        executionType: recurring.executionType,
        walletId: recurring.walletId,
        budgetScope: recurring.budgetScope,
        recurrencePattern: recurring.recurrencePattern,
        icon: recurring.icon,
        iconColor: recurring.iconColor,
        weekday: recurring.weekday,
        weekdays: recurring.weekdays,
        monthOfYear: recurring.monthOfYear,
        scheduledTime: recurring.scheduledTime,
        reminderLeadDays: recurring.reminderLeadDays,
        incomeSourceId: current.id,
        categoryIds: recurring.categoryIds,
        isVariableIncome: recurring.isVariableIncome,
        isDebtOrSubscription: false,
        notes: recurring.notes,
      );
    } else {
      await widget.cubit.updateRecurringTransaction(
        linkedRecurring.copyWith(
          name: recurring.name,
          amount: recurring.amount,
          dayOfMonth: recurring.dayOfMonth,
          executionType: recurring.executionType,
          walletId: recurring.walletId,
          budgetScope: recurring.budgetScope,
          recurrencePattern: recurring.recurrencePattern,
          icon: recurring.icon,
          iconColor: recurring.iconColor,
          weekday: recurring.weekday,
          weekdays: recurring.weekdays,
          monthOfYear: recurring.monthOfYear,
          scheduledTime: recurring.scheduledTime,
          reminderLeadDays: recurring.reminderLeadDays,
          incomeSourceId: current.id,
          categoryIds: recurring.categoryIds,
          isVariableIncome: recurring.isVariableIncome,
          isDebtOrSubscription: false,
          notes: recurring.notes,
        ),
      );
    }
  }

  Future<void> _editDebtDirect(DebtEntity current) async {
    final state = widget.cubit.state;
    final linkedRecurring = _linkedRecurringDebt(state, current);
    final fallbackWalletId = state.wallets.isNotEmpty
        ? state.wallets.first.id
        : 'wallet-cash-default';
    final draftRecurring = linkedRecurring ??
        RecurringTransactionEntity(
          id: current.recurringTransactionId ?? '',
          name: current.name,
          type: 'expense',
          amount: 0,
          dayOfMonth: current.executionDay.clamp(1, 28),
          executionType: current.type,
          walletId: fallbackWalletId,
          budgetScope: 'within-budget',
          recurrencePattern: 'monthly',
          icon: 'receipt',
          iconColor: '#c65d2e',
          isDebtOrSubscription: true,
          debtPrincipalTotal: current.amount > 0 ? current.amount : null,
        );
    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: 'expense',
          initialWithinBudget: true,
          initialRecurring: draftRecurring,
          returnOnSave: true,
          allowDelete: true,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == null) {
      return;
    }

    final setup = widget.cubit.state.budgetSetup;
    if (result.deleteRequested) {
      if ((current.recurringTransactionId ?? '').isNotEmpty) {
        await widget.cubit
            .deleteRecurringTransaction(current.recurringTransactionId!);
      } else if (linkedRecurring != null) {
        await widget.cubit.deleteRecurringTransaction(linkedRecurring.id);
      }
      final next = setup.debts.where((d) => d.id != current.id).toList();
      await widget.cubit.updateBudgetSetup(setup.copyWith(debts: next));
      return;
    }

    final recurring = result.recurring;
    if (recurring == null) {
      return;
    }

    final recurringId =
        linkedRecurring?.id ?? current.recurringTransactionId ?? _id('rec');
    final principal = recurring.debtPrincipalTotal;
    final debtAmount =
        principal != null && principal > 0 ? principal : recurring.amount;
    final updated = DebtEntity(
      id: current.id,
      name: recurring.name,
      amount: debtAmount,
      executionDay: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.executionType,
      fundingSource: current.fundingSource,
      recurringTransactionId: recurringId,
    );
    final next =
        setup.debts.map((d) => d.id == current.id ? updated : d).toList();
    await widget.cubit.updateBudgetSetup(setup.copyWith(debts: next));

    final recurringToSave = recurring.copyWith(
      id: recurringId,
      type: 'expense',
      budgetScope: 'within-budget',
      isDebtOrSubscription: true,
      allocationId: null,
      targetJarId: null,
    );
    if (linkedRecurring == null) {
      await widget.cubit.addRecurringTransaction(
        id: recurringId,
        name: recurringToSave.name,
        type: recurringToSave.type,
        amount: recurringToSave.amount,
        dayOfMonth: recurringToSave.dayOfMonth,
        executionType: recurringToSave.executionType,
        walletId: recurringToSave.walletId,
        budgetScope: recurringToSave.budgetScope,
        recurrencePattern: recurringToSave.recurrencePattern,
        icon: recurringToSave.icon,
        iconColor: recurringToSave.iconColor,
        weekday: recurringToSave.weekday,
        weekdays: recurringToSave.weekdays,
        monthOfYear: recurringToSave.monthOfYear,
        scheduledTime: recurringToSave.scheduledTime,
        reminderLeadDays: recurringToSave.reminderLeadDays,
        isDebtOrSubscription: true,
        debtPrincipalTotal: recurringToSave.debtPrincipalTotal,
        notes: recurringToSave.notes,
      );
    } else {
      await widget.cubit.updateRecurringTransaction(recurringToSave);
    }
  }

  Future<void> _addDebtDirect() async {
    final setup = widget.cubit.state.budgetSetup;
    if (setup.incomeSources.isEmpty) {
      return;
    }
    final fallbackWalletId = widget.cubit.state.wallets.isNotEmpty
        ? widget.cubit.state.wallets.first.id
        : 'wallet-cash-default';
    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: 'expense',
          initialWithinBudget: true,
          initialRecurring: RecurringTransactionEntity(
            id: '',
            name: '',
            type: 'expense',
            amount: 0,
            dayOfMonth: 1,
            executionType: 'confirm',
            walletId: fallbackWalletId,
            budgetScope: 'within-budget',
            recurrencePattern: 'monthly',
            icon: 'receipt',
            iconColor: '#c65d2e',
            isDebtOrSubscription: true,
          ),
          returnOnSave: true,
        ),
        fullscreenDialog: true,
      ),
    );
    final recurring = result?.recurring;
    if (recurring == null) {
      return;
    }

    final recurringId = _id('rec');
    final principal = recurring.debtPrincipalTotal;
    final debtAmount =
        principal != null && principal > 0 ? principal : recurring.amount;
    final debt = DebtEntity(
      id: _id('debt'),
      name: recurring.name,
      amount: debtAmount,
      executionDay: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.executionType,
      fundingSource: setup.incomeSources.first.id,
      recurringTransactionId: recurringId,
    );
    await widget.cubit
        .updateBudgetSetup(setup.copyWith(debts: [...setup.debts, debt]));
    await widget.cubit.addRecurringTransaction(
      id: recurringId,
      name: recurring.name,
      type: 'expense',
      amount: recurring.amount,
      dayOfMonth: recurring.dayOfMonth,
      executionType: recurring.executionType,
      walletId: recurring.walletId,
      budgetScope: 'within-budget',
      recurrencePattern: recurring.recurrencePattern,
      icon: recurring.icon,
      iconColor: recurring.iconColor,
      weekday: recurring.weekday,
      weekdays: recurring.weekdays,
      monthOfYear: recurring.monthOfYear,
      scheduledTime: recurring.scheduledTime,
      reminderLeadDays: recurring.reminderLeadDays,
      isDebtOrSubscription: true,
      debtPrincipalTotal: recurring.debtPrincipalTotal,
      notes: recurring.notes,
    );
  }

  RecurringTransactionEntity? _linkedRecurringDebt(
    AppStateEntity state,
    DebtEntity debt,
  ) {
    final recurring = state.recurringTransactions.where(
      (item) =>
          item.type == 'expense' &&
          item.budgetScope == 'within-budget' &&
          item.isDebtOrSubscription &&
          (((debt.recurringTransactionId ?? '').isNotEmpty &&
                  item.id == debt.recurringTransactionId) ||
              (item.name == debt.name)),
    );
    if (recurring.isEmpty) {
      return null;
    }
    return recurring.first;
  }

  bool _transactionCountsTowardDebt(
    TransactionEntity t,
    DebtEntity debt,
  ) {
    if (t.type != 'expense') return false;
    final n = t.notes ?? '';
    return n.contains(debt.name);
  }

  List<TransactionEntity> _allDebtPayments(
    AppStateEntity state,
    DebtEntity debt,
  ) {
    final list = state.transactions
        .where((t) => _transactionCountsTowardDebt(t, debt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  DateTime? _parseRecurringTime(String? value) {
    if (value == null || value.isEmpty || !value.contains(':')) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTime? _nextRecurringOccurrence(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) {
    final time = _parseRecurringTime(recurring.scheduledTime) ?? now;
    DateTime atDate(DateTime day) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);

    if (recurring.recurrencePattern == 'daily') {
      final today = atDate(now);
      return today.isAfter(now) ? today : today.add(const Duration(days: 1));
    }
    if (recurring.weekdays.isNotEmpty) {
      for (var offset = 0; offset <= 21; offset++) {
        final day = now.add(Duration(days: offset));
        if (recurring.weekdays.contains(day.weekday)) {
          final candidate = atDate(day);
          if (candidate.isAfter(now)) {
            return candidate;
          }
        }
      }
    }
    if (recurring.recurrencePattern == 'monthly' ||
        recurring.recurrencePattern == 'every_2_months' ||
        recurring.recurrencePattern == 'every_3_months' ||
        recurring.recurrencePattern == 'every_6_months') {
      final interval = switch (recurring.recurrencePattern) {
        'every_2_months' => 2,
        'every_3_months' => 3,
        'every_6_months' => 6,
        _ => 1,
      };
      for (var step = 0; step < 12; step++) {
        final monthDate = DateTime(now.year, now.month + (step * interval));
        final candidate = DateTime(
          monthDate.year,
          monthDate.month,
          recurring.dayOfMonth.clamp(1, 28),
          time.hour,
          time.minute,
        );
        if (candidate.isAfter(now)) {
          return candidate;
        }
      }
    }
    if (recurring.recurrencePattern == 'yearly') {
      final month = recurring.monthOfYear ?? now.month;
      final thisYear = DateTime(
        now.year,
        month,
        recurring.dayOfMonth.clamp(1, 28),
        time.hour,
        time.minute,
      );
      if (thisYear.isAfter(now)) {
        return thisYear;
      }
      return DateTime(
        now.year + 1,
        month,
        recurring.dayOfMonth.clamp(1, 28),
        time.hour,
        time.minute,
      );
    }
    return null;
  }

  Duration _reminderDuration(RecurringTransactionEntity recurring) {
    final value = recurring.reminderLeadDays ?? 0;
    if (recurring.recurrencePattern == 'daily' ||
        recurring.recurrencePattern == 'weekly' ||
        recurring.recurrencePattern == 'biweekly' ||
        recurring.recurrencePattern == 'every_3_weeks') {
      return Duration(hours: value.clamp(0, 3));
    }
    return Duration(days: value.clamp(0, 3));
  }

  Map<String, dynamic>? _expensePendingMeta(
      RecurringTransactionEntity? recurring) {
    if (recurring == null || recurring.executionType != 'confirm') {
      return null;
    }
    final now = DateTime.now();
    final dueNow = _dueOccurrenceNow(recurring, now);
    final occurrence = dueNow ?? _nextRecurringOccurrence(recurring, now);
    if (occurrence == null) {
      return null;
    }
    if (_occurrenceWasHandled(recurring, occurrence)) {
      return <String, dynamic>{
        'status': 'تم تنفيذ هذه الدورة',
        'occurrence': occurrence,
        'pending': false,
      };
    }
    final snoozedUntil = recurring.snoozedUntil == null
        ? null
        : DateTime.tryParse(recurring.snoozedUntil!);
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
      return <String, dynamic>{
        'status':
            'مؤجل حتى ${DateFormat('d/M - h:mm a', 'ar').format(snoozedUntil)}',
        'occurrence': occurrence,
        'pending': true,
      };
    }
    final reminderAt = occurrence.subtract(_reminderDuration(recurring));
    if (now.isBefore(reminderAt)) {
      return <String, dynamic>{
        'status':
            'الاستحقاق القادم ${DateFormat('d/M - h:mm a', 'ar').format(occurrence)}',
        'occurrence': occurrence,
        'pending': false,
      };
    }
    return <String, dynamic>{
      'status': dueNow == null
          ? 'معلق حتى ${DateFormat('d/M - h:mm a', 'ar').format(occurrence)}'
          : 'مستحق الآن ${DateFormat('d/M - h:mm a', 'ar').format(occurrence)}',
      'occurrence': occurrence,
      'pending': true,
    };
  }

  bool _occurrenceWasHandled(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) {
    final handled = recurring.lastHandledOccurrenceAt == null
        ? null
        : DateTime.tryParse(recurring.lastHandledOccurrenceAt!);
    if (handled == null) {
      return false;
    }
    final normalized = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      occurrence.hour,
      occurrence.minute,
    );
    return !handled.isBefore(normalized);
  }

  DateTime? _dueOccurrenceNow(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) {
    final time = _parseRecurringTime(recurring.scheduledTime) ?? now;
    DateTime atDate(DateTime day) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);

    if (recurring.recurrencePattern == 'daily') {
      final today = atDate(now);
      return today.isAfter(now) ? null : today;
    }

    if (recurring.weekdays.isNotEmpty) {
      for (var offset = 0; offset <= 21; offset++) {
        final day = now.subtract(Duration(days: offset));
        if (recurring.weekdays.contains(day.weekday)) {
          final candidate = atDate(day);
          if (!candidate.isAfter(now)) {
            return candidate;
          }
        }
      }
      return null;
    }

    if (recurring.recurrencePattern == 'yearly') {
      final month = recurring.monthOfYear ?? now.month;
      final candidate = DateTime(
        now.year,
        month,
        recurring.dayOfMonth.clamp(1, 28),
        time.hour,
        time.minute,
      );
      return candidate.isAfter(now) ? null : candidate;
    }

    final interval = switch (recurring.recurrencePattern) {
      'every_2_months' => 2,
      'every_3_months' => 3,
      'every_6_months' => 6,
      _ => 1,
    };
    final candidate = DateTime(
      now.year,
      now.month,
      recurring.dayOfMonth.clamp(1, 28),
      time.hour,
      time.minute,
    );
    if (candidate.isAfter(now)) {
      return null;
    }
    final monthDiff =
        (candidate.year - now.year) * 12 + candidate.month - now.month;
    return monthDiff % interval == 0 ? candidate : null;
  }

  Future<void> _processAutomaticDebts(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) async {
    if (_processingAutomaticDebts || !_isCurrentMonthView() || !mounted) {
      return;
    }
    _processingAutomaticDebts = true;
    try {
      final now = DateTime.now();
      for (final debt in budget.debts) {
        final recurring = _linkedRecurringDebt(state, debt);
        if (recurring == null || recurring.executionType != 'auto') {
          continue;
        }
        final occurrence = _dueOccurrenceNow(recurring, now);
        if (occurrence == null ||
            _occurrenceWasHandled(recurring, occurrence)) {
          continue;
        }
        final paid = monthTx
            .where((t) => _transactionCountsTowardDebt(t, debt))
            .fold<double>(0, (sum, t) => sum + t.amount);
        final remaining = (debt.amount - paid).clamp(0.0, debt.amount);
        if (remaining <= 0) {
          await widget.cubit.updateRecurringTransaction(
            recurring.copyWith(
              lastHandledOccurrenceAt: occurrence.toIso8601String(),
              snoozedUntil: '',
            ),
          );
          continue;
        }
        await widget.cubit.addTransaction(
          walletId: recurring.walletId,
          amount: remaining,
          type: 'expense',
          budgetScope: 'within-budget',
          createdAt: now,
          notes: 'خصم تلقائي دين: ${debt.name}',
        );
        await widget.cubit.updateRecurringTransaction(
          recurring.copyWith(
            lastHandledOccurrenceAt: occurrence.toIso8601String(),
            snoozedUntil: '',
          ),
        );
      }
    } finally {
      _processingAutomaticDebts = false;
    }
  }

  DateTime _incomeDueDateForMonth(IncomeSourceEntity source, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = source.date.clamp(1, lastDay);
    return DateTime(month.year, month.month, day);
  }

  Future<void> _recordIncomeFromTracking(IncomeSourceEntity source,
      {bool early = false}) async {
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
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد')),
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

  Future<void> _postponeIncome(IncomeSourceEntity source) async {
    final dueDate = _incomeDueDateForMonth(source, _month);
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate.add(const Duration(days: 1)),
      firstDate: dueDate.add(const Duration(days: 1)),
      lastDate: DateTime(_month.year, _month.month + 1, 28),
    );
    if (picked == null) return;
    final setup = widget.cubit.state.budgetSetup;
    final incomes = setup.incomeSources
        .map(
          (i) => i.id == source.id
              ? IncomeSourceEntity(
                  id: i.id,
                  name: i.name,
                  amount: i.amount,
                  date: picked.day,
                  type: i.type,
                  targetWalletId: i.targetWalletId,
                  isVariable: i.isVariable,
                  isDefault: i.isDefault,
                )
              : i,
        )
        .toList();
    await widget.cubit
        .updateBudgetSetup(setup.copyWith(incomeSources: incomes));
  }

  Future<void> _recordDebtFromTracking(
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
    final delayed = now.add(const Duration(hours: 1));
    final nextSnooze = delayed.isAfter(occurrence) ? occurrence : delayed;
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(snoozedUntil: nextSnooze.toIso8601String()),
    );
  }

  Future<void> _confirmDebtPayment(
    AppStateEntity state,
    BudgetSetupEntity budget,
    DebtEntity debt,
    RecurringTransactionEntity recurring,
  ) async {
    final now = DateTime.now();
    final occurrence = _dueOccurrenceNow(recurring, now) ?? 
        _nextRecurringOccurrence(recurring, now);
    if (occurrence == null) return;
    
    await _recordDebtFromTracking(debt, recurring, occurrence);
  }

  Future<void> _openTxSheet(
      {required String title, required List<TransactionEntity> tx}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...tx.map((item) => ListTile(
                  title: Text(
                      item.notes?.isNotEmpty == true ? item.notes! : 'معاملة'),
                  subtitle: Text(
                      DateFormat('d/M - h:mm a', 'ar').format(item.createdAt)),
                  trailing: Text(item.amount.toStringAsFixed(2)),
                  onTap: () => openTransactionDetailsSheet(
                    context,
                    cubit: widget.cubit,
                    transaction: item,
                  ),
                )),
            if (tx.isEmpty) const ListTile(title: Text('لا توجد معاملات.')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value,
      {bool danger = false, String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            suffix ?? value.toStringAsFixed(2),
            style: TextStyle(
              color: danger ? Theme.of(context).colorScheme.error : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  bool _isJarReserveTx(TransactionEntity t) {
    return t.transferType == 'jar-allocation' ||
        t.transferType == 'jar-allocation-cancel' ||
        t.transferType == 'jar-allocation-spend';
  }
}

enum _TxKindFilter { all, expense, income, transfer }

enum _TxDateFilter { day, week, month, year, custom, all }

class _DraggableFilterableTxSheet extends StatefulWidget {
  const _DraggableFilterableTxSheet({
    required this.theme,
    required this.accent,
    required this.topSectionAfterGrab,
    required this.transactions,
    required this.initialMonth,
    required this.emptyMessage,
    required this.sheetContext,
    required this.tileBuilder,
  });

  final ThemeData theme;
  final Color accent;
  final List<Widget> topSectionAfterGrab;
  final List<TransactionEntity> transactions;
  final DateTime initialMonth;
  final String emptyMessage;
  final BuildContext sheetContext;
  final Widget Function(TransactionEntity item) tileBuilder;

  @override
  State<_DraggableFilterableTxSheet> createState() =>
      _DraggableFilterableTxSheetState();
}

class _DraggableFilterableTxSheetState
    extends State<_DraggableFilterableTxSheet> {
  bool _newestFirst = true;
  _TxKindFilter _kind = _TxKindFilter.all;
  _TxDateFilter _dateFilter = _TxDateFilter.month;
  DateTime? _selectedDay;
  DateTime? _selectedWeekStart;
  DateTimeRange? _customRange;

  static bool _isTransfer(TransactionEntity t) {
    return t.type != 'expense' && t.type != 'income';
  }

  List<TransactionEntity> get _visible {
    var list = List<TransactionEntity>.from(widget.transactions);
    switch (_kind) {
      case _TxKindFilter.all:
        break;
      case _TxKindFilter.expense:
        list = list.where((t) => t.type == 'expense').toList();
        break;
      case _TxKindFilter.income:
        list = list.where((t) => t.type == 'income').toList();
        break;
      case _TxKindFilter.transfer:
        list = list.where(_isTransfer).toList();
        break;
    }
    list = list.where(_matchesDateFilter).toList();
    list.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  bool _matchesDateFilter(TransactionEntity transaction) {
    final date = transaction.createdAt;
    switch (_dateFilter) {
      case _TxDateFilter.all:
        return true;
      case _TxDateFilter.month:
        return date.year == widget.initialMonth.year &&
            date.month == widget.initialMonth.month;
      case _TxDateFilter.year:
        return date.year == widget.initialMonth.year;
      case _TxDateFilter.day:
        final day = _selectedDay ?? widget.initialMonth;
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      case _TxDateFilter.week:
        final start = _selectedWeekStart ?? widget.initialMonth;
        final normalizedStart = DateTime(start.year, start.month, start.day);
        final normalizedEnd = normalizedStart
            .add(const Duration(days: 6, hours: 23, minutes: 59));
        return !date.isBefore(normalizedStart) && !date.isAfter(normalizedEnd);
      case _TxDateFilter.custom:
        final range = _customRange;
        if (range == null) {
          return true;
        }
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        return !date.isBefore(start) && !date.isAfter(end);
    }
  }

  String get _dateFilterLabel {
    switch (_dateFilter) {
      case _TxDateFilter.day:
        final day = _selectedDay ?? widget.initialMonth;
        return 'يوم ${DateFormat('d/M/yyyy', 'ar').format(day)}';
      case _TxDateFilter.week:
        final start = _selectedWeekStart ?? widget.initialMonth;
        final end = start.add(const Duration(days: 6));
        return 'أسبوع ${DateFormat('d/M', 'ar').format(start)} - ${DateFormat('d/M', 'ar').format(end)}';
      case _TxDateFilter.month:
        return DateFormat('MMMM yyyy', 'ar').format(widget.initialMonth);
      case _TxDateFilter.year:
        return 'سنة ${widget.initialMonth.year}';
      case _TxDateFilter.custom:
        if (_customRange == null) return 'مدى مخصص';
        return '${DateFormat('d/M/yyyy', 'ar').format(_customRange!.start)} - ${DateFormat('d/M/yyyy', 'ar').format(_customRange!.end)}';
      case _TxDateFilter.all:
        return 'كل المعاملات';
    }
  }

  String get _kindFilterLabel {
    switch (_kind) {
      case _TxKindFilter.expense:
        return 'مصروفات فقط';
      case _TxKindFilter.income:
        return 'دخل فقط';
      case _TxKindFilter.transfer:
        return 'تحويلات فقط';
      case _TxKindFilter.all:
        return 'كل الأنواع';
    }
  }

  String get _sortLabel => _newestFirst ? 'الأحدث أولًا' : 'الأقدم أولًا';

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        Widget sectionTitle(String title, IconData icon) {
          return Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: widget.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        }

        Widget optionTile({
          required String title,
          String? subtitle,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? widget.accent.withValues(alpha: 0.10)
                      : widget.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? widget.accent.withValues(alpha: 0.34)
                        : widget.theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    widget.theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? widget.accent
                          : widget.theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تصفية المعاملات',
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اختر نوع المعاملات والفترة المناسبة، ويمكنك تغيير الترتيب من الشاشة الرئيسية مباشرة.',
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  sectionTitle('نوع المعاملة', Icons.tune_rounded),
                  const SizedBox(height: 10),
                  optionTile(
                    title: 'كل المعاملات',
                    selected: _kind == _TxKindFilter.all,
                    onTap: () {
                      setState(() => _kind = _TxKindFilter.all);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'مصروفات فقط',
                    selected: _kind == _TxKindFilter.expense,
                    onTap: () {
                      setState(() => _kind = _TxKindFilter.expense);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'دخل فقط',
                    selected: _kind == _TxKindFilter.income,
                    onTap: () {
                      setState(() => _kind = _TxKindFilter.income);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'تحويلات فقط',
                    selected: _kind == _TxKindFilter.transfer,
                    onTap: () {
                      setState(() => _kind = _TxKindFilter.transfer);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 18),
                  sectionTitle('الفترة', Icons.date_range_rounded),
                  const SizedBox(height: 10),
                  optionTile(
                    title: 'الشهر المعروض',
                    subtitle: DateFormat('MMMM yyyy', 'ar')
                        .format(widget.initialMonth),
                    selected: _dateFilter == _TxDateFilter.month,
                    onTap: () {
                      setState(() => _dateFilter = _TxDateFilter.month);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'السنة المعروضة',
                    subtitle: '${widget.initialMonth.year}',
                    selected: _dateFilter == _TxDateFilter.year,
                    onTap: () {
                      setState(() => _dateFilter = _TxDateFilter.year);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'يوم محدد',
                    subtitle: _selectedDay == null
                        ? 'اختر يومًا بعينه'
                        : DateFormat('d/M/yyyy', 'ar').format(_selectedDay!),
                    selected: _dateFilter == _TxDateFilter.day,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDay ?? widget.initialMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setState(() {
                        _selectedDay = picked;
                        _dateFilter = _TxDateFilter.day;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'أسبوع',
                    subtitle: _selectedWeekStart == null
                        ? 'اختر بداية الأسبوع'
                        : '${DateFormat('d/M', 'ar').format(_selectedWeekStart!)} - ${DateFormat('d/M', 'ar').format(_selectedWeekStart!.add(const Duration(days: 6)))}',
                    selected: _dateFilter == _TxDateFilter.week,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedWeekStart ?? widget.initialMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setState(() {
                        _selectedWeekStart = picked;
                        _dateFilter = _TxDateFilter.week;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'من تاريخ إلى تاريخ',
                    subtitle: _customRange == null
                        ? 'حدد مدى زمني مخصص'
                        : '${DateFormat('d/M/yyyy', 'ar').format(_customRange!.start)} - ${DateFormat('d/M/yyyy', 'ar').format(_customRange!.end)}',
                    selected: _dateFilter == _TxDateFilter.custom,
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDateRange: _customRange,
                      );
                      if (picked == null) return;
                      setState(() {
                        _customRange = picked;
                        _dateFilter = _TxDateFilter.custom;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'كل الفترات',
                    selected: _dateFilter == _TxDateFilter.all,
                    onTap: () {
                      setState(() => _dateFilter = _TxDateFilter.all);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final theme = widget.theme;

    return SizedBox(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.76,
        minChildSize: 0.38,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.76, 1.0],
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Material(
              color: theme.colorScheme.surface,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  ...widget.topSectionAfterGrab,
                  Divider(
                    height: 32,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المعاملات',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _dateFilterLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _kindFilterLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: widget.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              widget.accent.withValues(alpha: 0.10),
                          foregroundColor: widget.accent,
                        ),
                        onPressed: () {
                          setState(() => _newestFirst = !_newestFirst);
                        },
                        icon: Icon(
                          _newestFirst
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 20,
                        ),
                        tooltip: _sortLabel,
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              widget.accent.withValues(alpha: 0.10),
                          foregroundColor: widget.accent,
                        ),
                        onPressed: _openFilterSheet,
                        icon: const Icon(Icons.filter_list_rounded, size: 22),
                        tooltip: 'تصفية',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...visible.map(widget.tileBuilder),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        widget.emptyMessage,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}