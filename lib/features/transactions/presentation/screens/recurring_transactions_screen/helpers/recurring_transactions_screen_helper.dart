import 'package:flutter/material.dart';

import '../../../../../app_state/domain/entities/app_state_entity.dart';
import '../../../../domain/entities/recurring_transaction_entity.dart';
import '../../../../domain/entities/transaction_entity.dart';

class RecurringTransactionsScreenHelper {
  const RecurringTransactionsScreenHelper._();

  static String scopeSubtitle({
    required String tab,
    required bool withinBudget,
  }) {
    if (tab == 'income') {
      return withinBudget
          ? 'الدخل المتكرر الذي يدخل في خطة الميزانية ومصادر دخلها.'
          : 'الدخل المتكرر العام خارج تخطيط الميزانية الشهرية.';
    }
    return withinBudget
        ? 'المصروفات المتكررة المرتبطة بخطة الميزانية.'
        : 'مصروفات متكررة عامة خارج حسابات الميزانية الشهرية.';
  }

  static String emptyScopeLabel({
    required String tab,
    required bool withinBudget,
  }) {
    if (tab == 'income') {
      return withinBudget
          ? 'لا توجد معاملات دخل متكررة داخل الميزانية.'
          : 'لا توجد معاملات دخل متكررة عامة.';
    }
    return withinBudget
        ? 'لا توجد مصروفات متكررة داخل الميزانية.'
        : 'لا توجد مصروفات متكررة عامة.';
  }

  static String recurrenceLabel(RecurringTransactionEntity record) {
    final timeSuffix = (record.scheduledTime ?? '').isEmpty
        ? ''
        : ' · ${record.scheduledTime}';
    final weekdayLabel = record.weekdays.isNotEmpty
        ? record.weekdays.map(weekdayName).join('، ')
        : weekdayName(record.weekday);
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

  static String weekdayName(int? day) {
    return switch (day) {
      1 => 'الإثنين',
      2 => 'الثلاثاء',
      3 => 'الأربعاء',
      4 => 'الخميس',
      5 => 'الجمعة',
      6 => 'السبت',
      7 => 'الأحد',
      _ => 'غير محدد',
    };
  }

  static String executionLabel(String value) {
    return switch (value) {
      'auto' => 'تلقائي',
      'confirm' => 'يحتاج تأكيد',
      'manual' => 'يدوي',
      _ => value,
    };
  }

  static String typeLabel(RecurringTransactionEntity record) {
    if (record.type == 'income') return 'دخل';
    if (record.expensePlanKind == 'subscription') return 'اشتراك';
    if (record.expensePlanKind == 'installment') return 'قسط';
    return 'مصروف';
  }

  static String reminderLabel(RecurringTransactionEntity record) {
    final value = record.reminderLeadDays ?? 0;
    if (value == 0) return 'في نفس الموعد';
    final isHours = record.recurrencePattern == 'daily' ||
        record.recurrencePattern == 'weekly' ||
        record.recurrencePattern == 'biweekly' ||
        record.recurrencePattern == 'every_3_weeks';
    return isHours ? '$value ساعة' : '$value يوم';
  }

  static String walletName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final wallets = state.wallets.where((item) => item.id == id).toList();
    return wallets.isEmpty ? id : wallets.first.name;
  }

  static String incomeName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.incomeSources.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  static String allocationName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.allocations.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  static String jarName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.linkedWallets.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  static String categoryName(AppStateEntity state, String id) {
    final items = state.categories.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  static String expensePlanKindLabel(RecurringTransactionEntity record) {
    final kind = record.expensePlanKind;
    if (kind == 'installment') return 'قسط';
    if (kind == 'subscription') return 'اشتراك';
    return 'مصروف';
  }

  static Color parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0x2F6F5E));
  }

  static Map<String, String> detailsRows(
      AppStateEntity state, RecurringTransactionEntity record) {
    return {
      'اسم المعاملة': record.name,
      'النوع': typeLabel(record),
      'القيمة': record.isVariableIncome
          ? 'دخل متغير'
          : record.amount.toStringAsFixed(2),
      'المحفظة': walletName(state, record.walletId),
      'النطاق':
          record.budgetScope == 'within-budget' ? 'داخل الميزانية' : 'عام',
      'التكرار': recurrenceLabel(record),
      'التنفيذ': executionLabel(record.executionType),
      if (record.reminderLeadDays != null) 'التنبيه قبل': reminderLabel(record),
      if (record.incomeSourceId != null)
        'مصدر الدخل': incomeName(state, record.incomeSourceId),
      if (record.allocationId != null)
        'المخصص': allocationName(state, record.allocationId),
      if (record.targetJarId != null)
        'الحصالة': jarName(state, record.targetJarId),
      if (record.categoryIds.isNotEmpty)
        'الفئات':
            record.categoryIds.map((id) => categoryName(state, id)).join('، '),
      if (record.type == 'expense') 'التصنيف': expensePlanKindLabel(record),
      if (record.expensePlanKind == 'installment' &&
          record.debtPrincipalTotal != null)
        'إجمالي الأصل': record.debtPrincipalTotal!.toStringAsFixed(2),
      if (record.notes?.trim().isNotEmpty == true)
        'الملاحظات': record.notes!.trim(),
    };
  }

  static List<TransactionEntity> relatedTransactions(
      AppStateEntity state, RecurringTransactionEntity record) {
    final items = state.transactions.where((transaction) {
      if (transaction.type != record.type) return false;
      if (record.type == 'income') {
        if ((record.incomeSourceId ?? '').isNotEmpty) {
          return transaction.incomeSourceId == record.incomeSourceId;
        }
        return transaction.walletId == record.walletId;
      }
      if (transaction.walletId != record.walletId) return false;
      if ((record.allocationId ?? '').isNotEmpty) {
        return transaction.allocationId == record.allocationId;
      }
      if ((record.targetJarId ?? '').isNotEmpty) {
        return transaction.toWalletId == record.targetJarId ||
            transaction.walletId == record.targetJarId;
      }
      if (record.categoryIds.isNotEmpty &&
          transaction.categoryId != null &&
          record.categoryIds.contains(transaction.categoryId)) {
        return true;
      }
      final notes = (transaction.notes ?? '').toLowerCase();
      final recurringName = record.name.trim().toLowerCase();
      if (notes.contains(recurringName)) return true;
      return (transaction.amount - record.amount).abs() < 0.01;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(12).toList();
  }
}
