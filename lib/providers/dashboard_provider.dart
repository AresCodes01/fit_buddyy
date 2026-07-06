import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  bool _goalAnimationShownToday = false;

  DateTime get selectedDate => _selectedDate;
  bool get goalAnimationShownToday => _goalAnimationShownToday;

  void setGoalAnimationShown(bool shown) {
    _goalAnimationShownToday = shown;
    notifyListeners();
  }

  // Formatiert das Datum für Firebase Document IDs (z.B. 2023-10-27)
  String get dateId => DateFormat('yyyy-MM-dd').format(_selectedDate);

  // Formatiert das Datum für die UI (z.B. "Heute" oder "Montag, 27. Oktober")
  String get formattedDate {
    final now = DateTime.now();
    final todayId = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayId = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    if (dateId == todayId) return "Heute";
    if (dateId == yesterdayId) return "Gestern";
    
    return DateFormat('EEEE, d. MMMM', 'de_DE').format(_selectedDate);
  }

  bool get isToday {
    final todayId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dateId == todayId;
  }

  bool get canGoNext {
    final todayId = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dateId != todayId;
  }

  void nextDay() {
    if (!canGoNext) return;
    _selectedDate = _selectedDate.add(const Duration(days: 1));
    notifyListeners();
  }

  void previousDay() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    notifyListeners();
  }
  
  void goToToday() {
    _selectedDate = DateTime.now();
    notifyListeners();
  }

  // Setzt den Animations-Status zurück, wenn ein neuer Tag beginnt
  void checkAndResetDailyState() {
    // Hier könnte man den letzten Speicher-Tag prüfen, 
    // aber für den Session-Scope reicht das meistens.
  }
}
