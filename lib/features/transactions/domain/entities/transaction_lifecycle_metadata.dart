class TransactionLifecycleMetadata {
  const TransactionLifecycleMetadata({
    this.isDeleted = false,
    this.deletedAt,
    this.purgeAt,
  });

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? purgeAt;

  TransactionLifecycleMetadata markDeleted({
    required DateTime deletedAt,
    required Duration retention,
  }) {
    return TransactionLifecycleMetadata(
      isDeleted: true,
      deletedAt: deletedAt,
      purgeAt: deletedAt.add(retention),
    );
  }

  TransactionLifecycleMetadata restore() {
    return const TransactionLifecycleMetadata();
  }
}
