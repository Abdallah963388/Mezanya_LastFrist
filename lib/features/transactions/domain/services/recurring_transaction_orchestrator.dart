import 'transaction_submission_service.dart';

class RecurringTransactionExecution {
  const RecurringTransactionExecution({
    required this.request,
    required this.shouldExecute,
    this.reason,
  });

  final TransactionSubmissionRequest request;
  final bool shouldExecute;
  final String? reason;
}

class RecurringTransactionOrchestrator {
  const RecurringTransactionOrchestrator._();

  static RecurringTransactionExecution prepare({
    required TransactionSubmissionRequest request,
    required bool isEnabled,
    required bool isDue,
    required bool requiresConfirmation,
  }) {
    if (!isEnabled) {
      return RecurringTransactionExecution(
        request: request,
        shouldExecute: false,
        reason: 'Recurring transaction disabled',
      );
    }

    if (!isDue) {
      return RecurringTransactionExecution(
        request: request,
        shouldExecute: false,
        reason: 'Recurring transaction not due yet',
      );
    }

    if (requiresConfirmation) {
      return RecurringTransactionExecution(
        request: request,
        shouldExecute: false,
        reason: 'Recurring transaction requires confirmation',
      );
    }

    return RecurringTransactionExecution(
      request: request,
      shouldExecute: true,
    );
  }
}
