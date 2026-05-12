import 'package:flutter/material.dart';
import 'package:fit_buddyy/features/workout/domain/models/workout_session.dart';
import 'package:fit_buddyy/features/workout/domain/repositories/workout_repository.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutRepository _repository;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  WorkoutType? _selectedType;
  WorkoutType? get selectedType => _selectedType;

  WorkoutProvider(this._repository);

  void selectType(WorkoutType type) {
    _selectedType = type;
    notifyListeners();
  }

  Future<bool> saveWorkout({
    required String userId,
    required String userName,
    required Duration duration,
    required String intensity,
    required int calories,
  }) async {
    if (_selectedType == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final session = WorkoutSession(
        userId: userId,
        userName: userName,
        duration: duration,
        type: _selectedType!,
        calories: calories,
        intensity: intensity,
        timestamp: DateTime.now(),
      );

      await _repository.saveWorkout(session);
      _isLoading = false;
      _selectedType = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
