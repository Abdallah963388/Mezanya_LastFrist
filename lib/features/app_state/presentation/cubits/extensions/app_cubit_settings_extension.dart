import '../app_cubit.dart';

extension AppCubitSettingsExtension on AppCubit {
  Future<void> updateSettings({
    String? userName,
    String? currencyCode,
    bool? notificationsEnabled,
    String? googleEmail,
    String? backupDirectoryPath,
    String? autoBackupMode,
    String? profileImageUrl,
  }) async {
    final next = state.copyWith(
      userName: userName,
      currencyCode: currencyCode,
      notificationsEnabled: notificationsEnabled,
      googleEmail: googleEmail,
      backupDirectoryPath: backupDirectoryPath,
      autoBackupMode: autoBackupMode,
      profileImageUrl: profileImageUrl,
    );
    await applyAndLog(
      action: 'edit',
      entityType: 'settings',
      entityId: 'app-settings',
      details: '?? ????? ??????? ???????',
      apply: () async => next,
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    final updated = state.notifications
        .map((notification) => notification.id == notificationId && !notification.isRead
            ? notification.copyWith(readAt: DateTime.now())
            : notification)
        .toList();
    final next = state.copyWith(notifications: updated);
    await repository.saveState(next);
    emitState(next);
  }
}

