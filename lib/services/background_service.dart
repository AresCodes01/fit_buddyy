import 'dart:isolate';
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
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream?.listen((event) async {
        final prefs = await SharedPreferences.getInstance();
        int lastSteps = prefs.getInt('last_known_steps') ?? 0;
        int currentSteps = event.steps;

        if (currentSteps < lastSteps) lastSteps = 0; 
        
        await prefs.setInt('last_known_steps', currentSteps);
        sendPort?.send(currentSteps);
        
        FlutterForegroundTask.updateService(
          notificationTitle: 'Fit Buddy läuft',
          notificationText: '$currentSteps Schritte heute',
        );
      }, onError: (error) {
        print("Pedometer Stream Error: $error");
      });
    } catch (e) {
      print("Failed to start pedometer: $e");
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}

class BackgroundService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
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
