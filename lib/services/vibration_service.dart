import 'package:vibration/vibration.dart';

class VibrationService {
  static Future<void> success() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 100);
    }
  }

  static Future<void> heavy() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 500);
    }
  }

  static Future<void> levelUp() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 400]);
    }
  }
  
  static Future<void> error() async {
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 50, 50, 50, 50, 50]);
    }
  }
}
