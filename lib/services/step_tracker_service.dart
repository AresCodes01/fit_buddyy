import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class StepTrackerService {
  late Stream<StepCount> _stepCountStream;
  int _todaySteps = 0;

  Future<bool> requestPermission() async {
    PermissionStatus status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  void initStepTracking(Function(int) onStepUpdate) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen((StepCount event) {
      int totalSteps = event.steps;
      
      // Gespeichertes Datum und Offset laden
      String? lastDate = prefs.getString('last_step_date');
      int offset = prefs.getInt('step_offset') ?? 0;

      if (lastDate != today) {
        // Erster Start heute: Aktuellen Sensor-Wert als neuen Offset speichern
        offset = totalSteps;
        prefs.setString('last_step_date', today);
        prefs.setInt('step_offset', offset);
      }

      // Falls das Handy neu gestartet wurde, kann der Sensor-Wert kleiner als der Offset sein
      if (totalSteps < offset) {
        // Sensor wurde zurückgesetzt (Handy-Neustart)
        // Wir korrigieren den Offset: Wir nehmen an, dass der User bei 0 startet
        // (Bisherige Schritte von heute gehen in diesem seltenen Fall verloren oder wir addieren sie dazu)
        offset = 0; 
        prefs.setInt('step_offset', 0);
      }

      _todaySteps = totalSteps - offset;
      onStepUpdate(_todaySteps);
    }).onError((error) {
      print('Step Count Error: $error');
    });
  }
}
