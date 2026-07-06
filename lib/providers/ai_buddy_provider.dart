import 'package:flutter/material.dart';
import '../features/auth/domain/models/user_model.dart';
import '../features/home/domain/models/daily_stats_model.dart';
import '../features/home/domain/repositories/steps_repository.dart';
import '../services/ai_service.dart';

class AiBuddyProvider extends ChangeNotifier {
  final StepsRepository _stepsRepo;
  final AiService _aiService = AiService();

  String _dailyMotivation = "Lade Motivation...";
  bool _isLoading = false;
  List<Map<String, String>> _chatMessages = [];

  AiBuddyProvider(this._stepsRepo);

  String get dailyMotivation => _dailyMotivation;
  bool get isLoading => _isLoading;
  List<Map<String, String>> get chatMessages => _chatMessages;

  Future<void> fetchDailyMotivation(UserModel user, int todaySteps) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final history = await _stepsRepo.getHistoricalStats(user.id, 7);
      _dailyMotivation = await _aiService.generateDailyMotivation(
        user: user,
        history: history,
        todaySteps: todaySteps,
      );
    } catch (e) {
      debugPrint("AI Provider Error: $e");
      if (e.toString().contains("quota") || e.toString().contains("429")) {
        _dailyMotivation = "Dein Fit Buddyy macht gerade eine kurze Pause. 💪";
      } else {
        _dailyMotivation = "Bleib in Bewegung! Du schaffst das! 🚀";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text, UserModel user, int todaySteps) async {
    // Kopie der aktuellen Historie für den Service-Aufruf
    final historyBefore = List<Map<String, String>>.from(_chatMessages);
    
    _chatMessages.add({'role': 'user', 'content': text});
    notifyListeners();

    try {
      final response = await _aiService.chatWithBuddy(
        userMessage: text,
        user: user,
        todaySteps: todaySteps,
        history: historyBefore,
      );
      _chatMessages.add({'role': 'buddy', 'content': response});
    } catch (e) {
      _chatMessages.add({'role': 'buddy', 'content': "Fehler: $e"});
    }
    notifyListeners();
  }
}
