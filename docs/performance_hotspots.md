# Remaining Performance Hotspots

## High Priority

### BudgetTrackingScreen
- Giant StreamBuilder<AppStateEntity>
- Large rebuild scope
- Mixed business/UI logic
- Heavy transaction filtering inside UI

### Transaction Lists
- Full list loading
- No pagination yet
- Repeated sorting/filtering in widgets

## Medium Priority

### Legacy AppCubit Consumers
- Notifications screens
- Logs screens
- Dashboard widgets
- Goals/settings screens

### Logging System
- Before/after snapshots still stored
- Delta strategy not implemented yet

## Planned Optimizations
- Localized rebuild sections
- Controller-based selectors
- Pagination/lazy loading
- Delta logs
- Removal of giant state reads
