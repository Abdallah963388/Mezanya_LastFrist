# Mezanya Flutter App - Project Documentation

## 1. Project Overview

**Purpose:** Mezanya is a comprehensive personal financial management mobile application designed to help users track their money, manage budgets, automate savings, and monitor recurring transactions and debts.

**Use Case & Target Users:** It targets individuals who want granular control over their finances, specifically those looking to manage multiple wallets (cash, bank), allocate income into budgets, save into "jars" (linked wallets), and manage debts. 

**Architecture Style:** 
- **Feature-First Clean Architecture:** The project separates concerns by grouping them under specific features (e.g., `budget`, `transactions`, `wallets`). Inside each feature, standard layers like `domain` (entities, repositories) and `presentation` (screens, widgets) are used.
- **State Management:** BLoC (Business Logic Component) pattern is used primarily via `Cubit`. However, the app maintains a centralized single source of truth (`AppStateEntity`) managed by a global `AppCubit`.
- **Local First:** It heavily relies on `SharedPreferences` for local data persistence (offline-first approach).

## 2. Folder & File Structure

```text
lib/
├── main.dart
├── app.dart
├── firestore_test.dart
├── core/
│   ├── di/               # Dependency Injection (e.g., bootstrap.dart)
│   ├── storage/          # Local storage keys (shared_prefs_keys.dart)
│   ├── theme/            # App theme configuration (app_theme.dart)
│   └── widgets/          # Shared global UI components
└── features/
    ├── app_shell/        # Main navigation shell (bottom nav bar, scaffolding)
    ├── app_state/        # Global state management (AppCubit, AppStateEntity, repositories)
    ├── budget/           # Budget setup, allocations, and tracking
    ├── categories/       # Transaction categories management
    ├── goals/            # Savings goals tracking
    ├── home/             # Main dashboard, charts, money overview
    ├── logs/             # Audit logs for all state mutations
    ├── notifications/    # In-app notification center
    ├── settings/         # App settings, backups, user preferences
    ├── transactions/     # Managing income, expense, and recurring transactions
    └── wallets/          # Managing standard wallets and saving jars
```

**Key Files & Their Roles:**
- `lib/main.dart`: The entry point of the app. Initializes Firebase, the dependency injection (`AppBootstrap`), and runs the app.
- `lib/app.dart`: Contains the `MezanyaApp` widget. Configures the `MaterialApp`, localization (`ar` default), and a custom aesthetic background (`_PaperAppBackground`).
- `lib/features/app_state/presentation/cubits/app_cubit.dart`: The "God Cubit". Centralized controller handling almost all business logic (adding transactions, updating wallets, etc.) and broadcasting the global `AppStateEntity`.
- `lib/features/app_state/domain/entities/app_state_entity.dart`: The massive data class acting as the single source of truth, holding lists of wallets, transactions, budget setups, logs, etc.
- `lib/features/app_state/data/repositories/shared_prefs_app_repository.dart`: Concrete implementation of data persistence. Serializes the entire `AppStateEntity` into a JSON string saved via `SharedPreferences`.

## 3. Code Components Breakdown

- **Domain Entities (`*Entity`):** Plain Dart objects representing the core business models (e.g., `TransactionEntity`, `WalletEntity`, `BudgetSetupEntity`, `LinkedWalletEntity`). They include serialization methods (`toMap`, `fromMap`).
- **Repositories (`AppRepository` & `SharedPrefsAppRepository`):** Responsible for fetching and persisting the app's state. 
- **State Management (`AppCubit`):** Contains methods for every user action (`addTransaction`, `addWallet`, `updateBudgetSetup`). It mutates the state, logs the action, and saves it to the repository.
- **UI Screens & Widgets (`presentation/`):** Stateless and Stateful widgets that consume the `AppCubit` state via `StreamBuilder` or `BlocBuilder` to render UI. 

## 4. Data Flow

1. **Input:** User interacts with a UI component (e.g., clicks "Add Transaction").
2. **Processing:** The UI calls a method on `AppCubit` (e.g., `cubit.addTransaction()`).
3. **Business Logic & Persistence:** 
   - `AppCubit` prepares the entity and calls `AppRepository.addTransaction()`.
   - `SharedPrefsAppRepository` performs complex logic (e.g., automatically funding jars or paying debts based on the income source) and updates the in-memory state.
   - It serializes the new entire `AppStateEntity` to JSON and saves it to `SharedPreferences`.
4. **State Broadcast:** `AppCubit` logs the action internally, updates its local `logs` array, and emits the new `AppStateEntity`.
5. **Output:** The UI, listening via `StreamBuilder<AppStateEntity>` (in `app.dart` / `main_shell_screen.dart`), rebuilds to reflect the latest state.

## 5. Naming Conventions

- **Files:** `snake_case.dart` (e.g., `budget_setup_screen.dart`).
- **Classes:** `PascalCase` (e.g., `MainShellScreen`, `AppCubit`).
- **Variables/Methods:** `camelCase` (e.g., `monthlyBudgetSnapshots`, `addTransaction`).
- **Entities:** Always suffixed with `Entity` (e.g., `WalletEntity`).
- **Screens:** Always suffixed with `Screen` (e.g., `WalletsScreen`).
- **Consistency:** The naming is highly consistent and follows official Dart style guidelines. 

## 6. Key Features

- **Wallet & Jar Management:** Tracks cash, bank accounts, and "jars" (linked wallets for savings).
- **Advanced Budgeting:** Users define income sources and map them to allocations or jars. 
- **Automated Transactions:** Handles recurring transactions, subscriptions, and debts.
- **Audit Logging:** Every state mutation (add, edit, delete) is recorded into a `logs` array with "before" and "after" state snapshots.
- **Auto-Routing of Funds:** When income is added, the data repository automatically routes funds to designated savings jars and debt payments based on the `BudgetSetupEntity`.

## 7. Problems & Weak Points

- **God Class Anti-Pattern:** `AppCubit` is extremely large (~1000 lines) and manages too many domains. It should be split into smaller, domain-specific Cubits (e.g., `WalletCubit`, `TransactionCubit`).
- **Business Logic Leakage:** `SharedPrefsAppRepository` handles complex domain logic (e.g., automatic jar funding and debt repayment logic in `addTransaction`). This logic should reside in the domain layer (Use Cases) or the Cubit, not the data access layer.
- **Performance Bottleneck (State Size):** The entire state (including all historical transactions and logs) is stored in a single JSON string in `SharedPreferences`. As the user adds thousands of transactions, serializing/deserializing this massive object on every UI action will cause severe UI jank and memory bloat.
- **Local Storage Limitations:** Using `SharedPreferences` as a primary database is an anti-pattern for complex relational data. The app should migrate to a local database like SQLite (via `sqflite`) or `Isar` / `Hive` for indexed queries and pagination.

## 8. Optimization for AI Usage (AI Context Summary)

```markdown
**AI Context Summary:**
Mezanya is a Flutter financial app using Feature-First Clean Architecture and BLoC (`AppCubit`). 
- **State:** A monolithic `AppStateEntity` holds all wallets, transactions, and budgets.
- **Storage:** Persisted locally as a single JSON string in `SharedPreferences` (`SharedPrefsAppRepository`).
- **Data Flow:** UI -> `AppCubit` -> `AppRepository` -> `SharedPreferences` -> UI Rebuild.
- **Warning:** `SharedPrefsAppRepository` currently contains heavy business logic for automated jar/debt funding. `AppCubit` is a god class.
- **Key Models:** `WalletEntity`, `TransactionEntity`, `BudgetSetupEntity`, `LinkedWalletEntity`.
```

## 9. Final Summary

Mezanya is a comprehensive, offline-first Flutter application for personal finance management. It empowers users to track traditional wallets, define budget allocations, and automate savings through "jars" and debt tracking. The project utilizes a feature-based folder structure, enforcing a clear separation between presentation and domain layers. State management is handled globally by a centralized `AppCubit` that holds a monolithic `AppStateEntity`. This state is serialized to JSON and persisted locally using `SharedPreferences`. While the app boasts strong feature consistency and aesthetic UI, its architecture suffers from a "God class" `AppCubit` and places complex business logic inside the data repository. Additionally, relying on `SharedPreferences` for large datasets presents future scaling and performance risks. Overall, it is a feature-rich foundation that requires a transition to a robust local database and decentralized state management to scale efficiently.
