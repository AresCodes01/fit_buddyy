import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Die Einstiegspunkt-Funktion für den Hintergrund-Task.
// Muss eine Top-Level-Funktion sein.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _stepCountSubscription;
  int _todaySteps = 0;

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    // Initialisierung, wenn der Task startet
    _initPedometer(sendPort);
  }

  void _initPedometer(SendPort? sendPort) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];

    _stepCountSubscription = Pedometer.stepCountStream.listen((StepCount event) {
      int totalSteps = event.steps;
      int offset = prefs.getInt('step_offset') ?? totalSteps;
      String? lastDate = prefs.getString('last_step_date');

      if (lastDate != today) {
        offset = totalSteps;
        prefs.setString('last_step_date', today);
        prefs.setInt('step_offset', offset);
      }

      _todaySteps = totalSteps - offset;
      if (_todaySteps < 0) _todaySteps = 0;

      // Update der Benachrichtigung im Hintergrund
      FlutterForegroundTask.updateService(
        notificationTitle: 'Fit Buddy ist aktiv',
        notificationText: 'Heutige Schritte: $_todaySteps',
      );

      // Daten an die Haupt-App senden, falls diese offen ist
      sendPort?.send(_todaySteps);
      
      // Lokal speichern für später
      prefs.setInt('last_known_steps', _todaySteps);
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Wird regelmäßig aufgerufen (Intervall in den Einstellungen festgelegt)
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Aufräumen
    await _stepCountSubscription?.cancel();
  }
}

class BackgroundService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'fit_buddy_channel',
        channelName: 'Fit Buddy Tracking',
        channelDescription: 'Zählt deine Schritte im Hintergrund',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    return await FlutterForegroundTask.startService(
      notificationTitle: 'Fit Buddy läuft',
      notificationText: 'Schritte werden gezählt...',
      callback: startCallback,
    );
  }

  static Future<bool> stop() async {
    return await FlutterForegroundTask.stopService();
  }
}
