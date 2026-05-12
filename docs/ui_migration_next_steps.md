# UI Migration Next Steps

## Current Progress
- Wallet screen partially migrated to WalletController.
- Split repositories and persistence are stable.
- Controllers now expose lightweight selectors.

## Immediate Next Steps
1. Extract BudgetSummarySection.
2. Reduce BudgetTrackingScreen rebuild scope.
3. Replace direct AppStateEntity reads with controller selectors.
4. Add transaction history pagination.
5. Reduce AppCubit ownership in UI.
