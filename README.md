# Mezanya Flutter App

Financial management application built with Flutter.

## Current Architecture

The project currently follows a feature-based structure with partial Clean Architecture separation:

- `domain` → entities and repository contracts
- `data` → repository implementations and persistence
- `presentation` → cubits, screens, and widgets
- `core` → app-wide configuration and bootstrapping

## Main Technologies

- Flutter
- Flutter Bloc
- Firebase
- SharedPreferences

## Project Structure

```txt
lib/
  core/
  features/
    app_state/
    wallets/
    transactions/
    goals/
    notifications/
```

## Notes

The current application state is heavily centralized inside `AppCubit`.
Future refactoring should move business logic into dedicated use cases and services for better scalability and maintainability.

## Run

```bash
flutter pub get
flutter run
```
