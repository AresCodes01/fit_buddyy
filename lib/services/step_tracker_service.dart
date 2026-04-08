import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class StepTrackerService {
  late Stream<StepCount> _stepCountStream;
  int _steps = 0;

  int get steps => _steps;

  Future<bool> requestPermission() async {
    PermissionStatus status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  void initStepTracking(Function(int) onStepUpdate) {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen((StepCount event) {
      _steps = event.steps;
      onStepUpdate(_steps);
    }).onError((error) {
      print('Step Count Error: $error');
    });
  }
}
