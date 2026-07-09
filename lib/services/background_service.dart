import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  Stream<StepCount>? _stepCountStream;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((event) async {
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now().toString().split(' ')[0];
        final lastSavedDate = prefs.getString('last_step_date') ?? '';
        
        int lastSteps = prefs.getInt('last_known_steps') ?? 0;
        int currentSteps = event.steps;

        // Falls ein neuer Tag angebrochen ist, setzen wir den Zähler zurück
        if (lastSavedDate != today) {
          lastSteps = currentSteps;
          await prefs.setString('last_step_date', today);
          await prefs.setInt('last_known_steps', currentSteps);
        }

        // Berechnung der heutigen Schritte seit dem Reset/Tagesbeginn
        // (Wichtig: event.steps ist oft die Gesamtzahl seit Boot)
        int stepsToday = currentSteps - lastSteps;
        if (stepsToday < 0) {
          // Falls das Gerät neu gestartet wurde
          stepsToday = 0;
          await prefs.setInt('last_known_steps', currentSteps);
        }
        
        FlutterForegroundTask.sendDataToMain(stepsToday);
        
        FlutterForegroundTask.updateService(
          notificationTitle: 'Fit Buddy läuft',
          notificationText: '$stepsToday Schritte heute',
        );
      }, onError: (error) {
        debugPrint("Pedometer Stream Error: $error");
      });
    } catch (e) {
      debugPrint("Failed to start pedometer: $e");
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class BackgroundService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'Fit Buddy ist aktiv',
      notificationText: 'Schritte werden gezählt...',
      callback: startCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
