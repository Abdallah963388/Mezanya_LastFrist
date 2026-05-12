class TransactionValidationResult {
  const TransactionValidationResult({required this.isValid, this.message});

  final bool isValid;
  final String? message;
}

class TransactionValidationService {
  const TransactionValidationService._();

  static TransactionValidationResult validate({
    required double amount,
    required String walletId,
    required bool requiresBudgetTarget,
    required bool missingIncomeTarget,
    required bool recurringMode,
    required String recurringName,
    required bool exceedsUnallocated,
  }) {
    if (amount <= 0) {
      return const TransactionValidationResult(
        isValid: false,
        message: 'أدخل مبلغًا صحيحًا أكبر من صفر.',
      );
    }

    if (walletId.isEmpty) {
      return const TransactionValidationResult(
        isValid: false,
        message: 'اختر محفظة أولًا.',
      );
    }

    if (requiresBudgetTarget) {
      return const TransactionValidationResult(
        isValid: false,
        message: 'اختر مخصصًا أو حصالة.',
      );
    }

    if (missingIncomeTarget) {
      return const TransactionValidationResult(
        isValid: false,
        message: 'اختر مصدر دخل أو حصالة.',
      );
    }

    if (recurringMode && recurringName.trim().isEmpty) {
      return const TransactionValidationResult(
        isValid: false,
        message: 'اكتب اسم المعاملة المتكررة.',
      );
    }

    if (exceedsUnallocated) {
      return const TransactionValidationResult(
        isValid: false,
        message: 'المبلغ أكبر من غير المخصص.',
      );
    }

    return const TransactionValidationResult(isValid: true);
  }
}
