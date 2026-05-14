import '../entities/transaction_lifecycle_metadata.dart';

class PrepareTransactionSoftDeleteUseCase {
  const PrepareTransactionSoftDeleteUseCase({
    this.retention = const Duration(days: 30),
  });

  final Duration retention;

  TransactionLifecycleMetadata execute(DateTime deletedAt) {
    return const TransactionLifecycleMetadata().markDeleted(
      deletedAt: deletedAt,
      retention: retention,
    );
  }
}
