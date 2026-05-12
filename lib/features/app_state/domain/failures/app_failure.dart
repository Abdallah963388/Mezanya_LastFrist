abstract class AppFailure {
  const AppFailure(this.message);

  final String message;
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

class WalletFailure extends AppFailure {
  const WalletFailure(super.message);
}

class TransactionFailure extends AppFailure {
  const TransactionFailure(super.message);
}

class PersistenceFailure extends AppFailure {
  const PersistenceFailure(super.message);
}

class RecurringFailure extends AppFailure {
  const RecurringFailure(super.message);
}
