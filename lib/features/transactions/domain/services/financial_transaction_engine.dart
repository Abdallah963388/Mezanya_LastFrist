import '../services/transaction_submission_service.dart';

class FinancialTransactionResult {
  const FinancialTransactionResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;

  factory FinancialTransactionResult.success() {
    return const FinancialTransactionResult(success: true);
  }

  factory FinancialTransactionResult.failure(String message) {
    return FinancialTransactionResult(
      success: false,
      errorMessage: message,
    );
  }
}

abstract class FinancialTransactionEngine {
  Future<FinancialTransactionResult> execute(
    TransactionSubmissionRequest request,
  );
}
