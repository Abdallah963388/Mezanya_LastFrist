import 'package:flutter/foundation.dart';

import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';

class AppController extends ChangeNotifier {
  AppController(this._repository);

  final AppRepository _repository;

  AppStateEntity _state = AppStateEntity.initial();

  AppStateEntity get state => _state;

  Future<void> initialize() async {
    _state = await _repository.loadState();
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = await _repository.loadState();
    notifyListeners();
  }

  Future<void> sync(AppStateEntity state) async {
    _state = state;
    await _repository.saveState(_state);
    notifyListeners();
  }
}
