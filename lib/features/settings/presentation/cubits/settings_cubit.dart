import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/repositories/app_repository.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsState());

  final AppRepository _repository;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final appState = await _repository.loadState();
    emit(_fromAppState(appState).copyWith(isLoading: false));
  }

  Future<void> refresh() async {
    final appState = await _repository.loadState();
    emit(_fromAppState(appState));
  }

  SettingsState _fromAppState(AppStateEntity appState) {
    return SettingsState(
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
