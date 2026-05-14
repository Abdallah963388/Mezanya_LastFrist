import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';

class SettingsReadModel {
  const SettingsReadModel({
    required this.userName,
    required this.currencyCode,
    required this.notificationsEnabled,
    required this.googleEmail,
    required this.backupDirectoryPath,
    required this.autoBackupMode,
    required this.profileImageUrl,
  });

  final String userName;
  final String currencyCode;
  final bool notificationsEnabled;
  final String googleEmail;
  final String backupDirectoryPath;
  final String autoBackupMode;
  final String profileImageUrl;

  factory SettingsReadModel.fromAppState(AppStateEntity appState) {
    return SettingsReadModel(
      userName: appState.userName,
      currencyCode: appState.currencyCode,
      notificationsEnabled: appState.notificationsEnabled,
      googleEmail: appState.googleEmail,
      backupDirectoryPath: appState.backupDirectoryPath,
      autoBackupMode: appState.autoBackupMode,
      profileImageUrl: appState.profileImageUrl,
    );
  }
}

class LoadSettingsReadModelUseCase {
  LoadSettingsReadModelUseCase(this._appRepository);

  final AppRepository _appRepository;

  Future<SettingsReadModel> call() async {
    final appState = await _appRepository.loadState();
    return SettingsReadModel.fromAppState(appState);
  }
}
