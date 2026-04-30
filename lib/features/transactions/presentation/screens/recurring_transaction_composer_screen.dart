import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../data/subscription_service_presets.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/services/recurring_schedule_engine.dart';
import '../widgets/subscription_service_picker_sheet.dart';

class RecurringTransactionComposerResult {
  const RecurringTransactionComposerResult._({
    this.recurring,
    this.deleteRequested = false,
  });

  const RecurringTransactionComposerResult.saved(
    RecurringTransactionEntity recurring,
  ) : this._(recurring: recurring);

  const RecurringTransactionComposerResult.deleted()
      : this._(deleteRequested: true);

  final RecurringTransactionEntity? recurring;
  final bool deleteRequested;
}

class RecurringTransactionComposerScreen extends StatefulWidget {
  const RecurringTransactionComposerScreen({
    super.key,
    required this.cubit,
    required this.initialType,
    this.initialRecurring,
    this.initialWithinBudget = false,
    this.initialExpensePlanKind,
    this.returnOnSave = false,
    this.allowDelete = false,
  });

  final AppCubit cubit;
  final String initialType;
  final RecurringTransactionEntity? initialRecurring;
  final bool initialWithinBudget;
  final String? initialExpensePlanKind;
  final bool returnOnSave;
  final bool allowDelete;

  @override
  State<RecurringTransactionComposerScreen> createState() =>
      _RecurringTransactionComposerScreenState();
}

class _RecurringTransactionComposerScreenState
    extends State<RecurringTransactionComposerScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _debtPrincipalController = TextEditingController();
  final _notesController = TextEditingController();

  late String _type;
  late String _walletId;
  late bool _withinBudget;
  late String _executionType;
  late String _recurrencePattern;
  late String _iconName;
  late String _iconColor;
  late String _expensePlanKind;

  bool _isVariableIncome = false;
  bool _isDebtOrSubscription = true;
  bool _isSaving = false;
  int _monthlyDay = 1;
  int _yearlyMonth = 1;
  int _yearlyDay = 1;
  int _reminderLeadDays = 0;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _selectedWeekdays = <int>{};
  final Set<String> _selectedCategoryIds = <String>{};
  String? _allocationId;
  String? _targetJarId;
  String? _selectedSubscriptionPresetId;

  @override
  void initState() {
    super.initState();
    final state = widget.cubit.state;
    final recurring = widget.initialRecurring;
    _type = recurring?.type ?? widget.initialType;
    _walletId = recurring?.walletId ??
        (state.wallets.isNotEmpty ? state.wallets.first.id : '');
    _withinBudget = recurring != null
        ? recurring.budgetScope == 'within-budget'
        : widget.initialWithinBudget;
    _executionType = recurring?.executionType ?? 'confirm';
    _recurrencePattern = recurring?.recurrencePattern ?? 'monthly';
    _iconName = recurring?.icon ?? (_type == 'income' ? 'cash' : 'category');
    _iconColor =
        recurring?.iconColor ?? (_type == 'income' ? '#0f9d7a' : '#c65d2e');
    _expensePlanKind = recurring?.expensePlanKind ??
        widget.initialExpensePlanKind ??
        (_type == 'expense' && _withinBudget ? 'installment' : 'normal');
    _nameController.text = recurring?.name ?? '';
    _amountController.text = recurring == null
        ? ''
        : recurring.amount <= 0
            ? ''
            : recurring.amount.toStringAsFixed(2);
    _notesController.text = recurring?.notes ?? '';
    final principal = recurring?.debtPrincipalTotal;
    _debtPrincipalController.text =
        principal != null && principal > 0 ? principal.toStringAsFixed(2) : '';
    _isVariableIncome = recurring?.isVariableIncome ?? false;
    _isDebtOrSubscription = recurring?.isDebtOrSubscription ??
        (_expensePlanKind == 'installment' || _expensePlanKind == 'subscription');
    _monthlyDay = (recurring?.dayOfMonth ?? 1).clamp(1, 28);
    _yearlyDay = (recurring?.dayOfMonth ?? 1).clamp(1, 28);
    _yearlyMonth =
        (recurring?.monthOfYear ?? DateTime.now().month).clamp(1, 12);
    _reminderLeadDays = recurring?.reminderLeadDays ?? 0;
    _allocationId = recurring?.allocationId;
    _targetJarId = recurring?.targetJarId;
    _selectedCategoryIds.addAll(recurring?.categoryIds ?? const <String>[]);
    _selectedWeekdays.addAll(
      recurring?.weekdays.isNotEmpty == true
          ? recurring!.weekdays
          : recurring?.weekday != null
              ? <int>{recurring!.weekday!}
              : <int>{DateTime.now().weekday},
    );
    _selectedTime = _parseStoredTime(recurring?.scheduledTime);
    _selectedSubscriptionPresetId =
        subscriptionPresetByName(recurring?.name)?.id;

    if (_type == 'income' && _withinBudget && _isVariableIncome) {
      _executionType = 'manual';
    }

    _nameController.addListener(_refreshFormState);
    _amountController.addListener(_refreshFormState);
    _debtPrincipalController.addListener(_refreshFormState);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshFormState);
    _amountController.removeListener(_refreshFormState);
    _debtPrincipalController.removeListener(_refreshFormState);
    _nameController.dispose();
    _amountController.dispose();
    _debtPrincipalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _showAmount =>
      !(_type == 'income' && _withinBudget && _isVariableIncome);

  bool get _showRecurrenceDetails =>
      !(_type == 'income' && _withinBudget && _isVariableIncome);

  bool get _isWeekPattern =>
      _recurrencePattern == 'weekly' ||
      _recurrencePattern == 'biweekly' ||
      _recurrencePattern == 'every_3_weeks';

  bool get _isMonthPattern =>
      _recurrencePattern == 'monthly' ||
      _recurrencePattern == 'every_2_months' ||
      _recurrencePattern == 'every_3_months' ||
      _recurrencePattern == 'every_6_months';

  bool get _isExpenseInstallment => _expensePlanKind == 'installment';

  bool get _isExpenseSubscription => _expensePlanKind == 'subscription';

  bool get _canSave {
    if (_isSaving || _nameController.text.trim().isEmpty || _walletId.isEmpty) {
      return false;
    }
    if (_showAmount &&
        (double.tryParse(_amountController.text.trim()) ?? 0) <= 0) {
      return false;
    }
    if (_type == 'expense' &&
        _withinBudget &&
        !_isDebtOrSubscription &&
        _allocationId == null &&
        _targetJarId == null) {
      return false;
    }
    if (_showRecurrenceDetails && _isWeekPattern && _selectedWeekdays.isEmpty) {
      return false;
    }
    return true;
  }

  void _refreshFormState() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.cubit.state;
    final budget = state.budgetSetup;
    final wallets = state.wallets;
    final visibleCategories = _visibleCategories(state.categories, budget);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.initialRecurring == null
            ? 'إضافة معاملة متكررة'
            : 'تعديل معاملة متكررة'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _typeSwitcher(theme),
            const SizedBox(height: 14),
            if (_type == 'expense') ...[
              _expenseKindSection(),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المعاملة',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (_type == 'income' && _withinBudget) ...[
              _surfaceSection(
                child: SwitchListTile.adaptive(
                  value: _isVariableIncome,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('دخل متغير'),
                  subtitle: const Text(
                    'الدخل المتغير يكون يدويًا ولا يحتاج مبلغ أو توقيت ثابت',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _isVariableIncome = value;
                      if (value) {
                        _executionType = 'manual';
                        _amountController.clear();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_showAmount) ...[
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _type == 'expense' &&
                          _withinBudget &&
                          _isExpenseInstallment
                      ? 'مبلغ القسط أو الدفعة'
                      : 'المبلغ',
                  prefixIcon: const Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_type == 'expense' &&
                _withinBudget &&
                _isExpenseInstallment) ...[
              TextField(
                controller: _debtPrincipalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'إجمالي الدين (الأصل)',
                  helperText:
                      'مثل ١٠٠٠٠ — يُستخدم في الميزانية لحساب المتبقي والنسبة',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              value: _walletId.isEmpty ? null : _walletId,
              decoration: const InputDecoration(
                labelText: 'المحفظة',
                prefixIcon: Icon(Icons.account_balance_wallet_rounded),
              ),
              items: wallets
                  .map(
                    (wallet) => DropdownMenuItem<String>(
                      value: wallet.id,
                      child: Text(wallet.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _walletId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            _surfaceSection(
              child: SwitchListTile.adaptive(
                value: _withinBudget,
                contentPadding: EdgeInsets.zero,
                title: const Text('داخل الميزانية'),
                subtitle: Text(
                  _withinBudget
                      ? 'المعاملة ستدخل في تخطيط الميزانية'
                      : 'المعاملة ستبقى خارج حسابات الميزانية',
                ),
                onChanged: (value) {
                  setState(() {
                    _withinBudget = value;
                    if (!value) {
                      _allocationId = null;
                      _targetJarId = null;
                      _isDebtOrSubscription = false;
                      _expensePlanKind = 'normal';
                      _isVariableIncome = false;
                    } else if (_type == 'expense') {
                      _expensePlanKind = widget.initialExpensePlanKind ??
                          _expensePlanKind;
                      _isDebtOrSubscription = _expensePlanKind != 'normal';
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_type == 'expense' && _isExpenseSubscription) ...[
              _subscriptionSuggestionSection(),
              const SizedBox(height: 12),
            ],
            if (_withinBudget) ...[
              _surfaceSection(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الأيقونة واللون'),
                  subtitle: const Text('تظهر داخل التخطيط والميزانية'),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _parseColor(_iconColor).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AppIconPickerDialog.iconWidgetForName(
                      _iconName,
                      color: _parseColor(_iconColor),
                      size: 22,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickIcon,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_type == 'expense' && _withinBudget) ...[
              _budgetTargetSection(budget),
              const SizedBox(height: 12),
            ],
            _categorySection(visibleCategories),
            const SizedBox(height: 12),
            if (_showRecurrenceDetails) ...[
              DropdownButtonFormField<String>(
                value: _recurrencePattern,
                decoration: const InputDecoration(
                  labelText: 'نوع التكرار',
                  prefixIcon: Icon(Icons.repeat_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('يومي')),
                  DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                  DropdownMenuItem(
                      value: 'biweekly', child: Text('كل أسبوعين')),
                  DropdownMenuItem(
                      value: 'every_3_weeks', child: Text('كل 3 أسابيع')),
                  DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                  DropdownMenuItem(
                      value: 'every_2_months', child: Text('كل شهرين')),
                  DropdownMenuItem(
                      value: 'every_3_months', child: Text('كل 3 شهور')),
                  DropdownMenuItem(
                      value: 'every_6_months', child: Text('كل 6 شهور')),
                  DropdownMenuItem(value: 'yearly', child: Text('سنوي')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _recurrencePattern = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _recurrenceDetails(),
              const SizedBox(height: 12),
            ],
            if (_type == 'income' && _withinBudget && _isVariableIncome)
              _surfaceSection(
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('دخل متغير'),
                  subtitle: Text(
                    'سيتم تسجيله يدويًا فقط بدون تاريخ أو تكرار ثابت',
                  ),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                value: _executionType,
                decoration: const InputDecoration(
                  labelText: 'طريقة التنفيذ',
                  prefixIcon: Icon(Icons.bolt_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('تلقائي')),
                  DropdownMenuItem(
                      value: 'confirm', child: Text('يحتاج تأكيد')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _executionType = value);
                  }
                },
              ),
              if (_executionType == 'confirm') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _reminderLeadDays,
                  decoration: InputDecoration(
                    labelText: _recurrencePattern == 'daily' || _isWeekPattern
                        ? 'وقت الإشعار'
                        : 'وقت الإشعار',
                    prefixIcon: const Icon(Icons.notifications_active_rounded),
                  ),
                  items: (_recurrencePattern == 'daily' || _isWeekPattern)
                      ? const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text('في الوقت المحدد'),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text('قبلها بساعة'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('قبلها بساعتين'),
                          ),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('قبلها بـ 3 ساعات'),
                          ),
                        ]
                      : const [
                          DropdownMenuItem(
                              value: 0, child: Text('في نفس اليوم')),
                          DropdownMenuItem(value: 1, child: Text('مبكر بيوم')),
                          DropdownMenuItem(
                              value: 2, child: Text('مبكر بيومين')),
                          DropdownMenuItem(
                              value: 3, child: Text('مبكر بـ 3 أيام')),
                        ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _reminderLeadDays = value);
                    }
                  },
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_isSaving
                    ? 'جارٍ الحفظ...'
                    : widget.initialRecurring == null
                        ? 'حفظ المعاملة المتكررة'
                        : 'تحديث المعاملة المتكررة'),
              ),
            ),
            if (widget.allowDelete && widget.initialRecurring != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _deleteFromComposer,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف المعاملة'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeSwitcher(ThemeData theme) {
    final isIncome = _type == 'income';
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _switcherItem(
              selected: !isIncome,
              label: 'مصروف',
              icon: Icons.arrow_outward_rounded,
              onTap: () {
                setState(() {
                  _type = 'expense';
                  if (_withinBudget) {
                    _expensePlanKind = widget.initialExpensePlanKind ??
                        (_expensePlanKind == 'normal'
                            ? 'installment'
                            : _expensePlanKind);
                    _isDebtOrSubscription = _expensePlanKind != 'normal';
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _switcherItem(
              selected: isIncome,
              label: 'دخل',
              icon: Icons.arrow_downward_rounded,
              onTap: () {
                setState(() {
                  _type = 'income';
                  _allocationId = null;
                  _targetJarId = null;
                  _expensePlanKind = 'normal';
                  _isDebtOrSubscription = false;
                  _selectedSubscriptionPresetId = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _switcherItem({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : theme.colorScheme.onSurface),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surfaceSection({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
  }

  Widget _expenseKindSection() {
    return _surfaceSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نوع العملية',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _planChoiceTile(
                  label: 'مصروف عادي',
                  icon: Icons.repeat_rounded,
                  selected: _expensePlanKind == 'normal',
                  onTap: () {
                    setState(() {
                      _expensePlanKind = 'normal';
                      _isDebtOrSubscription = false;
                      _debtPrincipalController.clear();
                      _selectedSubscriptionPresetId = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _planChoiceTile(
                  label: 'تقسيط',
                  icon: Icons.account_balance_outlined,
                  selected: _isExpenseInstallment,
                  onTap: () {
                    setState(() {
                      _withinBudget = true;
                      _expensePlanKind = 'installment';
                      _isDebtOrSubscription = true;
                      _allocationId = null;
                      _targetJarId = null;
                      _selectedSubscriptionPresetId = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _planChoiceTile(
                  label: 'اشتراك',
                  icon: Icons.subscriptions_rounded,
                  selected: _isExpenseSubscription,
                  onTap: () {
                    setState(() {
                      _withinBudget = true;
                      _expensePlanKind = 'subscription';
                      _isDebtOrSubscription = true;
                      _debtPrincipalController.clear();
                      _allocationId = null;
                      _targetJarId = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planChoiceTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subscriptionSuggestionSection() {
    final highlightedPresets = subscriptionServicePresets.take(8).toList();
    final selectedPreset = subscriptionPresetById(_selectedSubscriptionPresetId);

    return _surfaceSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الخدمة المشترك فيها',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            selectedPreset == null
                ? 'اختر من قائمة الخدمات الجاهزة ليتم تعبئة الاسم والأيقونة واللون تلقائيًا.'
                : 'الخدمة المحددة الآن: ${selectedPreset.name}',
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _pickSubscriptionService,
            icon: const Icon(Icons.travel_explore_rounded),
            label: Text(
              selectedPreset == null
                  ? 'اختيار من الخدمات الجاهزة'
                  : 'تغيير الخدمة',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: highlightedPresets.map((preset) {
              return ActionChip(
                label: Text(preset.name),
                avatar: Icon(
                  _subscriptionIcon(preset.iconName),
                  size: 18,
                  color: _parseColor(preset.colorHex),
                ),
                onPressed: () => _applySubscriptionPreset(
                  name: preset.name,
                  icon: preset.iconName,
                  color: preset.colorHex,
                  presetId: preset.id,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _budgetTargetSection(BudgetSetupEntity budget) {
    return _surfaceSection(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text(
            'المخصصات والحصالات',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(_selectedBudgetTargetLabel(budget)),
          children: [
            RadioListTile<bool>(
              value: true,
              groupValue: _isDebtOrSubscription,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _isExpenseSubscription
                    ? 'اشتراك أو خدمة شهرية'
                    : 'معاملة تقسيط',
              ),
              subtitle: Text(
                _isExpenseSubscription
                    ? 'لن تُحسب من أي مخصص وستظهر ضمن الديون والاشتراكات'
                    : 'تظهر ضمن الديون والاشتراكات مع متابعة أصل التقسيط',
              ),
              onChanged: (value) {
                setState(() {
                  _isDebtOrSubscription = true;
                  if (_expensePlanKind == 'normal') {
                    _expensePlanKind = 'installment';
                  }
                  _allocationId = null;
                  _targetJarId = null;
                });
              },
            ),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'المخصصات',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...budget.allocations.map(
              (allocation) => RadioListTile<String>(
                value: allocation.id,
                groupValue: !_isDebtOrSubscription && _targetJarId == null
                    ? _allocationId
                    : null,
                contentPadding: EdgeInsets.zero,
                title: Text(allocation.name),
                onChanged: (value) {
                  setState(() {
                    _expensePlanKind = 'normal';
                    _isDebtOrSubscription = false;
                    _allocationId = value;
                    _targetJarId = null;
                  });
                },
              ),
            ),
            const Divider(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'الحصالات',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...budget.linkedWallets.map(
              (jar) => RadioListTile<String>(
                value: jar.id,
                groupValue: !_isDebtOrSubscription && _allocationId == null
                    ? _targetJarId
                    : null,
                contentPadding: EdgeInsets.zero,
                title: Text(jar.name),
                onChanged: (value) {
                  setState(() {
                    _expensePlanKind = 'normal';
                    _isDebtOrSubscription = false;
                    _targetJarId = value;
                    _allocationId = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _selectedBudgetTargetLabel(BudgetSetupEntity budget) {
    if (_isDebtOrSubscription) {
      return _isExpenseSubscription ? 'اشتراك أو خدمة شهرية' : 'تقسيط';
    }

    if (_allocationId != null) {
      for (final allocation in budget.allocations) {
        if (allocation.id == _allocationId) {
          return 'المخصص: ${allocation.name}';
        }
      }
    }

    if (_targetJarId != null) {
      for (final jar in budget.linkedWallets) {
        if (jar.id == _targetJarId) {
          return 'الحصالة: ${jar.name}';
        }
      }
    }

    return 'اضغط للاختيار';
  }

  Widget _categorySection(List<CategoryEntity> categories) {
    return _surfaceSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الفئات', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (categories.isEmpty)
            const Text('لا توجد فئات متاحة لهذا النوع حاليًا')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map(
                    (category) => FilterChip(
                      selected: _selectedCategoryIds.contains(category.id),
                      label: Text(category.name),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategoryIds.add(category.id);
                          } else {
                            _selectedCategoryIds.remove(category.id);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _recurrenceDetails() {
    if (_recurrencePattern == 'daily') {
      return _timeTile();
    }
    if (_isWeekPattern) {
      return Column(
        children: [
          _weekdayPicker(),
          const SizedBox(height: 12),
          _timeTile(),
        ],
      );
    }
    if (_isMonthPattern) {
      return Column(
        children: [
          DropdownButtonFormField<int>(
            value: _monthlyDay,
            decoration: const InputDecoration(
              labelText: 'اليوم الشهري',
              prefixIcon: Icon(Icons.calendar_today_rounded),
            ),
            items: List.generate(
              28,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('${index + 1}'),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _monthlyDay = value);
              }
            },
          ),
          const SizedBox(height: 12),
          _timeTile(),
        ],
      );
    }
    if (_recurrencePattern == 'yearly') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _yearlyMonth,
                  decoration: const InputDecoration(
                    labelText: 'الشهر',
                    prefixIcon: Icon(Icons.date_range_rounded),
                  ),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(_monthLabel(index + 1)),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _yearlyMonth = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _yearlyDay,
                  decoration: const InputDecoration(
                    labelText: 'اليوم',
                    prefixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  items: List.generate(
                    28,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _yearlyDay = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _timeTile(),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _weekdayPicker() {
    return _surfaceSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أيام التكرار',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              return FilterChip(
                selected: _selectedWeekdays.contains(weekday),
                label: Text(_weekdayLabel(weekday)),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedWeekdays.add(weekday);
                    } else {
                      _selectedWeekdays.remove(weekday);
                    }
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _timeTile() {
    final label = _formatTime(_selectedTime);
    return _surfaceSection(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_rounded),
        title: const Text('الوقت'),
        subtitle: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: _selectedTime,
          );
          if (picked != null) {
            setState(() => _selectedTime = picked);
          }
        },
      ),
    );
  }

  List<CategoryEntity> _visibleCategories(
    List<CategoryEntity> allCategories,
    BudgetSetupEntity budget,
  ) {
    if (_type == 'expense' && _withinBudget) {
      if (_allocationId != null) {
        final allocation =
            budget.allocations.where((item) => item.id == _allocationId);
        if (allocation.isNotEmpty) {
          return allocation.first.categories;
        }
      }
      if (_targetJarId != null) {
        final jar =
            budget.linkedWallets.where((item) => item.id == _targetJarId);
        if (jar.isNotEmpty) {
          return jar.first.categories;
        }
      }
    }
    return allCategories.where((category) => category.scope == _type).toList();
  }

  void _applySubscriptionPreset({
    required String name,
    required String icon,
    required String color,
    String? presetId,
  }) {
    setState(() {
      if (_nameController.text.trim().isEmpty || _isExpenseSubscription) {
        _nameController.text = name;
      }
      _iconName = icon;
      _iconColor = color;
      _selectedSubscriptionPresetId = presetId;
      _withinBudget = true;
      _expensePlanKind = 'subscription';
      _isDebtOrSubscription = true;
    });
  }

  Future<void> _pickSubscriptionService() async {
    final preset = await showSubscriptionServicePickerSheet(
      context,
      selectedPresetId: _selectedSubscriptionPresetId,
    );
    if (preset == null) return;
    _applySubscriptionPreset(
      name: preset.name,
      icon: preset.iconName,
      color: preset.colorHex,
      presetId: preset.id,
    );
  }

  IconData _subscriptionIcon(String key) {
    switch (key) {
      case 'live_tv':
        return Icons.live_tv_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      default:
        return Icons.movie_rounded;
    }
  }

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _iconName,
      initialColorHex: _iconColor,
      title: 'اختيار أيقونة المعاملة',
    );
    if (picked == null) return;
    setState(() {
      _iconName = picked.iconName;
      _iconColor = picked.colorHex;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final effectivePattern =
        _type == 'income' && _withinBudget && _isVariableIncome
            ? 'manual-variable'
            : _recurrencePattern;
    final effectiveExecutionType =
        _type == 'income' && _withinBudget && _isVariableIncome
            ? 'manual'
            : _executionType;
    final principalRaw = double.tryParse(_debtPrincipalController.text.trim());
    final debtPrincipalTotal = (_type == 'expense' &&
            _withinBudget &&
            _isExpenseInstallment &&
            principalRaw != null &&
            principalRaw > 0)
        ? principalRaw
        : null;

    final recurringDraft = RecurringTransactionEntity(
      id: widget.initialRecurring?.id ?? '',
      name: _nameController.text.trim(),
      type: _type,
      amount: _showAmount ? amount : 0,
      dayOfMonth: _recurrencePattern == 'yearly'
          ? _yearlyDay
          : _isMonthPattern
              ? _monthlyDay
              : 1,
      executionType: effectiveExecutionType,
      walletId: _walletId,
      budgetScope: _withinBudget ? 'within-budget' : 'outside-budget',
      recurrencePattern: effectivePattern,
      icon: _iconName,
      iconColor: _iconColor,
      weekday: _selectedWeekdays.isEmpty ? null : _selectedWeekdays.first,
      weekdays: _selectedWeekdays.toList()..sort(),
      monthOfYear: _recurrencePattern == 'yearly' ? _yearlyMonth : null,
      anchorDate: widget.initialRecurring?.anchorDate,
      scheduledTime: _showRecurrenceDetails ? _formatTime(_selectedTime) : null,
      reminderLeadDays:
          effectiveExecutionType == 'confirm' ? _reminderLeadDays : null,
      allocationId:
          _type == 'expense' && _withinBudget && !_isDebtOrSubscription
              ? _allocationId
              : null,
      targetJarId: _type == 'expense' && _withinBudget && !_isDebtOrSubscription
          ? _targetJarId
          : null,
      incomeSourceId: widget.initialRecurring?.incomeSourceId,
      categoryIds: _selectedCategoryIds.toList(),
      isVariableIncome: _isVariableIncome,
      isDebtOrSubscription:
          _type == 'expense' && _withinBudget && _isDebtOrSubscription,
      expensePlanKind:
          _type == 'expense' && _withinBudget && _isDebtOrSubscription
              ? _expensePlanKind
              : null,
      debtPrincipalTotal: debtPrincipalTotal,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    final recurring = recurringDraft.copyWith(
      anchorDate: recurringDraft.anchorDate ??
          RecurringScheduleEngine.defaultAnchorDate(recurringDraft)
              .toIso8601String(),
    );

    if (widget.returnOnSave) {
      if (!mounted) return;
      Navigator.of(context).pop(
        RecurringTransactionComposerResult.saved(recurring),
      );
      return;
    }

    if (widget.initialRecurring == null) {
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
        anchorDate: recurring.anchorDate,
        scheduledTime: recurring.scheduledTime,
        reminderLeadDays: recurring.reminderLeadDays,
        allocationId: recurring.allocationId,
        targetJarId: recurring.targetJarId,
        incomeSourceId: recurring.incomeSourceId,
        categoryIds: recurring.categoryIds,
        isVariableIncome: recurring.isVariableIncome,
        isDebtOrSubscription: recurring.isDebtOrSubscription,
        expensePlanKind: recurring.expensePlanKind,
        debtPrincipalTotal: recurring.debtPrincipalTotal,
        notes: recurring.notes,
      );
    } else {
      await widget.cubit.updateRecurringTransaction(
        widget.initialRecurring!.copyWith(
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
          anchorDate: recurring.anchorDate,
          scheduledTime: recurring.scheduledTime,
          reminderLeadDays: recurring.reminderLeadDays,
          allocationId: recurring.allocationId,
          targetJarId: recurring.targetJarId,
          incomeSourceId: recurring.incomeSourceId,
          categoryIds: recurring.categoryIds,
          isVariableIncome: recurring.isVariableIncome,
          isDebtOrSubscription: recurring.isDebtOrSubscription,
          expensePlanKind: recurring.expensePlanKind,
          debtPrincipalTotal: recurring.debtPrincipalTotal,
          notes: recurring.notes,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _deleteFromComposer() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المعاملة'),
        content: const Text(
          'سيتم حذف هذه المعاملة المتكررة. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) {
      return;
    }

    if (widget.returnOnSave) {
      Navigator.of(context)
          .pop(const RecurringTransactionComposerResult.deleted());
      return;
    }

    if (widget.initialRecurring != null) {
      await widget.cubit
          .deleteRecurringTransaction(widget.initialRecurring!.id);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  TimeOfDay _parseStoredTime(String? value) {
    if (value == null || !value.contains(':')) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = int.tryParse(parts.last) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      case 6:
        return 'السبت';
      default:
        return 'الأحد';
    }
  }

  String _monthLabel(int month) {
    const labels = <String>[
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return labels[month - 1];
  }

  Color _parseColor(String hex) {
    final value =
        int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x165b47;
    return Color(0xFF000000 | value);
  }
}
