import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({
    super.key,
    required this.cubit,
    required this.allTransactions,
    required this.initialMonth,
  });

  final AppCubit cubit;
  final List<TransactionEntity> allTransactions;
  final DateTime initialMonth;

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  String _tab = 'all';
  String _range = 'specific-month';
  late DateTime _month;
  DateTime? _from;
  DateTime? _to;

  static const _beige = Color(0xFFFFFBF1);
  static const _green = Color(0xFF165b47);

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  bool _isJarTx(TransactionEntity t) =>
      t.transferType == 'jar-allocation' ||
      t.transferType == 'jar-allocation-cancel' ||
      t.transferType == 'jar-allocation-spend';

  List<TransactionEntity> _filtered() {
    final now = DateTime.now();
    var out = widget.allTransactions.where((t) => !_isJarTx(t)).toList();
    if (_tab != 'all') out = out.where((t) => t.type == _tab).toList();
    if (_range == 'day') {
      out = out.where((t) => now.difference(t.createdAt).inHours <= 24).toList();
    } else if (_range == 'week') {
      out = out.where((t) => now.difference(t.createdAt).inDays <= 7).toList();
    } else if (_range == 'month') {
      out = out.where((t) => now.difference(t.createdAt).inDays <= 30).toList();
    } else if (_range == 'specific-month') {
      out = out
          .where((t) =>
              t.createdAt.year == _month.year &&
              t.createdAt.month == _month.month)
          .toList();
    } else if (_range == 'custom' && _from != null && _to != null) {
      final start = DateTime(_from!.year, _from!.month, _from!.day);
      final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
      out = out
          .where((t) =>
              !t.createdAt.isBefore(start) && !t.createdAt.isAfter(end))
          .toList();
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.cubit.state.categories;
    final filtered = _filtered();
    final totalIn =
        filtered.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final totalOut =
        filtered.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);

    // Group by date
    final grouped = <String, List<TransactionEntity>>{};
    for (final t in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(t.createdAt);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _beige,
        appBar: AppBar(
          backgroundColor: _beige,
          surfaceTintColor: Colors.transparent,
          title: const Text('كل المعاملات',
              style: TextStyle(fontWeight: FontWeight.w900)),
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // ── Summary header ─────────────────────────────────────────
            _SummaryHeader(totalIn: totalIn, totalOut: totalOut, count: filtered.length),
            const SizedBox(height: 16),

            // ── Type filter chips ──────────────────────────────────────
            _TypeFilterBar(
              selected: _tab,
              onSelect: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 12),

            // ── Range selector ─────────────────────────────────────────
            _RangeSelector(
              selected: _range,
              month: _month,
              from: _from,
              to: _to,
              onRangeChange: (v) => setState(() => _range = v),
              onMonthPrev: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1)),
              onMonthNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1)),
              onPickFrom: () => _pickDate(isFrom: true),
              onPickTo: () => _pickDate(isFrom: false),
            ),
            const SizedBox(height: 16),

            // ── Transaction list grouped by date ───────────────────────
            if (filtered.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 40),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 56, color: Color(0xFFB5A99A)),
                      SizedBox(height: 12),
                      Text('لا توجد معاملات مطابقة',
                          style: TextStyle(
                              color: Color(0xFF8A7F72),
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                ),
              )
            else
              ...sortedKeys.map((dateKey) {
                final dayTx = grouped[dateKey]!;
                final dayDate = DateTime.parse(dateKey);
                final dayIncome = dayTx
                    .where((t) => t.type == 'income')
                    .fold<double>(0, (s, t) => s + t.amount);
                final dayExpense = dayTx
                    .where((t) => t.type == 'expense')
                    .fold<double>(0, (s, t) => s + t.amount);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatDate(dayDate),
                              style: TextStyle(
                                color: _green,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (dayIncome > 0)
                            Text('+${dayIncome.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Color(0xFF16A34A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          if (dayIncome > 0 && dayExpense > 0)
                            const Text('  ',
                                style: TextStyle(fontSize: 11)),
                          if (dayExpense > 0)
                            Text('-${dayExpense.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    ...dayTx.map((t) => _TxCard(
                          tx: t,
                          categories: categories,
                          onTap: () => openTransactionDetailsSheet(context,
                              cubit: widget.cubit, transaction: t),
                        )),
                    const SizedBox(height: 10),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'اليوم';
    if (day == yesterday) return 'أمس';
    return DateFormat('EEEE، d MMMM', 'ar').format(d);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }
}

// ── Summary Header ─────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.totalIn,
    required this.totalOut,
    required this.count,
  });

  final double totalIn, totalOut;
  final int count;

  @override
  Widget build(BuildContext context) {
    final net = totalIn - totalOut;
    final isPos = net >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C6D25), Color(0xFF096119)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x251C6D25), blurRadius: 20, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GlassTile(
                  label: 'إجمالي الدخل',
                  value: '+${totalIn.toStringAsFixed(2)}',
                  valueColor: const Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GlassTile(
                  label: 'إجمالي المصروف',
                  value: '-${totalOut.toStringAsFixed(2)}',
                  valueColor: const Color(0xFFF87171),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GlassTile(
                  label: 'الصافي',
                  value: '${isPos ? '+' : ''}${net.toStringAsFixed(2)}',
                  valueColor:
                      isPos ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count معاملة',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label, value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Type Filter Bar ────────────────────────────────────────────────────────

class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('all', 'الكل', Color(0xFF165b47)),
      ('income', 'دخل', Color(0xFF16A34A)),
      ('expense', 'مصروف', Color(0xFFDC2626)),
      ('transfer', 'تحويل', Color(0xFF2563EB)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => onSelect(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? opt.$3
                      : opt.$3.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : opt.$3,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Range Selector ─────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.month,
    required this.from,
    required this.to,
    required this.onRangeChange,
    required this.onMonthPrev,
    required this.onMonthNext,
    required this.onPickFrom,
    required this.onPickTo,
  });

  final String selected;
  final DateTime month;
  final DateTime? from, to;
  final ValueChanged<String> onRangeChange;
  final VoidCallback onMonthPrev, onMonthNext, onPickFrom, onPickTo;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('day', 'اليوم'),
      ('week', 'الأسبوع'),
      ('month', 'آخر شهر'),
      ('specific-month', 'شهر محدد'),
      ('custom', 'مخصص'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = selected == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () => onRangeChange(opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF165b47)
                          : const Color(0xFF165b47).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF165b47),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (selected == 'specific-month') ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF165b47).withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onMonthPrev,
                  icon: const Icon(Icons.chevron_right,
                      color: Color(0xFF165b47)),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMMM yyyy', 'ar').format(month),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF165b47)),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onMonthNext,
                  icon: const Icon(Icons.chevron_left,
                      color: Color(0xFF165b47)),
                ),
              ],
            ),
          ),
        ],
        if (selected == 'custom') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPickFrom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF165b47)
                              .withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('من',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8A7F72),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          from == null
                              ? 'اختر تاريخ'
                              : DateFormat('d/M/yyyy').format(from!),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF165b47)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onPickTo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF165b47)
                              .withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إلى',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8A7F72),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          to == null
                              ? 'اختر تاريخ'
                              : DateFormat('d/M/yyyy').format(to!),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF165b47)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Transaction Card ───────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  const _TxCard({
    required this.tx,
    required this.categories,
    required this.onTap,
  });

  final TransactionEntity tx;
  final List<CategoryEntity> categories;
  final VoidCallback onTap;

  Color _color() {
    if (tx.type == 'income') return const Color(0xFF16A34A);
    if (tx.type == 'expense') return const Color(0xFFDC2626);
    return const Color(0xFF2563EB);
  }

  IconData _icon() {
    if (tx.type == 'income') return Icons.arrow_downward_rounded;
    if (tx.type == 'expense') return Icons.arrow_upward_rounded;
    return Icons.swap_horiz_rounded;
  }

  String _typeLabel() {
    if (tx.type == 'income') return 'دخل';
    if (tx.type == 'expense') return 'مصروف';
    return 'تحويل';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final cat = tx.categoryId == null
        ? null
        : categories.where((c) => c.id == tx.categoryId).firstOrNull;
    final time = DateFormat('HH:mm').format(tx.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon(), color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.notes?.isNotEmpty == true ? tx.notes! : _typeLabel(),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(time,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A7F72),
                              fontWeight: FontWeight.w500)),
                      if (cat != null) ...[
                        const Text(' • ',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF8A7F72))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(cat.name,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.type == 'expense' ? '-' : '+'}${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
