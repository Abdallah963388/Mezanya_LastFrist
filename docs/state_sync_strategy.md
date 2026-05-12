# State Synchronization Strategy

## Current Transitional State

The application currently contains:
- Legacy AppCubit/AppStateEntity flows
- Isolated feature controllers
- Split repositories
- Split persistence

This requires temporary synchronization rules to avoid stale UI.

## Current Safe Strategy

After mutations:
- Refresh the affected controller only.
- Refresh AppCubit from repository when legacy screens still depend on it.

Example:
- Transaction added
  - Refresh TransactionController
  - Refresh WalletController if balances changed
  - Refresh BudgetController if allocations/jars changed

## Avoid

- Controller-to-controller ownership
- Circular listeners
- Giant sync managers
- Global rebuild refreshes

## Long-Term Goal

AppCubit becomes:
- bootstrap facade
- compatibility bridge only

Controllers become:
- the primary UI state sources
