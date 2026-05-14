// ignore_for_file: no_wildcard_variable_uses

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';
import '../../../transactions/presentation/screens/recurring_transaction_composer_screen.dart';
import '../../../transactions/presentation/widgets/recurring_postpone_dialog.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/services/budget_recurring_plan_service.dart';
import '../cubits/budget_cubit.dart';
import '../cubits/budget_state.dart';
import '../sections/budget_tracking_overview_content.dart';
import '../sheets/draggable_filterable_tx_sheet.dart';
import '../widgets/budget_lent_pending_card.dart';
import '../widgets/budget_static_info_card.dart';
import '../widgets/budget_tracking_overview_widgets.dart';
import '../widgets/installment_payments_card.dart';
import 'budget_setup_screen.dart';
import 'cycle_analysis_screen.dart';

class BudgetTrackingScreen extends StatefulWidget {
  const BudgetTrackingScreen({super.key});

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  /// [_cycleStart] = أول يوم في الدورة المعروضة حالياً
  late DateTime _cycleStart;
  bool _isIncomeExpanded = false;
  bool _isLentExpanded = false;
  bool _processingAutomaticDebts = false;

  /// occurrences اتشغلت في هذه الـ session — يمنع التكرار بسبب rebuild
  final Set<String> _handledOccurrenceKeys = {};

  String? _dismissedAutoIncomeMonthKey;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _cycleStart = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bc = context.read<BudgetCubit>();
      setState(() {
        _cycleStart = bc.state.selectedCycleStart;
      });
      final state = bc.state.workspace;
      final cycleTx = state.transactions
          .where((t) =>
              !t.createdAt.isBefore(_cycleStart) &&
              !t.createdAt.isAfter(_cycleEndForWorkspace(state)))
          .toList();
      _processAutomaticDebts(state, state.budgetSetup, cycleTx);
    });
  }

  // ── الدورة الحالية ────────────────────────────────────────────────────────

  DateTime _cycleEndForWorkspace(AppStateEntity workspace) {
    final budget = workspace.budgetSetup;
    return budget.cycleEndFor(_cycleStart);
  }

  /// للتوافق مع الكود القديم الذي يستخدم _month
  DateTime get _month => _cycleStart;

  void _goToPreviousCycle(BudgetSetupEntity budget) {
    context.read<BudgetCubit>().goToPreviousCycle();
  }

  void _goToNextCycle(BudgetSetupEntity budget) {
    context.read<BudgetCubit>().goToNextCycle();
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
    return BlocConsumer<BudgetCubit, BudgetState>(
      listenWhen: (previous, current) =>
          previous.selectedCycleStart != current.selectedCycleStart,
      listener: (context, budgetState) {
        if (_cycleStart != budgetState.selectedCycleStart) {
          setState(() {
            _cycleStart = budgetState.selectedCycleStart;
          });
        }
      },
      builder: (context, budgetState) {
        final state = budgetState.workspace;
        final budget = _budgetForMonth(state);
        final futureMonth = _isFutureMonth();
        final pastMonth = _isPastMonth();
        final hasBudgetPlan = _hasBudgetPlan(budget);
        final showSetupPromptOnly = futureMonth || !hasBudgetPlan;
        final budgetJars = budget.linkedWallets.where((jar) {
          if (jar.id == 'linked-savings-default') return true;
          return jar.funding
              .any((f) => f.incomeSourceId.isNotEmpty && f.plannedAmount > 0);
        }).toList();
        final monthTx = _monthTransactions(state, state.transactions);
        final incomeTx = monthTx.where((t) => t.type == 'income').toList();
        final expenseTx = monthTx.where((t) => t.type == 'expense').toList();
        final incomeSectionChildren =
            _incomeInlineCards(state, budget, incomeTx, monthTx);
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

        return BudgetTrackingOverviewContent(
          monthBar: _monthBar(context),
          heroSummaryCard: _heroSummaryCard(
            totalIncomeActual: totalIncomeActual,
            totalExpenseActual: totalExpenseActual,
            remainingIncome: remainingIncome,
          ),
          pastMonthSummaryCard: pastMonth
              ? _pastMonthSummaryCard(
                  totalIncomeActual: totalIncomeActual,
                  totalExpenseActual: totalExpenseActual,
                  remainingIncome: remainingIncome,
                )
              : null,
          showSetupPromptOnly: showSetupPromptOnly,
          budgetSetupPromptCard:
              _budgetSetupPromptCard(futureMonth: futureMonth),
          incomeSectionTitle: _sectionTitle('الدخل'),
          incomeSectionCard: _inlineSectionCard(
            title: 'الدخل الكلي',
            subtitle: incomeSectionChildren.length == 1 &&
                    incomeSectionChildren.first is BudgetStaticInfoCard
                ? 'لا توجد مصادر دخل مضافة في هذه الدورة بعد'
                : 'كل مصادر الدخل المخطط لها لهذا الشهر',
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
            expandedChildren: incomeSectionChildren,
          ),
          allocationsSectionTitle: _sectionTitle('المخصصات'),
          allocationTiles: budget.allocations.isEmpty
              ? <Widget>[
                  _sectionEmptyCard(
                    text: 'لا يوجد مخصص في هذه الدورة.',
                    onTap: futureMonth || !pastMonth
                        ? _openBudgetSetupScreen
                        : null,
                  ),
                ]
              : budget.allocations
                  .map((allocation) =>
                      _allocationSummaryTile(state, allocation, monthTx))
                  .toList(),
          jarsSectionTitle: _sectionTitle('الحصالات'),
          jarTiles: budgetJars.isEmpty
              ? const <Widget>[
                  BudgetStaticInfoCard(
                    text: 'لا توجد حصالات ممولة في هذا الشهر.',
                  ),
                ]
              : budgetJars
                  .map((jar) => _jarSummaryTile(state, jar, monthTx))
                  .toList(),
          debtsSectionTitle: _sectionTitle('الديون والأقساط'),
          debtCards: [
            ..._installmentCards(state, budget, monthTx),
            ..._lentCards(state, monthTx),
          ],
          subscriptionsSectionTitle: _sectionTitle('الاشتراكات'),
          subscriptionCards: _subscriptionCards(state, budget, monthTx),
          cycleSummarySectionTitle: _sectionTitle('ملخص الدورة'),
          cycleSummaryCard: _cycleSummaryCard(
            state: state,
            budget: budget,
            totalIncomeActual: totalIncomeActual,
            totalExpenseActual: totalExpenseActual,
            remainingIncome: remainingIncome,
          ),
          showBudgetSetupButton: !pastMonth,
          budgetSetupButtonIcon:
              futureMonth ? Icons.add_task_outlined : Icons.edit_outlined,
          budgetSetupButtonLabel: futureMonth
              ? 'إعداد الميزانية الشهرية'
              : 'تعديل الميزانية الشهرية',
          onOpenBudgetSetupScreen: _openBudgetSetupScreen,
        );
      },
    );
  }

  Widget _monthBar(BuildContext context) {
    final workspace = context.read<BudgetCubit>().state.workspace;
    final budget = workspace.budgetSetup;
    return BudgetTrackingMonthBar(
      rangeLabel:
          '${DateFormat('d MMM', 'ar').format(_cycleStart)} — ${DateFormat('d MMM yyyy', 'ar').format(_cycleEndForWorkspace(workspace))}',
      isCurrent: _isCurrentCycle(budget),
      onPrevious: () => _goToPreviousCycle(budget),
      onNext: () => _goToNextCycle(budget),
    );
  }

  List<TransactionEntity> _monthTransactions(
    AppStateEntity workspace,
    List<TransactionEntity> tx,
  ) {
    final end = _cycleEndForWorkspace(workspace);
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

    // الدورة الحالية: دايمًا نستخدم budgetSetup الحالي لضمان ظهور آخر التحديثات
    if (_isCurrentCycle(budget)) return state.budgetSetup;

    final cycleKey = budget.cycleKeyFor(_cycleStart);

    // جرب الـ snapshot الجديد بمفتاح الدورة
    final cycleSnapshot = state.monthlyBudgetSnapshots[cycleKey];
    if (cycleSnapshot != null && cycleSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(cycleSnapshot);
    }

    // fallback: مفتاح الشهر القديم للتوافق مع البيانات السابقة
    final oldKey =
        '${_cycleStart.year}-${_cycleStart.month.toString().padLeft(2, '0')}';
    final oldSnapshot = state.monthlyBudgetSnapshots[oldKey];
    if (oldSnapshot != null && oldSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(oldSnapshot);
    }

    final end = _cycleEndForWorkspace(state);
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

  bool _isFutureMonth() => _isFutureCycle(context.read<BudgetCubit>().state.workspace.budgetSetup);

  bool _isPastMonth() => _isPastCycle(context.read<BudgetCubit>().state.workspace.budgetSetup);

  bool _hasBudgetPlan(BudgetSetupEntity budget) {
    final hasUserConfiguredJar = budget.linkedWallets.any(
      (jar) =>
          jar.id != 'linked-savings-default' ||
          jar.monthlyAmount > 0 ||
          jar.balance > 0 ||
          jar.funding.isNotEmpty,
    );
    return budget.incomeSources.isNotEmpty ||
        budget.allocations.isNotEmpty ||
        budget.debts.isNotEmpty ||
        hasUserConfiguredJar ||
        budget.totalIncome > 0 ||
        budget.totalAllocated > 0 ||
        budget.unallocatedAmount > 0;
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
            cubit: context.read<AppCubit>(),
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
    return BudgetTrackingHeroSummaryCard(
      totalIncomeActual: totalIncomeActual,
      totalExpenseActual: totalExpenseActual,
      remainingIncome: remainingIncome,
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
    return BudgetTrackingSetupPromptCard(
      futureMonth: futureMonth,
      isDisabled: _isPastMonth(),
      onTap: _openBudgetSetupScreen,
    );
  }

  Widget _sectionTitle(String title) {
    return BudgetTrackingSectionTitle(title: title);
  }

  Widget _sectionEmptyCard({
    required String text,
    VoidCallback? onTap,
  }) {
    return BudgetTrackingSectionEmptyCard(text: text, onTap: onTap);
  }

  Widget _cycleSummaryCard({
    required AppStateEntity state,
    required BudgetSetupEntity budget,
    required double totalIncomeActual,
    required double totalExpenseActual,
    required double remainingIncome,
  }) {
    final theme = Theme.of(context);
    final plannedIncome = budget.incomeSources
        .where((i) => !i.isVariable)
        .fold<double>(0, (s, i) => s + i.amount);
    final plannedAllocations = budget.allocations.fold<double>(
      0,
      (s, a) => s + a.funding.fold<double>(0, (ss, f) => ss + f.plannedAmount),
    );
    final plannedJars =
        budget.linkedWallets.fold<double>(0, (s, j) => s + j.monthlyAmount);
    final plannedDebts = budget.debts.fold<double>(0, (s, d) {
      final rec = _linkedRecurringDebt(state, d);
      return s +
          BudgetRecurringPlanService.amountDueInCycle(
            debt: d,
            recurring: rec,
            cycleStart: _cycleStart,
            cycleEnd: _cycleEndForWorkspace(state),
          );
    });
    final netSaving = remainingIncome.clamp(0, double.infinity).toDouble();
    final spendRatio = totalIncomeActual <= 0
        ? 0.0
        : (totalExpenseActual / totalIncomeActual).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('ملخص الدورة',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900)),
                ),
                // زرار تحليل الدورة
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CycleAnalysisScreen(
                        cubit: context.read<AppCubit>(),
                        cycleStart: _cycleStart,
                        cycleEnd: _cycleEndForWorkspace(state),
                        totalIncomeActual: totalIncomeActual,
                        totalExpenseActual: totalExpenseActual,
                        remainingIncome: remainingIncome,
                        plannedIncome: plannedIncome,
                        plannedAllocations: plannedAllocations,
                        plannedJars: plannedJars,
                        plannedDebts: plannedDebts,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E7F5C).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_graph_rounded,
                            size: 16, color: Color(0xFF1E7F5C)),
                        const SizedBox(width: 5),
                        Text('تحليل الدورة',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1E7F5C),
                              fontWeight: FontWeight.w800,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Spend progress ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('المستهلك',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      '${(spendRatio * 100).round()}٪  ·  ${totalExpenseActual.toStringAsFixed(0)}',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: spendRatio,
                    minHeight: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      spendRatio < 0.7
                          ? const Color(0xFF1E7F5C)
                          : spendRatio < 0.9
                              ? const Color(0xFFE4B83F)
                              : const Color(0xFFC65D2E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          // ── Rows ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row('الدخل الفعلي', totalIncomeActual),
                _row('إجمالي المصروف', totalExpenseActual,
                    danger: totalExpenseActual > totalIncomeActual),
                _row('المتبقي', remainingIncome, danger: remainingIncome < 0),
                const Divider(height: 20),
                _row('الدخل المخطط', plannedIncome),
                _row('المخصصات', plannedAllocations),
                _row('الحصالات', plannedJars),
                _row('الالتزامات في الدورة', plannedDebts),
                const Divider(height: 20),
                _row('غير المخصص', budget.unallocatedAmount,
                    danger: budget.unallocatedAmount < 0),
                _row('التوفير المتوقع', netSaving),
              ],
            ),
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
                        Text(
                          amountText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF165B47),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: Color(0xFF9E9E9E)),
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

    // اسم المعاملة: الفئة أولاً → الملاحظات → النوع
    final categories = context.read<BudgetCubit>().state.workspace.categories;
    String txTitle = defaultTitle;
    String? txNotes;
    if (item.categoryId != null && item.categoryId!.isNotEmpty) {
      try {
        final cat = categories.firstWhere((c) => c.id == item.categoryId);
        txTitle = cat.name;
        if (item.notes != null && item.notes!.isNotEmpty) {
          txNotes = item.notes;
        }
      } catch (_) {
        txTitle = item.notes?.isNotEmpty == true ? item.notes! : defaultTitle;
      }
    } else if (item.notes?.isNotEmpty == true) {
      txTitle = item.notes!;
    }

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
                cubit: context.read<AppCubit>(),
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
                        txTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (txNotes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          txNotes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
    Color? accentColor,
  }) {
    final theme = Theme.of(context);
    final accent = accentColor ??
        (title == 'الدخل الكلي'
            ? const Color(0xFF0F9D7A)
            : const Color(0xFFC65D2E));
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
                if (incomeTotalLayout) const SizedBox(height: 8),
                incomeTotalLayout
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: expandedChildren,
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
    final state = context.read<BudgetCubit>().state.workspace;
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

  bool _isCurrentMonthView() => _isCurrentCycle(context.read<BudgetCubit>().state.workspace.budgetSetup);

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
    Color? color,
  }) {
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
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
              foregroundColor: color,
              side: color != null ? BorderSide(color: color) : null,
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
    List<TransactionEntity> sourceIncomeTx,
  ) {
    final incomeOnly = [...sourceIncomeTx];
    incomeOnly.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return incomeOnly;
  }

  List<Widget> _incomeInlineCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> incomeTx,
    List<TransactionEntity> monthTx,
  ) {
    final children = <Widget>[
      ...budget.incomeSources.map((source) {
        final sourceTx =
            incomeTx.where((t) => t.incomeSourceId == source.id).toList();
        final received = sourceTx.fold<double>(0, (s, t) => s + t.amount);
        final recurring = _linkedRecurringIncome(state, source);
        final pendingMeta = _incomePendingMeta(state, source, sourceTx);
        final isSnoozed = pendingMeta?['snoozed'] == true;
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

        // ── snooze chip ──────────────────────────────────────────────────
        Widget? snoozeChip;
        if (isSnoozed) {
          snoozeChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF5A623).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: Color(0xFFF5A623)),
                const SizedBox(width: 4),
                Text(
                  pendingMeta!['status'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFF5A623),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return _entityTile(
          title: source.name,
          leading: _iconBadge(
            recurring?.icon ?? 'cash',
            recurring?.iconColor ?? '#0f9d7a',
            // حجم أصغر لو مأجل
            size: isSnoozed ? 44 : 56,
          ),
          amountText: displayedAmount.truncate().toString(),
          metaText: source.isVariable
              ? 'غير ثابت'
              : _monthWordLabel(_incomeDueDateForMonth(source, _month)),
          trailingTopText: recurring?.scheduledTime?.isNotEmpty == true
              ? recurring!.scheduledTime!
              : null,
          supportingText: source.isVariable ? 'دخل غير ثابت' : null,
          supportingCustom: isSnoozed
              ? snoozeChip
              : source.isVariable
                  ? null
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'الباقي',
                          style: TextStyle(
                            fontSize: 12,
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
          tint: isSnoozed
              ? const Color(0xFFF5A623).withValues(alpha: 0.6)
              : const Color(0xFF0F9D7A),
          compactMeta: source.isVariable || isSnoozed,
          progress: isSnoozed ? null : remProgress,
          progressColor: incomeProgressColor,
          embeddedInIncomeCard: true,
          onTap: () =>
              _openIncomeDetailsSheet(source, sourceTx, budget, monthTx),
          actions: (pendingMeta == null || isSnoozed)
              ? isSnoozed
                  ? <Widget>[
                      _compactActionButton(
                        label: 'إلغاء التأجيل',
                        filled: false,
                        onPressed: () async {
                          final setup = context.read<BudgetCubit>().state.workspace.budgetSetup;
                          final updated = setup.incomeSources.map((i) {
                            if (i.id != source.id) return i;
                            return i.copyWith(snoozedUntil: '');
                          }).toList();
                          await context.read<BudgetCubit>().updateBudgetSetup(
                            setup.copyWith(incomeSources: updated),
                          );
                        },
                      ),
                    ]
                  : const <Widget>[]
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
    if (children.isEmpty) {
      children.add(const BudgetStaticInfoCard(
          text: 'لا يوجد دخل مسجل أو مخطط في هذه الدورة.'));
    }
    return children;
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
    final hasPending = allocation.pendingDistribution > 0;

    Widget? pendingChip;
    if (hasPending) {
      pendingChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5A623).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF5A623).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded,
                size: 13, color: Color(0xFFF5A623)),
            const SizedBox(width: 4),
            Text(
              'ينتظر تأكيد تحويل ${allocation.pendingDistribution.toStringAsFixed(0)} ج.م',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFF5A623),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return _entityTile(
      title: allocation.name,
      leading: _iconBadge(allocation.icon, allocation.iconColor,
          size: hasPending ? 44 : 54),
      amountText: hasPending
          ? allocation.pendingDistribution.toStringAsFixed(2)
          : remaining.toStringAsFixed(2),
      metaText: 'المخطط ${planned.toStringAsFixed(2)}',
      supportingText: hasPending ? null : 'المتاح ${funded.toStringAsFixed(2)}',
      supportingCustom: pendingChip,
      compactMeta: hasPending,
      progress: hasPending ? null : ratio,
      progressColor: hasPending ? null : color,
      tint: hasPending ? const Color(0xFFF5A623).withValues(alpha: 0.6) : null,
      onTap: () => _openAllocationSheet(state, allocation, monthTx),
      actions: hasPending
          ? [
              _compactActionButton(
                label: 'تأكيد التحويل',
                onPressed: () async {
                  await context.read<BudgetCubit>()
                      .confirmAllocationDistribution(allocation.id);
                },
              ),
              _compactActionButton(
                label: 'تأجيل',
                filled: false,
                onPressed: () async {
                  await context.read<BudgetCubit>()
                      .postponeAllocationDistribution(allocation.id);
                },
              ),
            ]
          : [],
    );
  }

  Widget _jarSummaryTile(AppStateEntity state, LinkedWalletEntity jar,
      List<TransactionEntity> monthTx) {
    final hasPending = jar.pendingDistribution > 0;

    // ── شيب تأجيل لو في توزيع معلّق ──────────────────────────────────────
    Widget? pendingChip;
    if (hasPending) {
      pendingChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5A623).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF5A623).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded,
                size: 13, color: Color(0xFFF5A623)),
            const SizedBox(width: 4),
            Text(
              'ينتظر تأكيد تحويل ${jar.pendingDistribution.toStringAsFixed(0)} ج.م',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFF5A623),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return _entityTile(
      title: jar.name,
      leading: _iconBadge(jar.icon, jar.iconColor, size: hasPending ? 44 : 54),
      amountText: jar.balance.toStringAsFixed(2),
      metaText: 'المخصص الشهري ${jar.monthlyAmount.toStringAsFixed(2)}',
      supportingText: hasPending ? null : 'إجمالي رصيد الحصالة',
      supportingCustom: pendingChip,
      compactMeta: hasPending,
      progress: hasPending
          ? null
          : jar.monthlyAmount <= 0
              ? null
              : (monthTx
                          .where((t) =>
                              t.type == 'expense' && t.walletId == jar.id)
                          .fold<double>(0, (s, t) => s + t.amount) /
                      jar.monthlyAmount)
                  .clamp(0.0, 1.0)
                  .toDouble(),
      progressColor: hasPending
          ? null
          : jar.monthlyAmount <= 0
              ? null
              : _usageProgressColor((monthTx
                          .where((t) =>
                              t.type == 'expense' && t.walletId == jar.id)
                          .fold<double>(0, (s, t) => s + t.amount) /
                      jar.monthlyAmount)
                  .clamp(0.0, 1.0)
                  .toDouble()),
      tint: hasPending ? const Color(0xFFF5A623).withValues(alpha: 0.6) : null,
      onTap: () => _openJarDetailsSheet(jar),
      actions: hasPending
          ? [
              _compactActionButton(
                label: 'تأكيد التحويل',
                onPressed: () async {
                  await context.read<BudgetCubit>().confirmJarDistribution(jar.id);
                },
              ),
              _compactActionButton(
                label: 'تأجيل',
                filled: false,
                onPressed: () async {
                  await context.read<BudgetCubit>().postponeJarDistribution(jar.id);
                },
              ),
            ]
          : [],
    );
  }

  Future<void> _openJarDetailsSheet(LinkedWalletEntity jar) async {
    final state = context.read<BudgetCubit>().state.workspace;
    final distribution = {
      for (final s in jar.walletSources) s.walletId: s.amount
    };
    final relevantTransactions = state.transactions
        .where((t) => t.toWalletId == jar.id || t.walletId == jar.id)
        .where((t) =>
            // تحويلات الحصالة الداخلية
            t.transferType == 'jar-allocation' ||
            t.transferType == 'jar-allocation-cancel' ||
            t.transferType == 'jar-allocation-spend' ||
            t.transferType == 'allocation-to-jar' ||
            t.transferType == 'jar-to-allocation' ||
            (t.type == 'income' && t.budgetScope == 'within-budget') ||
            // مصروفات حقيقية مخصومة من الحصالة
            (t.type == 'expense' &&
                t.walletId == jar.id &&
                t.transferType == null))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final accent = _colorFromHex(jar.iconColor);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        var showWallets = false;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollCtrl) {
              final theme = Theme.of(ctx);
              return ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // ── Hero Card ────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.95),
                          accent.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.30),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: AppIconPickerDialog.iconWidgetForName(
                                      jar.icon,
                                      color: Colors.white,
                                      size: 32),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(jar.name,
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${jar.balance.toStringAsFixed(2)} جنيه',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white
                                              .withValues(alpha: 0.85)),
                                    ),
                                  ],
                                ),
                              ),
                              _jarIconAction(Icons.settings_outlined,
                                  onTap: () {
                                Navigator.of(ctx).pop();
                                Future.microtask(() {
                                  if (!mounted) return;
                                  _openBudgetSetupScreen();
                                });
                              }, tooltip: 'تعديل'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Expanded(
                                  child: _jarGlassMetric(
                                      label: 'الرصيد الكلي',
                                      value: jar.balance.toStringAsFixed(2),
                                      accent: accent)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _jarGlassMetric(
                                      label: 'شهري مخطط',
                                      value:
                                          jar.monthlyAmount.toStringAsFixed(2),
                                      accent: accent)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _jarGlassMetric(
                                      label: 'المحافظ',
                                      value: distribution.length.toString(),
                                      accent: accent)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () =>
                              setSheet(() => showWallets = !showWallets),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedRotation(
                                  turns: showWallets ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 260),
                                  child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  showWallets
                                      ? 'إخفاء التخصيصات'
                                      : 'عرض التخصيصات من المحافظ',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Wallet distribution ────────────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: showWallets
                        ? Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: accent,
                                        size: 17),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('التخصيصات من المحافظ',
                                      style: TextStyle(
                                          color: accent,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ]),
                                const SizedBox(height: 14),
                                if (distribution.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBF1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color:
                                              accent.withValues(alpha: 0.10)),
                                    ),
                                    child: const Text(
                                      'لا يوجد تخصيص من أي محفظة لهذه الحصالة حتى الآن.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Color(0xFF8A7F72),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  )
                                else
                                  ...distribution.entries.map((e) {
                                    final currentState = context.read<BudgetCubit>().state.workspace;
                                    final matchedWallets = currentState.wallets
                                        .where((w) => w.id == e.key)
                                        .toList();
                                    final walletName = matchedWallets.isEmpty
                                        ? 'محفظة'
                                        : matchedWallets.first.name;
                                    final walletIcon = matchedWallets.isEmpty
                                        ? 'account_balance_wallet'
                                        : (matchedWallets.first.icon ??
                                            'account_balance_wallet');
                                    final ratio = jar.balance <= 0
                                        ? 0.0
                                        : (e.value / jar.balance)
                                            .clamp(0.0, 1.0);
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBF1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: accent.withValues(
                                                  alpha: 0.14)),
                                        ),
                                        child: Column(children: [
                                          Row(children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: accent.withValues(
                                                    alpha: 0.10),
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                              ),
                                              child: Center(
                                                child: AppIconPickerDialog
                                                    .iconWidgetForName(
                                                        walletIcon,
                                                        color: accent,
                                                        size: 18),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Text(walletName,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 14))),
                                            Text(e.value.toStringAsFixed(2),
                                                style: TextStyle(
                                                    color: accent,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15)),
                                          ]),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: ratio,
                                              minHeight: 5,
                                              backgroundColor: accent
                                                  .withValues(alpha: 0.12),
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                      accent),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),
                  // ── Transactions ─────────────────────────────────────────
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: const Text('المعاملات',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 10),
                  if (relevantTransactions.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'لا توجد حركات مسجلة على هذه الحصالة حتى الآن.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF8A7F72),
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    ...relevantTransactions.map(
                        (t) => _trackingMonthTransactionTile(ctx, theme, t)),
                ],
              );
            },
          );
        });
      },
    );
  }

  Widget _jarGlassMetric({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _jarIconAction(IconData icon,
      {required VoidCallback onTap, required String tooltip}) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  List<Widget> _installmentCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    final installments = budget.debts.where((d) => d.isInstallment).toList();
    if (installments.isEmpty) {
      return [const BudgetStaticInfoCard(text: 'لا توجد ديون أو أقساط مسجلة.')];
    }
    final widgets = <Widget>[];
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
      final isSnoozed = pendingMeta?['snoozed'] == true;
      final isPending =
          pendingMeta?['pending'] == true && monthPaid < debt.amount;
      final remainingInstallments =
          debt.amount > 0 ? ((remaining - monthPaid) / debt.amount).ceil() : 0;
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
        actions: recurring == null
            ? <Widget>[]
            : isSnoozed
                ? <Widget>[
                    _compactActionButton(
                      label: 'إلغاء التأجيل',
                      filled: false,
                      onPressed: () => _clearDebtPostpone(recurring),
                    ),
                  ]
                : isPending
                    ? <Widget>[
                        _compactActionButton(
                          label: 'تسديد الآن',
                          onPressed: () {
                            _confirmDebtPayment(state, budget, debt, recurring);
                          },
                        ),
                        _compactActionButton(
                          label: 'تأجيل',
                          filled: false,
                          onPressed: () => _postponeDebt(recurring),
                        ),
                      ]
                    : <Widget>[],
      ));
    }
    return widgets;
  }

  List<Widget> _lentCards(
    AppStateEntity state,
    List<TransactionEntity> monthTx,
  ) {
    final allLent = state.recurringTransactions.where((r) => r.isLent).toList();
    if (allLent.isEmpty) return [];

    final cycleEnd = _cycleEndForWorkspace(state);

    // الأشخاص اللي حصل ليهم نشاط (سلفة أو استرداد) في الدورة دي
    final cycleLentPersons = allLent.where((r) {
      final name = r.lentPersonName ?? r.name;
      return state.transactions.any((t) =>
          ((t.notes?.contains('سلفة لـ $name') ?? false) ||
              (t.notes?.contains('استرداد سلفة من $name') ?? false)) &&
          !t.createdAt.isBefore(_cycleStart) &&
          !t.createdAt.isAfter(cycleEnd));
    }).toList();

    if (cycleLentPersons.isEmpty) return [];

    // إجمالي اللي اتسلف في الدورة دي (Outflow)
    double cycleTotalOut = 0;
    for (final person in cycleLentPersons) {
      final name = person.lentPersonName ?? person.name;
      final txs = state.transactions.where((t) =>
          t.type == 'expense' &&
          (t.notes?.contains('سلفة لـ $name') ?? false) &&
          !t.createdAt.isBefore(_cycleStart) &&
          !t.createdAt.isAfter(cycleEnd));
      cycleTotalOut += txs.fold(0.0, (s, t) => s + t.amount);
    }

    final hasOverdueGlobal = cycleLentPersons.any((r) =>
        r.hasOutstandingLent &&
        r.lentEntries.any((e) {
          if (e['isSettled'] == true) return false;
          final retStr = e['expectedReturnDate'] as String?;
          if (retStr == null) return false;
          final d = DateTime.tryParse(retStr);
          return d != null && d.isBefore(DateTime.now());
        }));

    final childTiles = cycleLentPersons.map((record) {
      final personName = record.lentPersonName ?? record.name;

      // نشاط الشخص ده في الدورة دي
      final personCycleTxs = state.transactions
          .where((t) =>
              ((t.notes?.contains('سلفة لـ $personName') ?? false) ||
                  (t.notes?.contains('استرداد سلفة من $personName') ??
                      false)) &&
              !t.createdAt.isBefore(_cycleStart) &&
              !t.createdAt.isAfter(cycleEnd))
          .toList();

      final out = personCycleTxs
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);
      final inc = personCycleTxs
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);

      final isOverdue = record.hasOutstandingLent &&
          record.lentEntries.any((e) {
            if (e['isSettled'] == true) return false;
            final retStr = e['expectedReturnDate'] as String?;
            if (retStr == null) return false;
            final d = DateTime.tryParse(retStr);
            return d != null && d.isBefore(DateTime.now());
          });

      String activityLabel = '';
      if (out > 0 && inc > 0) {
        activityLabel =
            'سلفة ${out.toStringAsFixed(0)} • استرداد ${inc.toStringAsFixed(0)}';
      } else if (out > 0) {
        activityLabel = 'سلفة ${out.toStringAsFixed(0)}';
      } else if (inc > 0) {
        activityLabel = 'استرداد ${inc.toStringAsFixed(0)}';
      }

      final balanceLabel =
          'المتبقي: ${record.outstandingLentAmount.toStringAsFixed(0)}';
      final statusLabel = isOverdue ? ' · متأخر ⚠️' : '';

      return _entityTile(
        title: personName,
        leading: _iconBadge(
          record.icon.isEmpty ? 'handshake' : record.icon,
          record.iconColor.isEmpty ? '#1a7a4a' : record.iconColor,
          size: 48,
        ),
        amountText: out > 0 ? out.toStringAsFixed(2) : inc.toStringAsFixed(2),
        metaText: '$activityLabel\n$balanceLabel$statusLabel',
        tint: isOverdue
            ? const Color(0xFFC65D2E)
            : (out > 0 ? null : const Color(0xFF1a7a4a)),
        onTap: () => _openBudgetLentDetailsSheet(record, state),
        embeddedInIncomeCard: true,
        actions: const [],
      );
    }).toList();

    final theme = Theme.of(context);
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _isLentExpanded = !_isLentExpanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _iconBadge('handshake', '#1a7a4a', size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سلف للناس',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${cycleLentPersons.length} نشاط سلف'
                              '${hasOverdueGlobal ? ' · يوجد متأخرات ⚠️' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: hasOverdueGlobal
                                    ? const Color(0xFFC65D2E)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            cycleTotalOut.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF165B47),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            _isLentExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isLentExpanded) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    ...childTiles,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _openBudgetLentDetailsSheet(
    RecurringTransactionEntity person,
    AppStateEntity state,
  ) async {
    const accent = Color(0xFF1a7a4a);
    final personName = person.lentPersonName ?? person.name;
    final theme = Theme.of(context);

    // كل معاملات الشخص ده (سلف + استردادات)
    final allPersonTxs = state.transactions
        .where(
          (t) =>
              (t.notes?.contains('سلفة لـ $personName') ?? false) ||
              (t.notes?.contains('استرداد سلفة من $personName') ?? false),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: allPersonTxs,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات مسجلة لهذا الشخص في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          // ── Hero Shell: بيانات الشخص + زر الإعداد ──────────────────
          _trackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _openLentSettingsFromBudget(person, context.read<BudgetCubit>().state.workspace);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconBadge(
                    person.icon.isEmpty ? 'handshake' : person.icon,
                    person.iconColor.isEmpty ? '#1a7a4a' : person.iconColor,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          personName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        BlocBuilder<BudgetCubit, BudgetState>(
                          builder: (_, budgetState) {
                            final s = budgetState.workspace;
                            final cur = s.recurringTransactions
                                    .where((r) => r.id == person.id)
                                    .cast<RecurringTransactionEntity?>()
                                    .firstWhere((_) => true,
                                        orElse: () => null) ??
                                person;
                            final pending = cur.lentEntries
                                .where((e) => e['isSettled'] != true)
                                .length;
                            return Text(
                              'إجمالي غير مسترد: ${cur.outstandingLentAmount.toStringAsFixed(2)} ج.م · $pending معلق',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<BudgetCubit, BudgetState>(
                    builder: (_, budgetState) {
                      final s = budgetState.workspace;
                      final cur = s.recurringTransactions
                              .where((r) => r.id == person.id)
                              .cast<RecurringTransactionEntity?>()
                              .firstWhere((_) => true, orElse: () => null) ??
                          person;
                      return Text(
                        cur.outstandingLentAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── كارت السلفات المعلقة القابل للتوسيع ─────────────────
              BlocBuilder<BudgetCubit, BudgetState>(
                builder: (_, budgetState) {
                  final s = budgetState.workspace;
                  final cur = s.recurringTransactions
                          .where((r) => r.id == person.id)
                          .cast<RecurringTransactionEntity?>()
                          .firstWhere((_) => true, orElse: () => null) ??
                      person;
                  return BudgetLentPendingCard(
                    theme: theme,
                    accent: accent,
                    person: cur,
                    cubit: context.read<AppCubit>(),
                    sheetCtx: sheetContext,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// فتح إعدادات السلف: إضافة سلفة جديدة لنفس الشخص
  Future<void> _openLentSettingsFromBudget(
    RecurringTransactionEntity person,
    AppStateEntity state,
  ) async {
    // نفتح شيت إضافة سلفة جديدة لنفس الشخص
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String walletId = person.walletId.isNotEmpty
        ? person.walletId
        : (state.wallets.isNotEmpty ? state.wallets.first.id : '');
    DateTime lentDate = DateTime.now();
    DateTime returnDate = DateTime.now().add(const Duration(days: 30));
    const accent = Color(0xFF1a7a4a);
    final personName = person.lentPersonName ?? person.name;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                          child: Icon(Icons.person_rounded,
                              color: Colors.white, size: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('سلفة جديدة لـ $personName',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const Text('المبلغ يُخصم من المحفظة فوراً',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ])),
                  ]),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                if (state.wallets.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: walletId.isEmpty ? null : walletId,
                        isExpanded: true,
                        hint: const Text('اختر المحفظة'),
                        items: state.wallets
                            .map((w) => DropdownMenuItem(
                                value: w.id, child: Text(w.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setS(() => walletId = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: lentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => lentDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                          'تاريخ السلفة: ${lentDate.day}/${lentDate.month}/${lentDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: returnDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (d != null) setS(() => returnDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                          'تاريخ الاسترداد المتوقع: ${returnDate.day}/${returnDate.month}/${returnDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
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
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0 || walletId.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('أدخل المبلغ والمحفظة')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await context.read<BudgetCubit>().addLentRecord(
                        personName: personName,
                        amount: amount,
                        walletId: walletId,
                        lentDate: lentDate,
                        expectedReturnDate: returnDate,
                        existingPersonId: person.id,
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

  List<Widget> _subscriptionCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    final subscriptions = budget.debts.where((d) => d.isSubscription).toList();
    if (subscriptions.isEmpty) {
      return [const BudgetStaticInfoCard(text: 'لا توجد اشتراكات مسجلة.')];
    }
    final widgets = <Widget>[];
    for (final debt in subscriptions) {
      final recurring = _linkedRecurringDebt(state, debt);
      final cycleDates = BudgetRecurringPlanService.occurrenceDatesInCycle(
        debt: debt,
        recurring: recurring,
        cycleStart: _cycleStart,
        cycleEnd: _cycleEndForWorkspace(state),
      );
      final isDueThisCycle = cycleDates.isNotEmpty;
      if (!isDueThisCycle) continue;

      final amountPerOccurrence =
          BudgetRecurringPlanService.amountPerOccurrence(
        debt: debt,
        recurring: recurring,
      );
      final cycleDue = amountPerOccurrence * cycleDates.length;
      final cyclePaid = monthTx
          .where((t) => _transactionCountsTowardDebt(t, debt))
          .fold<double>(0, (s, t) => s + t.amount);

      int paidCount = amountPerOccurrence > 0
          ? (cyclePaid / amountPerOccurrence).floor()
          : 0;
      if (paidCount > cycleDates.length) paidCount = cycleDates.length;

      final pendingDates = cycleDates.skip(paidCount).toList();
      final isFullyPaid = pendingDates.isEmpty;
      final nextDate = isFullyPaid ? null : pendingDates.first;

      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      final pendingMeta = _expensePendingMeta(recurring);
      final isSnoozed = pendingMeta?['snoozed'] == true;

      bool isDueOrLate = false;
      if (nextDate != null) {
        final nextMidnight =
            DateTime(nextDate.year, nextDate.month, nextDate.day);
        isDueOrLate = !todayMidnight.isBefore(nextMidnight);
      }
      final shouldShowDecision =
          pendingMeta?['pending'] == true && !isFullyPaid;

      String metaText;
      final amountLabel = amountPerOccurrence <= 0
          ? 'مجاني'
          : amountPerOccurrence.toStringAsFixed(2);
      if (isFullyPaid) {
        metaText = 'تم السداد ✓';
      } else {
        final nextStr = '${nextDate!.day}/${nextDate.month}';
        if (cycleDates.length > 1) {
          metaText = 'استحقاق يوم $nextStr · $amountLabel لكل مرة';
        } else {
          metaText = 'استحقاق يوم $nextStr · $amountLabel';
        }
      }

      widgets.add(_entityTile(
        title: debt.name,
        leading: _iconBadge(
          recurring?.icon ?? 'subscriptions',
          recurring?.iconColor ?? '#4a7c59',
          size: 54,
        ),
        amountText: cycleDue <= 0 ? 'مجاني' : cycleDue.toStringAsFixed(2),
        metaText: metaText,
        supportingText: _recurrenceLabel(
            recurring?.recurrencePattern ?? debt.recurrencePattern),
        progress: cycleDue <= 0
            ? null
            : (cyclePaid / cycleDue).clamp(0.0, 1.0).toDouble(),
        progressColor: Colors.teal,
        tint: (isDueOrLate || shouldShowDecision)
            ? const Color(0xFFC65D2E)
            : null,
        onTap: () => _openSubscriptionDetailsSheet(
          debt: debt,
          recurring: recurring,
          cycleDates: cycleDates,
          cyclePaid: cyclePaid,
          amountPerOccurrence: amountPerOccurrence,
          monthTx: monthTx,
        ),
        actions: recurring == null
            ? const <Widget>[]
            : isSnoozed
                ? <Widget>[
                    _compactActionButton(
                      label: 'إلغاء التأجيل',
                      filled: false,
                      onPressed: () => _clearDebtPostpone(recurring),
                    ),
                  ]
                : shouldShowDecision
                    ? <Widget>[
                        _compactActionButton(
                          label: 'تسديد الآن',
                          onPressed: () => _confirmDebtPayment(
                              state, budget, debt, recurring),
                        ),
                        _compactActionButton(
                          label: 'تأجيل',
                          filled: false,
                          onPressed: () => _postponeDebt(recurring),
                        ),
                      ]
                    : const <Widget>[],
      ));
    }
    if (widgets.isEmpty) {
      return [
        const BudgetStaticInfoCard(text: 'لا توجد اشتراكات مستحقة هذه الدورة.')
      ];
    }
    return widgets;
  }

  Future<void> _openSubscriptionDetailsSheet({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required List<DateTime> cycleDates,
    required double cyclePaid,
    required double amountPerOccurrence,
    required List<TransactionEntity> monthTx,
  }) async {
    final theme = Theme.of(context);
    final accent = _colorFromHex(recurring?.iconColor ?? '#4a7c59');

    final tx = monthTx
        .where((t) => _transactionCountsTowardDebt(t, debt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int paidCount =
        amountPerOccurrence > 0 ? (cyclePaid / amountPerOccurrence).floor() : 0;
    if (paidCount > cycleDates.length) paidCount = cycleDates.length;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: tx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات دفع لهذا الاشتراك.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          _trackingDetailHeroShell(
            accent: accent,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconBadge(
                    recurring?.icon ?? 'subscriptions',
                    recurring?.iconColor ?? '#4a7c59',
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
                          'استحقاقات الشهر (${cycleDates.length})',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(cycleDates.length, (index) {
                final date = cycleDates[index];
                final isPaid = index < paidCount;
                final dateStr = '${date.day}/${date.month}';

                final today = DateTime.now();
                final todayMidnight =
                    DateTime(today.year, today.month, today.day);
                final occurrenceMidnight =
                    DateTime(date.year, date.month, date.day);
                final isDueOrLate = !todayMidnight.isBefore(occurrenceMidnight);

                final statusText =
                    isPaid ? 'مسدد ✓' : (isDueOrLate ? 'مستحق الآن' : 'قادم');
                final statusColor = isPaid
                    ? Colors.green
                    : (isDueOrLate
                        ? const Color(0xFFC65D2E)
                        : theme.colorScheme.onSurfaceVariant);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'استحقاق $dateStr',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        amountPerOccurrence.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
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
      builder: (sheetContext) => DraggableFilterableTxSheet(
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
    final state = context.read<BudgetCubit>().state.workspace;
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
      await context.read<BudgetCubit>().updateBudgetSetup(
        budget.copyWith(allocations: next),
      );
      return;
    }

    final updated = result.entity;
    if (updated == null) return;
    final next =
        budget.allocations.map((e) => e.id == _.id ? updated : e).toList();
    await context.read<BudgetCubit>().updateBudgetSetup(
      budget.copyWith(allocations: next),
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
        _incomePendingMeta(context.read<BudgetCubit>().state.workspace, source, sourceIncomeTx);
    final canEarly = pendingMeta?['canEarly'] == true;
    final isDueOrLate = pendingMeta?['isDueOrLate'] == true;
    final recurring = _linkedRecurringIncome(context.read<BudgetCubit>().state.workspace, source);
    final cycleTx = _monthTransactionsForIncomeSource(sourceIncomeTx);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: cycleTx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات دخل مسجلة لهذا المصدر في المدة المحددة.',
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
    final state = context.read<BudgetCubit>().state.workspace;
    final budget = state.budgetSetup;
    final recurring = _linkedRecurringDebt(state, debt);
    final now = DateTime.now();
    final dueDate = debt.isSubscription && recurring != null
        ? (RecurringScheduleEngine.dueOccurrenceNow(recurring, now) ??
            RecurringScheduleEngine.nextOccurrence(recurring, now) ??
            DateTime(
              _month.year,
              _month.month,
              debt.executionDay.clamp(1, 28),
            ))
        : DateTime(
            _month.year,
            _month.month,
            debt.executionDay.clamp(1, 28),
          );
    final paid = tx.fold<double>(0, (s, t) => s + t.amount);
    final principal = debt.principalTotal ?? debt.amount;
    final dueThisCycle = BudgetRecurringPlanService.amountDueInCycle(
      debt: debt,
      recurring: recurring,
      cycleStart: _cycleStart,
      cycleEnd: _cycleEndForWorkspace(state),
    );
    final paidRatio = debt.isSubscription
        ? (dueThisCycle <= 0 ? null : (paid / dueThisCycle).clamp(0.0, 1.0))
        : (principal <= 0 ? null : (paid / principal).clamp(0.0, 1.0));

    // حسابات دفعات القسط في هذه الدورة
    final monthTx = state.transactions
        .where((t) => _transactionCountsTowardDebt(t, debt))
        .where((t) =>
            !t.createdAt.isBefore(_cycleStart) &&
            !t.createdAt.isAfter(_cycleEndForWorkspace(state)))
        .toList();
    final monthPaid = monthTx.fold<double>(0, (s, t) => s + t.amount);
    final installmentAmt = debt.amount;
    final currentPaid = monthPaid >= installmentAmt;
    final isSinglePaymentInstallment =
        debt.installmentCount == 1 || principal <= installmentAmt;
    final nextPaid =
        isSinglePaymentInstallment || monthPaid >= installmentAmt * 2;

    final sortedTx = [...tx]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pctLabel =
        paidRatio == null ? '0' : (paidRatio * 100).round().toString();
    final headerLabel = debt.isSubscription
        ? 'استحقاق ${_monthWordLabel(dueDate)} · ${_recurrenceLabel(recurring?.recurrencePattern ?? debt.recurrencePattern)}'
        : 'استحقاق ${_monthWordLabel(dueDate)} · الأصل ${principal.toStringAsFixed(2)}';
    final progressLabel = debt.isSubscription
        ? 'تم سداد $pctLabel٪ · المدفوع ${paid.toStringAsFixed(2)} من قيمة الدورة ${dueThisCycle.toStringAsFixed(2)}'
        : 'تم سداد $pctLabel٪ · المتبقي ${remaining.toStringAsFixed(2)} من أصل ${principal.toStringAsFixed(2)}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableFilterableTxSheet(
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
                          headerLabel,
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
                progressLabel,
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
              // ── قسم الدفعات القابل للتوسع ────────────────────────────
              if (debt.isInstallment && recurring != null) ...[
                const SizedBox(height: 14),
                InstallmentPaymentsCard(
                  theme: theme,
                  debt: debt,
                  recurring: recurring,
                  installmentAmt: installmentAmt,
                  currentPaid: currentPaid,
                  nextPaid: nextPaid,
                  showNextPayment: !isSinglePaymentInstallment,
                  dueDate: dueDate,
                  onPayCurrent: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDebtPayment(state, budget, debt, recurring);
                  },
                  onPayNext: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDebtPayment(state, budget, debt, recurring);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editIncomeDirect(IncomeSourceEntity current) async {
    final state = context.read<BudgetCubit>().state.workspace;
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
          cubit: context.read<AppCubit>(),
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

    final setup = context.read<BudgetCubit>().state.workspace.budgetSetup;
    if (result.deleteRequested) {
      final linked = context.read<BudgetCubit>().state.workspace.recurringTransactions
          .where((r) => r.incomeSourceId == current.id)
          .toList();
      for (final recurring in linked) {
        await context.read<BudgetCubit>().deleteRecurringTransaction(recurring.id);
      }
      if (linked.isEmpty && linkedRecurring != null) {
        await context.read<BudgetCubit>().deleteRecurringTransaction(linkedRecurring.id);
      }
      final incomes =
          setup.incomeSources.where((e) => e.id != current.id).toList();
      await context.read<BudgetCubit>()
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
    await context.read<BudgetCubit>()
        .updateBudgetSetup(setup.copyWith(incomeSources: incomes));

    if (linkedRecurring == null) {
      await context.read<BudgetCubit>().addRecurringTransaction(
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
      await context.read<BudgetCubit>().updateRecurringTransaction(
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
    final state = context.read<BudgetCubit>().state.workspace;
    final linkedRecurring = _linkedRecurringDebt(state, current);
    final fallbackWalletId = state.wallets.isNotEmpty
        ? state.wallets.first.id
        : 'wallet-cash-default';
    final draftRecurring = (linkedRecurring ??
            RecurringTransactionEntity(
              id: current.recurringTransactionId ?? '',
              name: current.name,
              type: 'expense',
              amount: current.amount,
              dayOfMonth: current.executionDay.clamp(1, 28),
              executionType: current.type,
              walletId: fallbackWalletId,
              budgetScope: 'within-budget',
              recurrencePattern: current.recurrencePattern,
              icon: 'receipt',
              iconColor: '#c65d2e',
              monthOfYear: current.monthOfYear,
              isDebtOrSubscription: true,
              expensePlanKind:
                  current.isSubscription ? 'subscription' : 'installment',
              debtPrincipalTotal: current.principalTotal ??
                  (current.isInstallment && current.amount > 0
                      ? current.amount
                      : null),
            ))
        .copyWith(
      recurrencePattern: current.recurrencePattern != 'monthly'
          ? current.recurrencePattern
          : (linkedRecurring?.recurrencePattern ?? current.recurrencePattern),
      monthOfYear: current.monthOfYear ?? linkedRecurring?.monthOfYear,
      expensePlanKind: linkedRecurring?.expensePlanKind ??
          (current.isSubscription ? 'subscription' : 'installment'),
      debtPrincipalTotal: linkedRecurring?.debtPrincipalTotal ??
          current.principalTotal ??
          (current.isInstallment && current.amount > 0 ? current.amount : null),
    );
    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: context.read<AppCubit>(),
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

    final setup = context.read<BudgetCubit>().state.workspace.budgetSetup;
    if (result.deleteRequested) {
      if ((current.recurringTransactionId ?? '').isNotEmpty) {
        await context.read<BudgetCubit>()
            .deleteRecurringTransaction(current.recurringTransactionId!);
      } else if (linkedRecurring != null) {
        await context.read<BudgetCubit>().deleteRecurringTransaction(linkedRecurring.id);
      }
      final next = setup.debts.where((d) => d.id != current.id).toList();
      await context.read<BudgetCubit>().updateBudgetSetup(setup.copyWith(debts: next));
      return;
    }

    final recurring = result.recurring;
    if (recurring == null) {
      return;
    }

    final recurringId =
        linkedRecurring?.id ?? current.recurringTransactionId ?? _id('rec');
    final isSubscription = recurring.expensePlanKind == 'subscription';
    final principal = recurring.debtPrincipalTotal;
    final updated = DebtEntity(
      id: current.id,
      name: recurring.name,
      amount: recurring.amount,
      executionDay: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.executionType,
      fundingSource: current.fundingSource,
      recurringTransactionId: recurringId,
      kind: isSubscription ? 'subscription' : 'installment',
      principalTotal: isSubscription
          ? null
          : (principal != null && principal > 0 ? principal : null),
      installmentCount: isSubscription ? null : recurring.installmentCount,
      downPayment: isSubscription ? null : recurring.installmentDownPayment,
      recurrencePattern: recurring.recurrencePattern,
      monthOfYear: recurring.monthOfYear,
    );
    final next =
        setup.debts.map((d) => d.id == current.id ? updated : d).toList();
    await context.read<BudgetCubit>().updateBudgetSetup(setup.copyWith(debts: next));

    final recurringToSave = recurring.copyWith(
      id: recurringId,
      type: 'expense',
      budgetScope: 'within-budget',
      isDebtOrSubscription: true,
      allocationId: null,
      targetJarId: null,
    );
    if (linkedRecurring == null) {
      await context.read<BudgetCubit>().addRecurringTransaction(
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
        anchorDate: recurringToSave.anchorDate,
        scheduledTime: recurringToSave.scheduledTime,
        reminderLeadDays: recurringToSave.reminderLeadDays,
        isDebtOrSubscription: true,
        expensePlanKind: recurringToSave.expensePlanKind,
        debtPrincipalTotal: recurringToSave.debtPrincipalTotal,
        installmentCount: recurringToSave.installmentCount,
        installmentDownPayment: recurringToSave.installmentDownPayment,
        notes: recurringToSave.notes,
      );
    } else {
      await context.read<BudgetCubit>().updateRecurringTransaction(recurringToSave);
    }
  }

  RecurringTransactionEntity? _linkedRecurringDebt(
    AppStateEntity state,
    DebtEntity debt,
  ) =>
      BudgetRecurringPlanService.linkedRecurring(
        state.recurringTransactions,
        debt,
      );

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

  DateTime? _nextRecurringOccurrence(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) =>
      RecurringScheduleEngine.nextOccurrence(recurring, now);

  Map<String, dynamic>? _expensePendingMeta(
      RecurringTransactionEntity? recurring) {
    if (recurring == null) {
      return null;
    }
    final now = DateTime.now();
    final fallbackOccurrence = _dueOccurrenceNow(recurring, now) ??
        _nextRecurringOccurrence(recurring, now);
    final snoozedUntil = recurring.snoozedUntil == null
        ? null
        : DateTime.tryParse(recurring.snoozedUntil!);
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
      return <String, dynamic>{
        'status':
            'مؤجل حتى ${DateFormat('d MMMM - h:mm a', 'ar').format(snoozedUntil)}',
        'occurrence': fallbackOccurrence,
        'pending': false,
        'snoozed': true,
      };
    }
    final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
    if (prompt != null) {
      return <String, dynamic>{
        'status': switch (prompt.state) {
          RecurringExpensePromptState.upcoming =>
            'مستحق قريبًا ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
          RecurringExpensePromptState.due =>
            'مستحق الآن ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
          RecurringExpensePromptState.overdue => prompt.catchUpFromAuto
              ? 'دورة فائتة تحتاج قرارًا ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}'
              : 'استحقاق متأخر ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
        },
        'occurrence': prompt.occurrence,
        'pending': true,
        'snoozed': false,
      };
    }

    final occurrence = fallbackOccurrence;
    if (occurrence == null) return null;
    return <String, dynamic>{
      'status':
          'الاستحقاق القادم ${DateFormat('d/M - h:mm a', 'ar').format(occurrence)}',
      'occurrence': occurrence,
      'pending': false,
      'snoozed': false,
    };
  }

  bool _occurrenceWasHandled(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) =>
      RecurringScheduleEngine.wasOccurrenceHandled(recurring, occurrence);

  DateTime? _dueOccurrenceNow(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) =>
      RecurringScheduleEngine.dueOccurrenceNow(recurring, now);

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
        final snoozedUntil =
            recurring.snoozedUntil == null || recurring.snoozedUntil!.isEmpty
                ? null
                : DateTime.tryParse(recurring.snoozedUntil!);
        if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
          continue;
        }
        final occurrence = _dueOccurrenceNow(recurring, now);
        if (occurrence == null ||
            _occurrenceWasHandled(recurring, occurrence)) {
          continue;
        }
        // منع التكرار بسبب rebuild خلال نفس الـ session
        final occKey = '${recurring.id}__${occurrence.toIso8601String()}';
        if (_handledOccurrenceKeys.contains(occKey)) continue;
        _handledOccurrenceKeys.add(occKey);
        if (!RecurringScheduleEngine.isSameCalendarDay(occurrence, now)) {
          continue;
        }
        if (debt.isInstallment) {
          final paid = monthTx
              .where((t) => _transactionCountsTowardDebt(t, debt))
              .fold<double>(0, (sum, t) => sum + t.amount);
          final remaining = (debt.amount - paid).clamp(0.0, debt.amount);
          if (remaining <= 0) {
            await context.read<BudgetCubit>().updateRecurringTransaction(
              recurring.copyWith(
                lastHandledOccurrenceAt: occurrence.toIso8601String(),
                snoozedUntil: '',
              ),
            );
            continue;
          }
        }
        // تحقق إن المعاملة دي مش اتسجلت فعلاً في الدورة الحالية
        final alreadyPaidThisCycle = monthTx
            .where((t) =>
                t.type == 'expense' &&
                t.walletId == recurring.walletId &&
                t.notes?.contains(debt.name) == true &&
                RecurringScheduleEngine.isSameCalendarDay(t.createdAt, now))
            .isNotEmpty;
        if (alreadyPaidThisCycle) {
          _handledOccurrenceKeys.add(occKey);
          continue;
        }

        await context.read<BudgetCubit>().addTransaction(
          walletId: recurring.walletId,
          amount: recurring.amount,
          type: 'expense',
          budgetScope: 'within-budget',
          createdAt: now,
          notes: 'خصم تلقائي دين: ${debt.name}',
        );
        await context.read<BudgetCubit>().updateRecurringTransaction(
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
    await context.read<BudgetCubit>().addTransaction(
      walletId: source.targetWalletId,
      amount: amount,
      type: 'income',
      incomeSourceId: source.id,
      budgetScope: 'within-budget',
      createdAt: DateTime(now.year, now.month, now.day, 12),
      details: early
          ? 'تسجيل دخل مبكر: ${source.name} بقيمة ${amount.toStringAsFixed(2)}'
          : 'تأكيد نزول دخل: ${source.name} بقيمة ${amount.toStringAsFixed(2)}',
    );
  }

  // Removed local _showPostponeDialog in favor of RecurringPostponeDialog

  Future<void> _postponeIncome(IncomeSourceEntity source) async {
    final dueDate = _incomeDueDateForMonth(source, _month);
    final result = await RecurringPostponeDialog.show(
      context,
      name: source.name,
      amount: source.amount,
      kindLabel: 'راتب / دخل',
      occurrence: dueDate,
      allowSkip: false,
    );

    if (result == null || result is! DateTime) return;

    final setup = context.read<BudgetCubit>().state.workspace.budgetSetup;
    final updatedIncomes = setup.incomeSources.map((i) {
      if (i.id != source.id) return i;
      return i.copyWith(snoozedUntil: result.toIso8601String());
    }).toList();

    await context.read<BudgetCubit>().updateBudgetSetup(
      setup.copyWith(incomeSources: updatedIncomes),
      detailsOverride:
          'تأجيل دخل: ${source.name} حتى ${DateFormat('d MMMM yyyy - HH:mm', 'ar').format(result)}',
    );
  }

  Future<void> _postponeDebt(RecurringTransactionEntity recurring) async {
    final now = DateTime.now();
    final occurrence = _dueOccurrenceNow(recurring, now) ??
        _nextRecurringOccurrence(recurring, now) ??
        now;
    final result = await RecurringPostponeDialog.show(
      context,
      name: recurring.name,
      amount: recurring.amount,
      kindLabel:
          recurring.expensePlanKind == 'subscription' ? 'اشتراك' : 'دفعة دين',
      occurrence: occurrence,
      allowSkip: true,
    );

    if (result == null) return;

    if (result == PostponeChoice.skip) {
      await context.read<BudgetCubit>().updateRecurringTransaction(
        recurring.copyWith(
          lastHandledOccurrenceAt: occurrence.toIso8601String(),
          snoozedUntil: '',
        ),
        detailsOverride:
            'تخطي هذه المرة: ${recurring.name} بقيمة ${recurring.amount.toStringAsFixed(2)}',
      );
      return;
    }

    if (result is DateTime) {
      await context.read<BudgetCubit>().updateRecurringTransaction(
        recurring.copyWith(snoozedUntil: result.toIso8601String()),
        detailsOverride:
            'تأجيل معاملة متكررة: ${recurring.name} بقيمة ${recurring.amount.toStringAsFixed(2)} حتى ${DateFormat('d MMMM yyyy - HH:mm', 'ar').format(result)}',
      );
    }
  }

  Future<void> _clearDebtPostpone(RecurringTransactionEntity recurring) async {
    await context.read<BudgetCubit>().updateRecurringTransaction(
      recurring.copyWith(snoozedUntil: ''),
    );
  }

  Future<void> _recordDebtFromTracking(
    DebtEntity debt,
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) async {
    await context.read<BudgetCubit>().addTransaction(
      walletId: recurring.walletId,
      amount: debt.amount,
      type: 'expense',
      budgetScope: 'within-budget',
      createdAt: DateTime.now(),
      notes: 'سداد دين: ${debt.name}',
      details: 'سداد دين: ${debt.name} بقيمة ${debt.amount.toStringAsFixed(2)}',
    );
    await context.read<BudgetCubit>().updateRecurringTransaction(
      recurring.copyWith(
        lastHandledOccurrenceAt: occurrence.toIso8601String(),
        snoozedUntil: '',
      ),
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
                  subtitle: Text(DateFormat('d MMMM - h:mm a', 'ar')
                      .format(item.createdAt)),
                  trailing: Text(item.amount.toStringAsFixed(2)),
                  onTap: () => openTransactionDetailsSheet(
                    context,
                    cubit: context.read<AppCubit>(),
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
        t.transferType == 'jar-allocation-spend' ||
        t.transferType == 'jar-funding' ||
        t.transferType == 'allocation-to-jar';
  }
}
