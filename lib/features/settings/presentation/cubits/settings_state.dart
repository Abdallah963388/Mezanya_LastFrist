class SettingsState {
  const SettingsState({
    this.userName = '',
    this.currencyCode = 'EGP',
    this.notificationsEnabled = true,
    this.googleEmail = '',
    this.backupDirectoryPath = '',
    this.autoBackupMode = 'off',
    this.profileImageUrl = '',
    this.isLoading = false,
  });

  final String userName;
  final String currencyCode;
  final bool notificationsEnabled;
  final String googleEmail;
  final String backupDirectoryPath;
  final String autoBackupMode;
  final String profileImageUrl;
  final bool isLoading;

  SettingsState copyWith({
    String? userName,
    String? currencyCode,
    bool? notificationsEnabled,
    String? googleEmail,
    String? backupDirectoryPath,
    String? autoBackupMode,
    String? profileImageUrl,
    bool? isLoading,
  }) {
    return SettingsState(
      userName: userName ?? this.userName,
      currencyCode: currencyCode ?? this.currencyCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      googleEmail: googleEmail ?? this.googleEmail,
      backupDirectoryPath: backupDirectoryPath ?? this.backupDirectoryPath,
      autoBackupMode: autoBackupMode ?? this.autoBackupMode,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
