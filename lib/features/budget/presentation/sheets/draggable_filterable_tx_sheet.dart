import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';

enum _TxKindFilter { all, expense, income, transfer }

enum _TxDateFilter { day, week, month, year, custom, all }

class DraggableFilterableTxSheet extends StatefulWidget {
  const DraggableFilterableTxSheet({
    super.key,
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
  State<DraggableFilterableTxSheet> createState() =>
      _DraggableFilterableTxSheetState();
}

class _DraggableFilterableTxSheetState
    extends State<DraggableFilterableTxSheet> {
  bool _newestFirst = true;
  _TxKindFilter _kind = _TxKindFilter.all;
  _TxDateFilter _dateFilter = _TxDateFilter.month;
  DateTime? _selectedDay;
  DateTime? _selectedWeekStart;
  DateTimeRange? _customRange;

  static bool _isTransfer(TransactionEntity transaction) {
    return transaction.type != 'expense' && transaction.type != 'income';
  }

  List<TransactionEntity> get _visible {
    var list = List<TransactionEntity>.from(widget.transactions);
    switch (_kind) {
      case _TxKindFilter.all:
        break;
      case _TxKindFilter.expense:
        list = list.where((transaction) => transaction.type == 'expense').toList();
        break;
      case _TxKindFilter.income:
        list = list.where((transaction) => transaction.type == 'income').toList();
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
        return 'يوم ${DateFormat('d MMMM yyyy', 'ar').format(day)}';
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
        return '${DateFormat('d MMMM yyyy', 'ar').format(_customRange!.start)} - ${DateFormat('d MMMM yyyy', 'ar').format(_customRange!.end)}';
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
      builder: (sheetContext) {
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
                      Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'مصروفات فقط',
                    selected: _kind == _TxKindFilter.expense,
                    onTap: () {
                      setState(() => _kind = _TxKindFilter.expense);
                      Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'دخل فقط',
                    selected: _kind == _TxKindFilter.income,
                    onTap: () {
                      setState(() => _kind = _TxKindFilter.income);
                      Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'تحويلات فقط',
                    selected: _kind == _TxKindFilter.transfer,
                    onTap: () {
                      setState(() => _kind = _TxKindFilter.transfer);
                      Navigator.pop(sheetContext);
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
                      Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'السنة المعروضة',
                    subtitle: '${widget.initialMonth.year}',
                    selected: _dateFilter == _TxDateFilter.year,
                    onTap: () {
                      setState(() => _dateFilter = _TxDateFilter.year);
                      Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'يوم محدد',
                    subtitle: _selectedDay == null
                        ? 'اختر يومًا بعينه'
                        : DateFormat('d MMMM yyyy', 'ar').format(_selectedDay!),
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
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
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
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'من تاريخ إلى تاريخ',
                    subtitle: _customRange == null
                        ? 'حدد مدى زمني مخصص'
                        : '${DateFormat('d MMMM yyyy', 'ar').format(_customRange!.start)} - ${DateFormat('d MMMM yyyy', 'ar').format(_customRange!.end)}',
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
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'كل الفترات',
                    selected: _dateFilter == _TxDateFilter.all,
                    onTap: () {
                      setState(() => _dateFilter = _TxDateFilter.all);
                      Navigator.pop(sheetContext);
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
