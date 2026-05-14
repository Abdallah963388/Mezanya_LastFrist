import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/load_settings_read_model_usecase.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._loadSettingsReadModelUseCase) : super(const SettingsState());

  final LoadSettingsReadModelUseCase _loadSettingsReadModelUseCase;

  Future<void> initialize() async {
    emit(state.copyWith(isLoading: true));
    final readModel = await _loadSettingsReadModelUseCase();
    emit(_fromReadModel(readModel).copyWith(isLoading: false));
  }

  Future<void> refresh() async {
    final readModel = await _loadSettingsReadModelUseCase();
    emit(_fromReadModel(readModel));
  }

  SettingsState _fromReadModel(SettingsReadModel readModel) {
    return SettingsState(
      userName: readModel.userName,
      currencyCode: readModel.currencyCode,
      notificationsEnabled: readModel.notificationsEnabled,
      googleEmail: readModel.googleEmail,
      backupDirectoryPath: readModel.backupDirectoryPath,
      autoBackupMode: readModel.autoBackupMode,
      profileImageUrl: readModel.profileImageUrl,
    );
  }
}
